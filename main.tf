# Using the test scripts from ~/hashicorp/git/vault-tools/users/sclark/managed-keys

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.31.0"
      # version = "4.49.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_ami" "amzn" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-*-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "vault-debug" {
  name   = "${random_pet.name.id}-sg"
  vpc_id = aws_vpc.vault-debug-vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    description = "Vault"
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    description = "Vault"
    from_port   = 8201
    to_port     = 8201
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    description = "Vault"
    from_port   = 8202
    to_port     = 8202
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${random_pet.name.id}"
  }
}

resource "aws_instance" "vault-debug" {

  ami = data.aws_ami.amzn.id
  instance_type               = "t3.micro"
  key_name                    = "mykeypair1"
  user_data_replace_on_change = true

  vpc_security_group_ids = [aws_security_group.vault-debug.id]
  subnet_id              = aws_subnet.vault-debug-subnet.id
  private_ip             = cidrhost(aws_subnet.vault-debug-subnet.cidr_block, 5)

  # Wait until complete installation with `tail -f /var/log/cloud-init-output.log`
  user_data = <<-EOF
    #!/usr/bin/env sh
    set -x

    # RHEL
    if [ `grep '^ID="rhel"' /etc/os-release` ] ;then
       yum install -y yum-utils jq zip net-tools
       yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
    fi

    # AmazonLinux
    if [ `grep '^ID="amzn"' /etc/os-release` ] ;then
       yum install -y yum-utils shadow-utils jq zip net-tools
       yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
    fi

    yum -y install softhsm
    yum -y install ${local.vault_version}

    export SOFTHSMLIB=""
    export SOFTLIBLOCS="/usr/lib64/libsofthsm2.so /usr/local/lib/softhsm/libsofthsm2.so /usr/lib/x86_64-linux-gnu/softhsm/libsofthsm2.so"
    for i in $SOFTLIBLOCS; do
       test -f "$i" &&  export SOFTHSMLIB="$i"
    done
    
    if [ -z $SOFTHSMLIB ]; then
       2> echo "Failed to find the location of soft hsm library"
       exit 1
    fi

    cat >/etc/vault.d/vault.env <<-EOS
    VAULT_DISABLE_SUPPORTED_STORAGE_CHECK=true
    #VAULT_LICENSE_PATH=/etc/vault.d/vault.hclic
    EOS

    cat >/etc/vault.d/vault.hcl <<-EOT
    disable_mlock = true
    log_requests_level="debug"
    log_level="trace"
    raw_storage_endpoint = true

    telemetry {
      disable_hostname = true
      dogstatsd_addr = "localhost:8125"
      prometheus_retention_time = "12h"
    }
      ui = true

      storage "raft" {
        path = "/opt/vault/data"
        node_id = "raft_node_1"
      }

      listener "tcp" {
        address     = "0.0.0.0:8200"
        tls_disable = 1
      }
      cluster_addr = "http://127.0.0.1:8201"
      api_addr = "http://127.0.0.1:8200"

      license_path = "/etc/vault.d/vault.hclic"
      disable_sealwrap = "true"

      seal "pkcs11" {
        lib            = "$SOFTHSMLIB"
        token_label    = "unseal"
        pin            = "prettysecret"
        key_label      = "vault-unseal-key"
        hmac_key_label = "vault-unseal-hmac"
        generate_key   = "true"
        # Used for seal migrations
        disabled       = "false"
      }

      kms_library "pkcs11" {
        name    = "myhsm"
        library = "$SOFTHSMLIB"
      }
    EOT

    echo ${local.license} >/etc/vault.d/vault.hclic

    rm -rf  /var/lib/softhsm/tokens
    mkdir -p /var/lib/softhsm/tokens
    chown vault:vault /var/lib/softhsm
    chown -R vault:vault /var/lib/softhsm/tokens

    softhsm2-util --init-token --slot 0 --label "unseal" --pin prettysecret --so-pin sosecret --id 44cda736-9b7b-bbd6-95ed-6d4a38d1821f
    softhsm2-util --init-token --slot 1 --label "managed-keys" --pin prettysecret --so-pin sosecret --id 4c842833-3d84-3838-4e99-a1911cbe1e9a
    #[ -d /var/lib/softhsm/tokens/44cda736-9b7b-bbd6-95ed-6d4a38d1821f ] || softhsm2-util --init-token --slot 0 --label "unseal" --pin prettysecret --so-pin sosecret --id 44cda736-9b7b-bbd6-95ed-6d4a38d1821f
    #[ -d /var/lib/softhsm/tokens/4c842833-3d84-3838-4e99-a1911cbe1e9a ] || softhsm2-util --init-token --slot 1 --label "managed-keys" --pin prettysecret --so-pin sosecret --id 4c842833-3d84-3838-4e99-a1911cbe1e9a

    usermod  vault -d /opt/vault -s /bin/bash
    chown vault:vault /var/lib/softhsm
    chown -R vault:vault /var/lib/softhsm/* 

    setcap CAP_NET_BIND_SERVICE=+eip /usr/bin/vault
    mkdir -p /etc/systemd/system/vault.service.d/
    cat >/etc/systemd/system/vault.service.d/capabilities.conf <<-EOT
      [Service]
      AmbientCapabilities=CAP_NET_BIND_SERVICE
      CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK CAP_NET_BIND_SERVICE
    EOT

    systemctl daemon-reload
    systemctl restart vault
    export VAULT_ADDR=http://localhost:8200
    while ! curl --insecure --fail --silent http://127.0.0.1:8200/v1/sys/seal-status --output /dev/null ; do printf '.' ; sleep 4 ; done  
    [ -f keys.json ] || vault operator init -recovery-shares=1 -recovery-threshold=1 -format=json >/home/ec2-user/keys.json
    chmod u+rx /home/ec2-user/.bashrc
    echo 'export VAULT_ADDR="http://localhost:8200"' >>/home/ec2-user/.bashrc
    echo "export VAULT_TOKEN=\$(cat keys.json |jq -r '.root_token')" >>/home/ec2-user/.bashrc
    echo "export PS1='[\u@\h $(vault version|cut -d " "  -f2 ) \W]\$'" >>/home/ec2-user/.bashrc
  EOF

  tags = {
    Name = "${random_pet.name.id}-instance"
  }
}

resource "aws_eip" "ip-vault-debug" {
  instance = aws_instance.vault-debug.id
  domain = "vpc"
  # vpc      = true
  tags = {
    Name = "${random_pet.name.id}-ip"
  }
}

output "configuration" {
  value = <<-EOF
###
ID of the EC2 instance: aws_instance.vault-debug.id
Public IP address of the EC2 instance: ${aws_eip.ip-vault-debug.public_ip}

###
export VAULT_ADDR=http://${aws_eip.ip-vault-debug.public_ip}:8200
# or
export VAULT_ADDR=http://${aws_eip.ip-vault-debug.public_dns}:8200
vault status

###
# Bypass fingerprint verification
# SSH to the EC2 instance:
  ssh -o "StrictHostKeyChecking=no"  -i "mykeypair1.pem" ec2-user@${aws_eip.ip-vault-debug.public_dns}
# GET the ROOT TOKEN:
  export VAULT_TOKEN=$(cat keys.json |jq -r '.root_token')
###
EOF

}

######
resource "aws_vpc" "vault-debug-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${random_pet.name.id}-vpc"
  }
}

resource "aws_subnet" "vault-debug-subnet" {
  cidr_block              = cidrsubnet(aws_vpc.vault-debug-vpc.cidr_block, 4, 1)
  vpc_id                  = aws_vpc.vault-debug-vpc.id
  map_public_ip_on_launch = true
#  availability_zone       = "eu-central-1a"
  availability_zone       = "${var.region}a"
  tags = {
    Name = "${random_pet.name.id}-subnet"
  }
}


resource "aws_internet_gateway" "vault-debug-gw" {
  vpc_id = aws_vpc.vault-debug-vpc.id
  tags = {
    Name = "${random_pet.name.id}-gw"
  }
}


resource "aws_route_table" "vault-debug-rtb" {
  vpc_id = aws_vpc.vault-debug-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vault-debug-gw.id
  }
  tags = {
    Name = "${random_pet.name.id}-rtb"
  }
}
resource "aws_route_table_association" "subnet-association" {
  subnet_id      = aws_subnet.vault-debug-subnet.id
  route_table_id = aws_route_table.vault-debug-rtb.id
}

resource "random_pet" "name" {
  length    = 1
  separator = "-"
  prefix    = "vault"
}

