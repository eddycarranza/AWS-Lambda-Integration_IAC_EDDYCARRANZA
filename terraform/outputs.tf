# ─────────────────────────────────────────────
#  outputs.tf
# ─────────────────────────────────────────────

output "api_endpoint" {
  description = "URL base del HTTP API Gateway"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "upload_url" {
  description = "Endpoint POST completo para subir imágenes"
  value       = "${aws_apigatewayv2_stage.default.invoke_url}/upload"
}

output "upload_bucket_name" {
  description = "Nombre del bucket S3 de imágenes originales"
  value       = aws_s3_bucket.uploads.bucket
}

output "processed_bucket_name" {
  description = "Nombre del bucket S3 de imágenes procesadas"
  value       = aws_s3_bucket.processed.bucket
}

output "sqs_queue_url" {
  description = "URL de la cola SQS principal"
  value       = aws_sqs_queue.main.url
}

output "sqs_dlq_url" {
  description = "URL de la Dead Letter Queue"
  value       = aws_sqs_queue.dlq.url
}

output "vpc_id" {
  description = "ID de la VPC"
  value       = aws_vpc.main.id
}

output "upload_lambda_name" {
  description = "Nombre de la upload-lambda"
  value       = aws_lambda_function.upload.function_name
}

output "crop_lambda_name" {
  description = "Nombre de la crop-lambda"
  value       = aws_lambda_function.crop.function_name
}

output "aws_account_id" {
  description = "ID de la cuenta AWS usada en el despliegue"
  value       = data.aws_caller_identity.current.account_id
}

output "curl_example" {
  description = "Comando curl de ejemplo para probar el endpoint"
  value       = "curl -X POST '${aws_apigatewayv2_stage.default.invoke_url}/upload' -F 'file=@imagen.jpg'"
}
