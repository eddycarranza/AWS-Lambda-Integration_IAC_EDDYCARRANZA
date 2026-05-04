resource "aws_cloudwatch_log_group" "upload_lambda" {
  name              = "/aws/lambda/${local.upload_fn_name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "crop_lambda" {
  name              = "/aws/lambda/${local.crop_fn_name}"
  retention_in_days = 14
}

resource "aws_lambda_function" "upload" {
  function_name    = local.upload_fn_name
  filename         = var.upload_lambda_zip
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  role             = aws_iam_role.upload_lambda.arn
  memory_size      = 256
  timeout          = 30
  source_code_hash = filebase64sha256(var.upload_lambda_zip)

  environment {
    variables = {
      UPLOAD_BUCKET = local.upload_bucket_name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.upload_lambda,
    aws_iam_role_policy_attachment.upload_basic,
    aws_iam_role_policy.upload_s3,
  ]
}

resource "aws_lambda_function" "crop" {
  function_name    = local.crop_fn_name
  filename         = var.crop_lambda_zip
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  role             = aws_iam_role.crop_lambda.arn
  memory_size      = 512
  timeout          = 60
  source_code_hash = filebase64sha256(var.crop_lambda_zip)

  environment {
    variables = {
      UPLOAD_BUCKET    = local.upload_bucket_name
      PROCESSED_BUCKET = local.processed_bucket_name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.crop_lambda,
    aws_iam_role_policy_attachment.crop_basic,
    aws_iam_role_policy.crop_s3_sqs,
  ]
}

resource "aws_lambda_event_source_mapping" "sqs_to_crop" {
  event_source_arn        = aws_sqs_queue.main.arn
  function_name           = aws_lambda_function.crop.arn
  batch_size              = 5
  enabled                 = true
  function_response_types = ["ReportBatchItemFailures"]
}
