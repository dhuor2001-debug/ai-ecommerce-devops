variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "environment" {
  type        = string
  description = "dev or prod"
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.20.1.0/24"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "root_volume_gb" {
  type    = number
  default = 30
}

variable "admin_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to SSH and reach the Kubernetes API. Never use 0.0.0.0/0."
  validation {
    condition     = !contains(var.admin_cidrs, "0.0.0.0/0")
    error_message = "admin_cidrs must not contain 0.0.0.0/0."
  }
}

variable "ecr_repositories" {
  type    = list(string)
  default = ["ecommerce-backend", "ecommerce-frontend"]
}
