provider "aws" {
  region = var.aws_region
}

resource "aws_instance" "odoo_server" {
  ami           = "ami-0c55b159cbfafe1f0" # Ubuntu 22.04 LTS
  instance_type = var.instance_type

  tags = {
    Name = "Odoo Server"
  }

  user_data = file("${path.module}/install_odoo.sh")

  vpc_security_group_ids = [aws_security_group.odoo_sg.id]
  key_name               = var.ssh_key_name
}

resource "aws_security_group" "odoo_sg" {
  name        = "odoo_sg"
  description = "Allow Odoo and SSH traffic"

  ingress {
    from_port   = 8069
    to_port     = 8069
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
