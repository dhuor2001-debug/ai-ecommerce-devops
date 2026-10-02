output "public_ip" { value = aws_instance.node.public_ip }
output "private_key_file" { value = "${var.name}.pem" }
