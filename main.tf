resource "aws_dynamodb_table" "counter" {
  name           = "visitors_counter"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "site"

  attribute {
    name = "site"
    type = "S"
  }
}

resource "aws_dynamodb_table_item" "this" {
  table_name = aws_dynamodb_table.counter.name
  hash_key   = aws_dynamodb_table.counter.hash_key
  item       = <<ITEM
  {
    "${aws_dynamodb_table.counter.hash_key}": {"S": "cloud_resume"},
    "count": {"N": "0"}
  }
  ITEM

  lifecycle {
    ignore_changes = [
      item
    ]
  }
}

resource "aws_dynamodb_table" "tracker" {
  name           = "visitors_tracker"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "ip_address"

  attribute {
    name = "ip_address"
    type = "S"
  }

  ttl {
    attribute_name = "expiry_date"
    enabled        = true
  }
}

resource "aws_iam_role" "this" {
  name_prefix        = "cloudresume_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.asssume_role.json
}

resource "aws_iam_role_policy" "this" {
  name_prefix = "cloudresume_policy"
  role        = aws_iam_role.this.id
  policy      = data.aws_iam_policy_document.lambda.json
}

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

resource "aws_cloudwatch_log_group" "lambda" {
  name = "/aws/lambda/${aws_lambda_function.this.function_name}"

  retention_in_days = 7
}


resource "aws_cloudwatch_log_group" "gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.this.name}"

  retention_in_days = 7
}

resource "aws_apigatewayv2_api" "this" {
  name                         = "cloudresume_lambda_gw"
  protocol_type                = "HTTP"
  disable_execute_api_endpoint = true

  cors_configuration {
    allow_origins = ["https://cv.dmandyna.co.uk"]
    allow_methods = ["GET"]
  }
}

resource "aws_apigatewayv2_stage" "this" {
  api_id = aws_apigatewayv2_api.this.id

  name        = "prod"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }

  route_settings {
    route_key              = "GET /counter"
    throttling_burst_limit = 5
    throttling_rate_limit  = 10
  }
}

resource "aws_apigatewayv2_integration" "this" {
  api_id = aws_apigatewayv2_api.this.id

  integration_uri    = aws_lambda_function.this.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "hello_world" {
  api_id = aws_apigatewayv2_api.this.id

  route_key = "GET /counter"
  target    = "integrations/${aws_apigatewayv2_integration.this.id}"
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

resource "aws_route53_record" "validation" {
  for_each = {
    for entry in aws_acm_certificate.this.domain_validation_options : entry.domain_name => {
      name   = entry.resource_record_name
      record = entry.resource_record_value
      type   = entry.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.this.zone_id
  lifecycle {
    ignore_changes = [
      name
    ]
  }
}

resource "aws_apigatewayv2_domain_name" "this" {
  domain_name = local.api_domain_name

  domain_name_configuration {
    certificate_arn = aws_acm_certificate.this.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_route53_record" "domain" {
  allow_overwrite = true
  name            = aws_apigatewayv2_domain_name.this.id
  type            = "A"
  zone_id         = data.aws_route53_zone.this.zone_id

  alias {
    name                   = aws_apigatewayv2_domain_name.this.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.this.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_apigatewayv2_api_mapping" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  domain_name = aws_apigatewayv2_domain_name.this.id
  stage       = aws_apigatewayv2_stage.this.id
}
