# ------------------------------------------------------------------
# Lambda functions + EventBridge routing
#
# S3 does not allow two Lambda functions to subscribe to the same PUT
# event directly, so uploads are routed through an EventBridge rule
# instead, which fans the event out to both functions.
# ------------------------------------------------------------------

data "archive_file" "annotation_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda-annotation/lambda_function.py"
  output_path = "${path.module}/build/annotation_function.zip"
}

data "archive_file" "thumbnail_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda-thumbnail/lambda_function.py"
  output_path = "${path.module}/build/thumbnail_function.zip"
}

resource "aws_lambda_function" "annotation" {
  function_name = "image-app-annotation"
  filename      = data.archive_file.annotation_zip.output_path
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  role          = aws_iam_role.app_role.arn
  timeout       = 30

  vpc_config {
    subnet_ids         = [aws_subnet.private.id]
    security_group_ids = [aws_security_group.app.id]
  }

  environment {
    variables = {
      DB_HOST        = aws_db_instance.main.address
      DB_USER        = var.db_username
      DB_PASSWORD    = var.db_password
      DB_NAME        = var.db_name
      GEMINI_API_KEY = var.gemini_api_key
    }
  }

  # NOTE: this Lambda depends on the `requests` and `pymysql` packages,
  # which are not part of the standard runtime. The original zip bundled
  # them alongside the handler; a production setup would use a Lambda
  # Layer instead of a fat zip for easier dependency management.
}

resource "aws_lambda_function" "thumbnail" {
  function_name = "image-app-thumbnail"
  filename      = data.archive_file.thumbnail_zip.output_path
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  role          = aws_iam_role.app_role.arn
  timeout       = 30

  # Requires a Pillow-compatible Lambda Layer (native dependencies) —
  # see the Klayers project referenced in the main README for the
  # public layer ARN matching your region/runtime.
  # layers = ["arn:aws:lambda:<region>:770693421928:layer:Pillow:<version>"]
}

resource "aws_cloudwatch_event_rule" "s3_upload" {
  name        = "s3-invoke-two-lambdas"
  description = "Fires when a new object is created under uploads/ in the images bucket"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = { name = [var.s3_bucket_name] }
      object = { key = [{ prefix = "uploads/" }] }
    }
  })
}

resource "aws_cloudwatch_event_target" "annotation_target" {
  rule = aws_cloudwatch_event_rule.s3_upload.name
  arn  = aws_lambda_function.annotation.arn
}

resource "aws_cloudwatch_event_target" "thumbnail_target" {
  rule = aws_cloudwatch_event_rule.s3_upload.name
  arn  = aws_lambda_function.thumbnail.arn
}

resource "aws_lambda_permission" "allow_eventbridge_annotation" {
  statement_id  = "AllowEventBridgeInvokeAnnotation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.annotation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_upload.arn
}

resource "aws_lambda_permission" "allow_eventbridge_thumbnail" {
  statement_id  = "AllowEventBridgeInvokeThumbnail"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.thumbnail.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_upload.arn
}

# EventBridge only receives S3 object-level events once this is enabled
# on the bucket (this is a separate setting from the bucket resource
# itself, kept here for visibility next to the rule it feeds).
resource "aws_s3_bucket_notification" "eventbridge" {
  bucket      = aws_s3_bucket.images.id
  eventbridge = true
}
