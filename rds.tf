data "aws_cloudformation_export" "vpc_id" {
  name = "HfMlPlatformVpcId"
}

data "aws_cloudformation_export" "private_subnet_1" {
  name = "HfMlPlatformPrivateSubnetId1"
}

data "aws_cloudformation_export" "private_subnet_2" {
  name = "HfMlPlatformPrivateSubnetId2"
}

resource "aws_db_subnet_group" "postgres" {
  name = "hf-ml-platform-rds"
  subnet_ids = [
    data.aws_cloudformation_export.private_subnet_1.value,
    data.aws_cloudformation_export.private_subnet_2.value,
  ]
  tags = merge(var.tags, { Name = "hf-ml-platform-rds" })
}

resource "aws_db_instance" "postgres" {
  identifier        = "hf-ml-platform"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = "db.t4g.micro"
  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az                = false
  publicly_accessible     = false
  backup_retention_period = 1
  skip_final_snapshot     = true

  tags = merge(var.tags, { Name = "hf-ml-platform" })
}
