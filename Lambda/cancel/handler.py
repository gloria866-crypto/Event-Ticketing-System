import json
import logging
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "shared"))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "shared"))

from db import get_registration, delete_registration, increment_spots

logger = logging.getLogger()
logger.setLevel(logging.INFO)

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Methods": "DELETE,OPTIONS"
}


def lambda_handler(event, context):
    try:
        registration_id = event.get("pathParameters", {}).get("id")
        if not registration_id:
            return {"statusCode": 400, "headers": CORS_HEADERS, "body": json.dumps({"message": "id is required"})}

        logger.info("DELETE /registration/%s", registration_id)
        item = get_registration(registration_id)
        if not item:
            return {"statusCode": 404, "headers": CORS_HEADERS, "body": json.dumps({"message": "Registration not found"})}

        delete_registration(registration_id)
        increment_spots(item["eventId"])

        logger.info("Registration deleted: %s", registration_id)
        return {
            "statusCode": 200,
            "headers": CORS_HEADERS,
            "body": json.dumps({"message": "Registration cancelled successfully"})
        }
    except Exception as e:
        logger.error("Error cancelling registration: %s", str(e))
        return {
            "statusCode": 500,
            "headers": CORS_HEADERS,
            "body": json.dumps({"message": "Internal server error"})
        }
