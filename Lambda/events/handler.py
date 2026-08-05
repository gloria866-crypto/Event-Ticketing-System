import json
import logging
import sys
import os
from decimal import Decimal

# Works locally (../shared) and inside Lambda zip (shared/ at root)
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "shared"))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "shared"))

from db import list_events

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
        logger.info("GET /events request received")
        events = list_events()
        logger.info("Returning %d events", len(events))
        return {
            "statusCode": 200,
            "headers": CORS_HEADERS,
            "body": json.dumps(events, default=decimal_default)
        }
    except Exception as e:
        logger.error("Error listing events: %s", str(e))
        return {
            "statusCode": 500,
            "headers": CORS_HEADERS,
            "body": json.dumps({"message": "Internal server error"})
        }
