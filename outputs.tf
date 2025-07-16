output "kinesis_stream_name" {
  value = aws_kinesis_stream.transaction_stream.name
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.customer_table.name
}

output "lambda_function_name" {
  value = aws_lambda_function.transaction_processor.function_name
}

output "documentdb_endpoint" {
  description = "DocumentDB cluster endpoint"
  value       = aws_docdb_cluster.hurimoney_analytics.endpoint
}

output "documentdb_connection_string" {
  description = "DocumentDB connection string"
  value       = "mongodb://hurimoney_admin:${var.documentdb_password}@${aws_docdb_cluster.hurimoney_analytics.endpoint}:27017/hurimoney_analytics?ssl=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
  sensitive   = true
}
