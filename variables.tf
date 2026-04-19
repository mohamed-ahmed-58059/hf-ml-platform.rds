variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}


variable "db_name" {
  description = "Name of the Postgres database"
  type        = string
  default     = "hf_platform"
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "postgres"
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
