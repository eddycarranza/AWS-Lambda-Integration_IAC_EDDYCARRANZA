# ─────────────────────────────────────────────
#  messaging.tf — SQS, DLQ, SNS, CloudWatch
# ─────────────────────────────────────────────

# ── Dead Letter Queue ─────────────────────────
resource "aws_sqs_queue" "dlq" {
  name                      = local.dlq_name
  message_retention_seconds = 1209600  # 14 días
  tags                      = { Name = local.dlq_name }
}

# ── Cola principal ─────────────────────────────
resource "aws_sqs_queue" "main" {
  name                       = local.queue_name
  visibility_timeout_seconds = 360        # >= timeout crop-lambda (60s) x batch (5) = suficiente margen
  message_retention_seconds  = 86400      # 1 día
  receive_wait_time_seconds  = 20         # long polling

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })

  tags = { Name = local.queue_name }
}

# ── Política: permite a S3 enviar mensajes ────
resource "aws_sqs_queue_policy" "main" {
  queue_url = aws_sqs_queue.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowS3SendMessage"
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.main.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::${local.upload_bucket_name}"
          }
        }
      }
    ]
  })
}

# ── SNS: tema de alertas ──────────────────────
resource "aws_sns_topic" "alerts" {
  name = "${local.prefix}-alerts"
  tags = { Name = "${local.prefix}-alerts" }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ── CloudWatch Alarm: DLQ con mensajes ────────
resource "aws_cloudwatch_metric_alarm" "dlq_not_empty" {
  alarm_name          = "${local.prefix}-dlq-not-empty"
  alarm_description   = "La DLQ tiene mensajes — revisar errores en crop-lambda"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = aws_sqs_queue.dlq.name }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  tags                = { Name = "${local.prefix}-dlq-alarm" }
}
