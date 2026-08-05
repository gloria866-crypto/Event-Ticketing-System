import json
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "shared"))
from db import get_registrations_by_email


def lambda_handler(event, context):
    email = event.get("pathParameters", {}).get("email")
    if not email:
        return {"statusCode": 400, "body": json.dumps({"message": "email is required"})}

    return {"statusCode": 200, "body": json.dumps(get_registrations_by_email(email))}
