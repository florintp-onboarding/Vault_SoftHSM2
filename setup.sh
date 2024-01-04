#!/bin/bash

# This script will install and configure a single HashiCorp Vault (Enterprise+HSM) instance as well as the SoftHSM package.

# Need some basic colors, just makes it easier to show/read/point-out

echo_green() {
    echo -e "\e[32m${1}\e[0m"
}

echo_red() {
    echo -e "\e[31m${1}\e[0m"
}

# Main installer and configuration function

install_and_config() {
    # Install SoftHSM2 and Vault Enterprise with HSM support
    echo_green "Installing SoftHSM2 and Vault Enterprise with HSM support..."
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
    sudo apt-add-repository -y "deb https://apt.releases.hashicorp.com $(lsb_release -cs) main"
    sudo apt-get install -qq vault-enterprise-hsm softhsm2 opensc
    sudo systemctl enable vault.service
    read -p "Press any key to continue... " -n1 -s

    # Add vault user to softhsm group
    clear
    echo_green "Adding vault user to softhsm group"
    echo "sudo adduser vault softhsm"
    sudo adduser vault softhsm
    read -p "Press any key to continue... " -n1 -s

    # Let's show the SoftHSM slots
    clear
    echo_green "Listing SoftHSM slots (pre-config)"
    echo "sudo softhsm2-util --show-slots"
    sudo softhsm2-util --show-slots
    read -p "Press any key to continue... " -n1 -s

    # Need to configure a new slot for Vault
    clear
    echo_green "Configuring a new slot for Vault"
    echo "sudo -u vault softhsm2-util --init-token --slot 0 --label "vault_hsm_key" --pin 1234 --so-pin asdf"
    sudo -u vault softhsm2-util --init-token --slot 0 --label "vault_hsm_key" --pin 1234 --so-pin asdf
    read -p "Press any key to continue... " -n1 -s

    # Show new slot
    clear
    echo_green "Listing SoftHSM slots (post-config) using softhsm2-util"
    echo "sudo softhsm2-util --show-slots"
    sudo softhsm2-util --show-slots
    read -p "Press any key to continue... " -n1 -s

    # Show new slot using pkcs#11
    clear
    echo_green "Listing SoftHSM slots (post-config) using pkcs#11"
    echo "sudo pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so -L"
    sudo pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so -L
    read -p "Press any key to continue... " -n1 -s

    # Gather the new slot number and place this in VAULT_HSM_SLOT
    clear
    echo_green "Reading and saving the slot number to VAULT_HSM_SLOT"
    echo "VAULT_HSM_SLOT=\$(sudo softhsm2-util --show-slots | grep \"^Slot \" | head -1 | cut -d \" \" -f 2)"
    VAULT_HSM_SLOT=$(sudo softhsm2-util --show-slots | grep "^Slot " | head -1 | cut -d " " -f 2)
    echo "VAULT_HSM_SLOT="$VAULT_HSM_SLOT
    read -p "Press any key to continue... " -n1 -s

    # Setting VAULT_ADDR env variable
    clear
    echo_green "Setting VAULT_ADDR environment variable ..."
    echo "export VAULT_ADDR=\"http://127.0.0.1:8200\""
    echo export VAULT_ADDR="http://127.0.0.1:8200" >> ~/.profile
    export VAULT_ADDR="http://127.0.0.1:8200"
    read -p "Press any key to continue... " -n1 -s

    # Add Vault license
    echo_green "Adding license ..."
    sudo cp `pwd`/vault.hclic /etc/vault.d/vault.hclic
    echo "VAULT_LICENSE_PATH=/etc/vault.d/vault.hclic" | sudo tee -a /etc/vault.d/vault.env

    # Setup Vault config for HSM etc...
    clear
    echo_green "Setting new Vault configuration ..."
    sudo mv /etc/vault.d/vault.hcl /etc/vault.d/vault_hcl.old

    sudo tee /etc/vault.d/vault.hcl << EOF

ui = true
log_level = "trace"

storage "file" {
    path = "/opt/vault/data"
}

listener "tcp" {
address = "0.0.0.0:8200"
tls_disable = 1
}

seal "pkcs11" {
lib            = "/usr/lib/softhsm/libsofthsm2.so"
slot           = "${VAULT_HSM_SLOT}"
pin            = "1234"
key_label      = "vault-hsm-key"
hmac_key_label = "vault-hsm-hmac-key"
generate_key   = "true"
}

EOF

    sudo chown -R vault:vault /etc/vault.d/*
    read -p "Press any key to continue... " -n1 -s

    # Start Vault
    clear
    echo_green "Starting Vault"
    sudo systemctl start vault.service
    read -p "Press any key to continue... " -n1 -s
    # Check if Vault is up

    STATUS="$(systemctl is-active vault.service)"
    if [ "${STATUS}" = "active" ]; then
        clear
        echo_green "Vault is running, let's initialize....."
        echo_green "Initializing Vault and exporting keys to `echo ~`/unseal.keys - NEVER do this in production"
        echo "vault operator init -recovery-shares=1 -recovery-threshold=1 >> ~/unseal.keys"
        vault operator init -recovery-shares=1 -recovery-threshold=1 >> ~/unseal.keys
        cat ~/unseal.keys
        vault status
    else
        echo_red "Vault is not running!"
        exit 1
    fi
}

# First check whether the Vault Enterprise license file exists, break if it is missing otherwise install.
echo_green "Checking for Vault Enterprise license"
LIC=`pwd`/vault.hclic
if [ -f "$LIC" ]; then
    echo_green "Vault Enterprise license file found!"
    install_and_config
else
    echo_red $LIC" does not exist, exiting......"
fi