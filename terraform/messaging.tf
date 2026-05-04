resource "aws_sqs_queue" "main" {
  name                       = local.queue_name
  visibility_timeout_seconds = 360
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 20
  tags                       = { Name = local.queue_name }
}
resource "aws_sqs_queue_policy" "main" {
  queue_url = aws_sqs_queue.main.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowS3"
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.main.arn
      Condition = { ArnLike = { "aws:SourceArn" = "arn:aws:s3:::${local.upload_bucket_name}" } }
    }]
  })
}
