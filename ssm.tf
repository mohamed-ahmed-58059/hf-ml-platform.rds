resource "aws_ssm_parameter" "db_endpoint" {
  name  = "/hf-ml-platform/rds/endpoint"
  type  = "String"
  value = aws_db_instance.postgres.address
  tags  = var.tags
}

resource "aws_ssm_parameter" "db_secret_arn" {
  name  = "/hf-ml-platform/rds/secret-arn"
  type  = "String"
  value = aws_secretsmanager_secret.db.arn
  tags  = var.tags
}

resource "aws_ssm_parameter" "db_access_sg_id" {
  name  = "/hf-ml-platform/rds/db-access-sg-id"
  type  = "String"
  value = aws_security_group.db_access.id
  tags  = var.tags
}
