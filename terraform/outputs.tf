output "upload_url"           { value = "${aws_apigatewayv2_stage.default.invoke_url}/upload" }
output "upload_bucket_name"   { value = aws_s3_bucket.uploads.bucket }
output "processed_bucket_name"{ value = aws_s3_bucket.processed.bucket }
output "sqs_queue_url"        { value = aws_sqs_queue.main.url }
output "aws_account_id"       { value = data.aws_caller_identity.current.account_id }
output "curl_example"         { value = "curl -X POST '${aws_apigatewayv2_stage.default.invoke_url}/upload' -F 'file=@imagen.jpg'" }
