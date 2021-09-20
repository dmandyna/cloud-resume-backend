resource "aws_dynamodb_table" "this" {
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
  table_name = aws_dynamodb_table.this.name
  hash_key   = aws_dynamodb_table.this.hash_key
  item       = <<ITEM
  {
    "${aws_dynamodb_table.this.hash_key}": {"S": "cloud_resume"},
    "count": {"N": "0"}
  }
  ITEM

  lifecycle {
    ignore_changes = [
      item
    ]
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
      TABLE_NAME = aws_dynamodb_table.this.id
      HASH_KEY   = aws_dynamodb_table.this.hash_key
      HASH_VALUE = "cloud_resume"
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
  name          = "cloudresume_lambda_gw"
  protocol_type = "HTTP"
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

resource "aws_apigatewayv2_domain_name" "this" {
  domain_name = "api.dmandyna.co.uk"

  domain_name_configuration {
    certificate_arn = data.terraform_remote_state.outputs.acm_certificate_arn
  }
}
