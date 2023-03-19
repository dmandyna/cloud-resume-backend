resource "aws_iam_role" "this" {
  name_prefix        = "cloudresume_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.asssume_role.json
}

resource "aws_iam_role_policy" "this" {
  name_prefix = "cloudresume_policy"
  role        = aws_iam_role.this.id
  policy      = data.aws_iam_policy_document.lambda.json
}
