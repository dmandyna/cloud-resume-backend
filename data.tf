data "aws_iam_policy_document" "asssume_role" {
  statement {
    sid    = "LambdaAssumeRole"
    effect = "Allow"

    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda" {
  statement {
    sid    = "ReadAndUpdateVisitorCounterTable"
    effect = "Allow"

    actions = [
      "dynamodb:GetItem",
      "dynamodb:UpdateItem"
    ]
    resources = [aws_dynamodb_table.counter.arn]
  }
  statement {
    sid    = "ReadAndAddVisitorTrackerTable"
    effect = "Allow"

    actions = [
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:PutItem"
    ]
    resources = [aws_dynamodb_table.tracker.arn]
  }
  statement {
    sid    = "WriteCloudWatchLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["${aws_cloudwatch_log_group.lambda.arn}:*"]
  }
}

data "archive_file" "visitor_counter" {
  type = "zip"

  source_dir  = "${path.module}/src"
  output_path = "${path.module}/src.zip"
}

data "aws_route53_zone" "this" {
  name         = "dmandyna.co.uk"
  private_zone = false
}
