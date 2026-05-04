resource "aws_s3_bucket" "uploads" {
  bucket        = local.upload_bucket_name
  force_destroy = true
  tags          = { Name = local.upload_bucket_name }
}
resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket                  = aws_s3_bucket.uploads.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_notification" "uploads" {
  bucket     = aws_s3_bucket.uploads.id
  depends_on = [aws_sqs_queue_policy.main]
  queue {
    queue_arn     = aws_sqs_queue.main.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ""
  }
}
resource "aws_s3_bucket" "processed" {
  bucket        = local.processed_bucket_name
  force_destroy = true
  tags          = { Name = local.processed_bucket_name }
}
resource "aws_s3_bucket_public_access_block" "processed" {
  bucket                  = aws_s3_bucket.processed.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
