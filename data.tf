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
    resources = [aws_dynamodb_table.this.arn]
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

data "terraform_remote_state" "frontend" {
  bucket = "dmandyna-tf-backend-eu-west-1"
  key    = "projects/cloud-resume/frontend.tf"
}
