# Vault_SoftHSM2_Demo

## Install and configure Vault and SoftHSM2 for demonstration purposes

This is a simple script that will install and configure a single [Vault](https://www.vaultproject.io/) instance as well as [SoftHSM2](https://github.com/opendnssec/SoftHSMv2) on an [Ubuntu](https://ubuntu.com/) VM.

A successful execution of the script should provide you with a [Vault](https://www.vaultproject.io/) instance that auto-unseal using keys stored in a [SoftHSM2](https://github.com/opendnssec/SoftHSMv2) slot.

# Disclaimer
Please do not use this for production employments. This is for lab/testing/demonstration purposes only.

# Prerequisites
- An x86_64 Ubuntu VM (VirtualBox, AWS, gcloud, etc) - Testing was done on Jammy Jellyfish - see the [tf](https://github.com/kwagga/Vault_SoftHSM2/tree/main/tf) folder for a sandbox
- Bash shell
- [Vault Enterprise License](https://www.vaultproject.io/docs/enterprise/license) (HSM support is only available for Vault Enterprise)

# Usage
## Clone the repo
```shell
git clone https://github.com/florintp-onboarding/Vault_SoftHSM2.git
cd Vault_SoftHSM2
```
## Insert Enterprise license
- Populate `vault_license.hclic` with your license.


## Choose the AWS region into variables.tf (line 15)
```shell

variable "region" {
  type        = string
  description = "Default Region"
  sensitive   = false
  default     = "us-east-2"
}


```

## Create a SSH Keypair into the desired AWS region

## Ammend the keypair into main.tf as for example (in line 69)

```shell
...
 instance_type               = "t3.micro"
    key_name                    = "<your_keypair>"
    user_data_replace_on_change = true
...
```

## Initialize Terraform and create infrastructure
```shell
terraform init
terraform apply -auto-approve
```

## The output might look similar to
```shell
...
Outputs:

configuration = <<EOT
###
ID of the EC2 instance: aws_instance.vault-debug.id
Public IP address of the EC2 instance: 3.136.58.221

###
export VAULT_ADDR=http://3.136.58.221:8200
# or
export VAULT_ADDR=http://ec2-3-136-58-221.us-east-2.compute.amazonaws.com:8200
vault status

###
# Bypass fingerprint verification
SSH to the EC2 instance: ssh -o "StrictHostKeyChecking=no"  -i "mykey.pem" ec2-user@ec2-3-136-58-221.us-east-2.compute.amazonaws.com
GET the ROOT TOKEN: export VAULT_TOKEN=$(cat keys.json |jq -r '.root_token')

###

EOT
```

## To connect to the instance simple execute:
```shell
ssh -o "StrictHostKeyChecking=no"  -i "mykey.pem" ec2-user@ec2-3-136-58-221.us-east-2.compute.amazonaws.com
```

## To cleanup the infrastructure and created EC2 instance execute
```shell
terraform destroy -auto-approve
```
