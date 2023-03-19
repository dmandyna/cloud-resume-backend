resource "aws_lambda_function" "this" {
  function_name = "cloudresume_increase_visitor_counter"
  role          = aws_iam_role.this.arn
  description   = "This Lambda function will increate the visitor counter stored in visitors_counter DynamoDB"

  filename = data.archive_file.visitor_counter.output_path
  handler  = "main.handler"
  runtime  = "python3.9"

  source_code_hash = data.archive_file.visitor_counter.output_base64sha256

  environment {
    variables = {
      COUNTER_TABLE_NAME = aws_dynamodb_table.counter.id
      COUNTER_HASH_KEY   = aws_dynamodb_table.counter.hash_key
      COUNTER_HASH_VALUE = "cloud_resume"
      TRACKER_TABLE_NAME = aws_dynamodb_table.tracker.id
      TRACKER_HASH_KEY   = aws_dynamodb_table.tracker.hash_key
    }
  }

  lifecycle {
    ignore_changes = [
      last_modified
    ]
  }
}

resource "aws_lambda_permission" "this" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

resource "aws_acm_certificate" "this" {
  domain_name               = "dmandyna.co.uk"
  subject_alternative_names = [local.api_domain_name]
  validation_method         = "DNS"

  tags = {
    Name = "API Gateway SSL Cert"
  }

  lifecycle {
    create_before_destroy = true
  }
}
