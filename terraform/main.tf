data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

module "network" {
  source             = "./modules/network"
  name               = "ecommerce-${var.environment}"
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  az                 = data.aws_availability_zones.available.names[0]
  admin_cidrs        = var.admin_cidrs
}

module "compute" {
  source            = "./modules/compute"
  name              = "ecommerce-${var.environment}"
  instance_type     = var.instance_type
  root_volume_gb    = var.root_volume_gb
  subnet_id         = module.network.public_subnet_id
  security_group_id = module.network.node_security_group_id
}

module "registry" {
  source       = "./modules/registry"
  repositories = var.ecr_repositories
}

# Hand-off to Ansible: generate the inventory from Terraform outputs so the two tools stay in sync.
resource "local_file" "ansible_inventory" {
  filename        = "${path.root}/../ansible/inventory/${var.environment}.ini"
  file_permission = "0644"
  content         = <<-EOT
    [k8s_nodes]
    ${module.compute.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=${abspath(path.root)}/${module.compute.private_key_file}
  EOT
}
