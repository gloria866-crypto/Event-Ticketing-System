import json
import logging
import sys
import os
from decimal import Decimal

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "shared"))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "shared"))

from db import get_registrations_by_email

logger = logging.getLogger()
logger.setLevel(logging.INFO)

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Methods": "GET,OPTIONS"
}


def decimal_default(obj):
    if isinstance(obj, Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    raise TypeError


def lambda_handler(event, context):
    try:
        email = event.get("pathParameters", {}).get("email")
        if not email:
            return {"statusCode": 400, "headers": CORS_HEADERS, "body": json.dumps({"message": "email is required"})}

        logger.info("GET /registrations/%s", email)
        registrations = get_registrations_by_email(email.lower().strip())
        logger.info("Found %d registrations for %s", len(registrations), email)
        return {
            "statusCode": 200,
            "headers": CORS_HEADERS,
            "body": json.dumps(registrations, default=decimal_default)
        }
    except Exception as e:
        logger.error("Error fetching registrations: %s", str(e))
        return {
            "statusCode": 500,
            "headers": CORS_HEADERS,
            "body": json.dumps({"message": "Internal server error"})
        }
