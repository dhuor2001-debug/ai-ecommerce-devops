output "node_public_ip" { value = module.compute.public_ip }
output "ssh_command" { value = "ssh -i ${module.compute.private_key_file} ubuntu@${module.compute.public_ip}" }
output "ecr_repository_urls" { value = module.registry.repository_urls }
output "ansible_inventory" { value = local_file.ansible_inventory.filename }
