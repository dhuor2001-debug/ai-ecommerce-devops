variable "name" { type = string }
variable "vpc_cidr" { type = string }
variable "public_subnet_cidr" { type = string }
variable "az" { type = string }
variable "admin_cidrs" { type = list(string) }
