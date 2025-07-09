output "odoo_server_ip" {
  value = aws_instance.odoo_server.public_ip
}
