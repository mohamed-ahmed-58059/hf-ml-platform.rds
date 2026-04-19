import json
import os
import boto3
import pg8000.native


def handler(event, context):
    secret_arn = os.environ["SECRET_ARN"]
    db_name    = os.environ["DB_NAME"]
    sql_path   = os.path.join(os.path.dirname(__file__), "init.sql")

    print("Fetching secret...")
    client  = boto3.client("secretsmanager")
    secret  = json.loads(client.get_secret_value(SecretId=secret_arn)["SecretString"])
    print(f"Secret fetched. Connecting to {secret['host']}:{secret['port']}...")

    conn = pg8000.native.Connection(
        host     = secret["host"],
        port     = int(secret["port"]),
        database = db_name,
        user     = secret["username"],
        password = secret["password"],
    )

    with open(sql_path) as f:
        sql = f.read()

    conn.run(sql)
    conn.close()

    print("init.sql executed successfully")
    return {"status": "ok"}
