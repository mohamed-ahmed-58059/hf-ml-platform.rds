# hf-ml-platform.rds

Terraform-managed RDS PostgreSQL 16 for the HuggingFace ML Inference Platform. Runs in private subnets with no public access. Credentials stored in Secrets Manager. Schema initialized via a Lambda function.

---

## Architecture

- **Engine:** PostgreSQL 16
- **Instance:** `db.t4g.micro` (single-AZ, cheapest available)
- **Subnets:** Private subnets from `hf-ml-platform.vpc` (looked up via CloudFormation exports)
- **Credentials:** Randomly generated, stored in AWS Secrets Manager at `hf-ml-platform/rds`
- **State backend:** S3 bucket + DynamoDB lock table (managed separately)

---

## Security Group Pattern

Two security groups are created:

| SG | Purpose |
|---|---|
| `hf-ml-platform-rds` | Attached to the RDS instance. Allows port 5432 inbound only from `hf-ml-platform-db-access`. |
| `hf-ml-platform-db-access` | Empty label SG. Attach to any service that needs DB access (ECS tasks, Lambdas, etc.). |

This pattern means you never need to redeploy RDS infra when adding a new service — just attach `sg-db-access` to it.

Both SGs have explicit allow-all egress rules. This is required — without egress, a Lambda carrying `sg-db-access` cannot reach Secrets Manager to fetch credentials.

---

## Cross-Repo Contract (SSM Parameters)

Other services look up RDS connection details from SSM at runtime:

| Parameter | Value |
|---|---|
| `/hf-ml-platform/rds/endpoint` | RDS hostname |
| `/hf-ml-platform/rds/secret-arn` | Secrets Manager ARN for DB credentials |
| `/hf-ml-platform/rds/db-access-sg-id` | Security group ID of `sg-db-access` |

VPC ID and subnet IDs are read from CloudFormation exports produced by `hf-ml-platform.vpc`.

---

## Schema

Schema is defined in `lambda/init.sql` and applied by the init Lambda on every deploy (idempotent — all statements use `IF NOT EXISTS` / `ON CONFLICT DO NOTHING`).

Tables:

| Table | Purpose |
|---|---|
| `tiers` | Rate limit tiers (free, basic, premium, internal-*) |
| `routes` | Registered API endpoints |
| `tier_endpoints` | Per-endpoint rate limit overrides per tier |
| `users` | Platform users |
| `sessions` | User sessions |
| `refresh_tokens` | Refresh token chain with grace period support |
| `service_clients` | Internal service-to-service clients |
| `api_keys` | User API keys (SHA-256 hashed) |

> **Migration strategy:** `init.sql` is suitable for bootstrapping. For production schema migrations, use [Flyway](https://flywaydb.org/) or [Liquibase](https://www.liquibase.org/).

---

## Lambda: Init DB / Ad-hoc SQL Runner

The `hf-ml-platform-init-db` Lambda serves two purposes:

1. **Schema init** — invoked automatically by Terraform on deploy via `aws_lambda_invocation`. Runs `init.sql` against the live DB.
2. **Ad-hoc SQL** — invoke manually with a `{"sql": "..."}` payload to run any query and get results back.

**Driver:** [`pg8000`](https://github.com/tlocke/pg8000) (pure Python — no C compilation required, works on Lambda from any build machine).

### Running ad-hoc SQL queries

Create a query file:

```bash
echo '{"sql": "SELECT id, name FROM tiers ORDER BY name;"}' > /tmp/query.json
```

Invoke the Lambda:

```bash
aws lambda invoke \
  --function-name hf-ml-platform-init-db \
  --payload file:///tmp/query.json \
  --cli-binary-format raw-in-base64-out \
  --region us-east-1 \
  --profile devnull \
  /dev/stdout
```

The response contains the rows returned by the query:

```json
{"status": "ok", "rows": [["free", ...], ["basic", ...], ...]}
```

To re-run `init.sql` (e.g. after a schema change):

```bash
echo '{}' > /tmp/init.json
aws lambda invoke \
  --function-name hf-ml-platform-init-db \
  --payload file:///tmp/init.json \
  --cli-binary-format raw-in-base64-out \
  --region us-east-1 \
  --profile devnull \
  /dev/stdout
```

---

## Deployment

Managed via GitHub Actions. Three workflows:

| Workflow | Trigger | What it does |
|---|---|---|
| `ci.yml` | Every push | `terraform fmt`, `terraform validate` |
| `deploy.yml` | Manual | `terraform apply` — provisions all resources and runs schema init |
| `destroy.yml` | Manual | `terraform destroy` — tears down all resources |

Authentication uses GitHub OIDC — no long-lived AWS credentials stored anywhere.

The IAM role and Terraform state backend (S3 + DynamoDB) are managed separately.
