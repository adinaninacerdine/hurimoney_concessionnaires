output "kinesis_stream_name" {
  value = aws_kinesis_stream.transaction_stream.name
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.customer_table.name
}

output "lambda_function_name" {
  value = aws_lambda_function.transaction_processor.function_name
}
