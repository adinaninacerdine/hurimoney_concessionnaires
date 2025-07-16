
provider "aws" {
  region = var.aws_region
}

resource "aws_kinesis_stream" "transaction_stream" {
  name        = "hurimoney-transactions"
  shard_count = 1
}

resource "aws_dynamodb_table" "customer_table" {
  name           = "hurimoney-customers"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "customer_phone"

  attribute {
    name = "customer_phone"
    type = "S"
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "hurimoney-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_kinesis_policy" {
  name = "hurimoney-lambda-kinesis-policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["kinesis:GetRecords", "kinesis:GetShardIterator", "kinesis:DescribeStream", "kinesis:ListStreams"]
        Effect   = "Allow"
        Resource = aws_kinesis_stream.transaction_stream.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name = "hurimoney-lambda-dynamodb-policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.customer_table.arn
      }
    ]
  })
}

# Security Group pour DocumentDB
resource "aws_security_group" "docdb" {
  name        = "hurimoney-docdb-sg"
  description = "Security group for DocumentDB cluster"

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Restreindre en production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "hurimoney-docdb-sg"
  }
}

# DocumentDB Cluster (MongoDB compatible)
resource "aws_docdb_cluster" "hurimoney_analytics" {
  cluster_identifier      = "hurimoney-analytics"
  engine                  = "docdb"
  master_username         = "hurimoney_admin"
  master_password         = var.documentdb_password
  backup_retention_period = 7
  preferred_backup_window = "07:00-09:00"
  skip_final_snapshot     = false
  storage_encrypted       = true
  
  vpc_security_group_ids = [aws_security_group.docdb.id]

  tags = {
    Name = "hurimoney-analytics-cluster"
  }
}

# DocumentDB Instance
resource "aws_docdb_cluster_instance" "hurimoney_analytics_instance" {
  identifier         = "hurimoney-analytics-1"
  cluster_identifier = aws_docdb_cluster.hurimoney_analytics.id
  instance_class     = "db.t3.medium"

  tags = {
    Name = "hurimoney-analytics-instance"
  }
}

# Lambda Function avec DocumentDB
resource "aws_lambda_function" "transaction_processor" {
  function_name = "hurimoney-transaction-processor"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "main.handler"
  runtime       = "python3.9"
  filename      = "lambda.zip"

  environment {
    variables = {
      CUSTOMER_TABLE_NAME = aws_dynamodb_table.customer_table.name
      MONGODB_URI = "mongodb://hurimoney_admin:${var.documentdb_password}@${aws_docdb_cluster.hurimoney_analytics.endpoint}:27017/hurimoney_analytics?ssl=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
      ODOO_API_URL = var.odoo_api_url
      ODOO_API_KEY = var.odoo_api_key
    }
  }
}

resource "aws_lambda_event_source_mapping" "kinesis_mapping" {
  event_source_arn  = aws_kinesis_stream.transaction_stream.arn
  function_name     = aws_lambda_function.transaction_processor.arn
  starting_position = "LATEST"
}
