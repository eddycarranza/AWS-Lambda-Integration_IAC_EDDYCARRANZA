# ─────────────────────────────────────────────
#  storage.tf — Buckets S3
# ─────────────────────────────────────────────

# ════════════════════════════════════════════
#  Bucket: uploads
# ════════════════════════════════════════════
resource "aws_s3_bucket" "uploads" {
  bucket        = local.upload_bucket_name
  force_destroy = true
  tags          = { Name = local.upload_bucket_name }
}

resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket                  = aws_s3_bucket.uploads.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  rule {
    id     = "expire-30d"
    status = "Enabled"
    filter { prefix = "" }
    expiration { days = 30 }
    noncurrent_version_expiration { noncurrent_days = 7 }
  }
}

# Notificación S3 → SQS (ObjectCreated)
# depends_on garantiza que la política SQS exista antes
resource "aws_s3_bucket_notification" "uploads" {
  bucket     = aws_s3_bucket.uploads.id
  depends_on = [aws_sqs_queue_policy.main]

  queue {
    queue_arn     = aws_sqs_queue.main.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ""
  }
}

# ════════════════════════════════════════════
#  Bucket: processed
# ════════════════════════════════════════════
resource "aws_s3_bucket" "processed" {
  bucket        = local.processed_bucket_name
  force_destroy = true
  tags          = { Name = local.processed_bucket_name }
}

resource "aws_s3_bucket_versioning" "processed" {
  bucket = aws_s3_bucket.processed.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "processed" {
  bucket = aws_s3_bucket.processed.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "processed" {
  bucket                  = aws_s3_bucket.processed.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "processed" {
  bucket = aws_s3_bucket.processed.id
  rule {
    id     = "expire-90d"
    status = "Enabled"
    filter { prefix = "" }
    expiration { days = 90 }
    noncurrent_version_expiration { noncurrent_days = 7 }
  }
}
