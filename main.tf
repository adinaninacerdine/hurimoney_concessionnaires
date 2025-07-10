provider "aws" {
  region = var.aws_region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# VPC et subnets pour RDS
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# DB Subnet Group pour RDS
resource "aws_db_subnet_group" "odoo_db_subnet_group" {
  name       = "odoo-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name = "Odoo DB subnet group"
  }
}

# Security Group pour RDS
resource "aws_security_group" "rds_sg" {
  name        = "odoo-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.odoo_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Odoo RDS Security Group"
  }
}

# RDS PostgreSQL instance avec PostGIS
resource "aws_db_instance" "odoo_db" {
  identifier     = "odoo-postgresql-v2"
  engine         = "postgres"
  engine_version = "15.7"
  instance_class = "db.t3.micro"
  
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type         = "gp2"
  storage_encrypted    = true
  
  db_name  = "odoo"
  username = "odoo"
  password = "OdooPassword2024"
  
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.odoo_db_subnet_group.name
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  skip_final_snapshot = true
  deletion_protection = false
  
  tags = {
    Name = "Odoo PostgreSQL Database"
  }
}

# Security Group pour le serveur web Odoo
resource "aws_security_group" "odoo_sg" {
  name        = "odoo-web-sg"
  description = "Security group for Odoo web server"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 8069
    to_port     = 8069
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Odoo Web Security Group"
  }
}

# Serveur web Odoo (sans PostgreSQL local)
resource "aws_instance" "odoo_web_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.small"

  vpc_security_group_ids = [aws_security_group.odoo_sg.id]
  key_name               = var.ssh_key_name

  user_data = file("${path.module}/install_odoo_official.sh")

  tags = {
    Name = "Odoo Web Server"
  }

  depends_on = [aws_db_instance.odoo_db]
}

# Outputs
output "rds_endpoint" {
  value = aws_db_instance.odoo_db.endpoint
}

output "rds_address" {
  value = aws_db_instance.odoo_db.address
}

output "rds_port" {
  value = aws_db_instance.odoo_db.port
}

output "odoo_web_server_ip" {
  value = aws_instance.odoo_web_server.public_ip
}

output "odoo_url" {
  value = "http://${aws_instance.odoo_web_server.public_ip}:8069"
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/${var.ssh_key_name}.pem ubuntu@${aws_instance.odoo_web_server.public_ip}"
}

output "webhook_url" {
  value = "http://${aws_instance.odoo_web_server.public_ip}:9000/deploy"
}

output "rds_connection_string" {
  value = "postgresql://${aws_db_instance.odoo_db.username}:${aws_db_instance.odoo_db.password}@${aws_db_instance.odoo_db.address}:${aws_db_instance.odoo_db.port}/${aws_db_instance.odoo_db.db_name}"
  sensitive = true
}