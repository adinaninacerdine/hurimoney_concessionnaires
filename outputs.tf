output "odoo_server_ip" {
  value = aws_instance.odoo_server.public_ip
}

output "odoo_url" {
  value = "http://${aws_instance.odoo_server.public_ip}:8069"
}

output "webhook_url" {
  value = "http://${aws_instance.odoo_server.public_ip}:9000/deploy"
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/${var.ssh_key_name}.pem ubuntu@${aws_instance.odoo_server.public_ip}"
}
