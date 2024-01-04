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
}


