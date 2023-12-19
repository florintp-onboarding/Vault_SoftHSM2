# Vault_SoftHSM2_Demo

## Install and configure Vault and SoftHSM2 for demonstration purposes

This is a Terraform code that will install and configure a single [Vault](https://www.vaultproject.io/) instance on AWS region us-east2.
The EC2 may be configurable with an [Ubuntu](https://ubuntu.com/) AMI or an Amazon Linux 2 AMI.
The TF code will also install and configure a software HSM - [SoftHSM2](https://github.com/opendnssec/SoftHSMv2).

Succcessful deployment of the infrastructure will configure and start a [Vault](https://www.vaultproject.io/) instance with auto-unseal using an KMS key.
The KMS stored in a [SoftHSM2](https://github.com/opendnssec/SoftHSMv2) slot.

# Disclaimer
This is for debugging and learning purposes only.

# Prerequisites
- A valid AWS subscription and enough permissions for deploying an EC2 instace, create Security Groups, create Elastic IPs.
- [Vault Enterprise License](https://www.vaultproject.io/docs/enterprise/license) (HSM support is only available for Vault Enterprise)
- The infrastructure as code tool [Terraform](https://developer.hashicorp.com/terraform/install) 

# Usage
## Clone the repo
```shell
git clone https://github.com/florintp-onboarding/Vault_SoftHSM2.git
cd Vault_SoftHSM2
```
## Insert Enterprise license
- Populate `vault_license.hclic` with your license.


## Choose the AWS region into variables.tf (line 17)
```shell

variable "region" {
  type        = string
  description = "Default Region"
  sensitive   = false
  default     = "us-east-2"
  # Change the AMI to ami-098dd3a86ea110896
#  default     = "eu-central-1"
}


```

## Create a SSH Keypair into the desired AWS region
[AWS Console-> Netwpork & Security -> Key Pairs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html)

## Ammend the keypair into main.tf as for example (in line 69)

```shell
...
 instance_type               = "t3.micro"
    key_name                    = "<your_keypair>"
    user_data_replace_on_change = true
...
```
## Prepare the AWS environment variables
```
AWS_ACCESS_KEY_ID='<your_access_key_id>'
AWS_ACCOUNT_ID='<your_account_id>'
AWS_SECRET_ACCESS_KEY='<your_key>'
AWS_SESSION_TOKEN='<your_token'
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
