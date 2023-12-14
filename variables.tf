variable "license" {
  type        = string
  description = "License Vault"
  sensitive   = true
default = ""
}

variable "region" {
  type        = string
  description = "Default Region"
  sensitive   = false
  default     = "us-east-2"
  # Change the AMI to ami-098dd3a86ea110896
#  default     = "eu-central-1"
}


