resource "aws_security_group" "db_access" {
  name        = "hf-ml-platform-db-access"
  description = "Attach to any service that needs access to RDS"
  vpc_id      = data.aws_cloudformation_export.vpc_id.value
  tags        = merge(var.tags, { Name = "hf-ml-platform-db-access" })
}

resource "aws_security_group" "rds" {
  name        = "hf-ml-platform-rds"
  description = "RDS Postgres - allows inbound 5432 from db-access group"
  vpc_id      = data.aws_cloudformation_export.vpc_id.value
  tags        = merge(var.tags, { Name = "hf-ml-platform-rds" })
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_db_access" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.db_access.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  tags                         = var.tags
}

resource "aws_vpc_security_group_egress_rule" "rds_egress" {
  security_group_id = aws_security_group.rds.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  tags              = var.tags
}
