locals {
  lambda_src = "${path.module}/lambda"
  lambda_zip = "${path.module}/lambda.zip"
}

# ── package ───────────────────────────────────────────────────────────────────

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = local.lambda_src
  output_path = local.lambda_zip
}

# ── IAM role ──────────────────────────────────────────────────────────────────

resource "aws_iam_role" "init_db_lambda" {
  name = "hf-ml-platform-init-db-lambda"
  tags = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "init_db_lambda" {
  name = "hf-ml-platform-init-db-lambda"
  role = aws_iam_role.init_db_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.db.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
    ]
  })
}

# ── function ──────────────────────────────────────────────────────────────────

resource "aws_lambda_function" "init_db" {
  function_name    = "hf-ml-platform-init-db"
  role             = aws_iam_role.init_db_lambda.arn
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime          = "python3.12"
  handler          = "init_db.handler"
  timeout          = 60
  tags             = var.tags

  vpc_config {
    subnet_ids = [
      data.aws_cloudformation_export.private_subnet_1.value,
      data.aws_cloudformation_export.private_subnet_2.value,
    ]
    security_group_ids = [aws_security_group.db_access.id]
  }

  environment {
    variables = {
      SECRET_ARN = aws_secretsmanager_secret.db.arn
      DB_NAME    = var.db_name
    }
  }

  depends_on = [aws_db_instance.postgres]
}

# ── invoke once after apply ───────────────────────────────────────────────────

resource "aws_lambda_invocation" "init_db" {
  function_name = aws_lambda_function.init_db.function_name
  input         = "{}"

  triggers = {
    schema_hash = filemd5("${local.lambda_src}/init.sql")
  }
}
