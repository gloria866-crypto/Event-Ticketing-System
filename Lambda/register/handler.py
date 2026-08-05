import json
import uuid
import logging
import sys
import os
from datetime import datetime

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "shared"))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "shared"))

from db import get_event, put_registration, decrement_spots
from validators import validate_register_body

logger = logging.getLogger()
logger.setLevel(logging.INFO)

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Methods": "POST,OPTIONS"
}


def lambda_handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
        logger.info("POST /register request for eventId=%s", body.get("eventId"))

        error = validate_register_body(body)
        if error:
            return {"statusCode": 400, "headers": CORS_HEADERS, "body": json.dumps({"message": error})}

        event_item = get_event(body["eventId"])
        if not event_item:
            return {"statusCode": 404, "headers": CORS_HEADERS, "body": json.dumps({"message": "Event not found"})}
        if int(event_item.get("availableSpots", 0)) <= 0:
            return {"statusCode": 409, "headers": CORS_HEADERS, "body": json.dumps({"message": "No available spots"})}

        registration_id = str(uuid.uuid4())
        put_registration({
            "registrationId": registration_id,
            "eventId": body["eventId"],
            "email": body["email"].lower().strip(),
            "name": body["name"].strip(),
            "registeredAt": datetime.utcnow().isoformat(),
            "status": "active"
        })
        decrement_spots(body["eventId"])

        logger.info("Registration created: %s", registration_id)
        return {
            "statusCode": 201,
            "headers": CORS_HEADERS,
            "body": json.dumps({"message": "Registration successful", "registrationId": registration_id})
        }
    except Exception as e:
        logger.error("Error creating registration: %s", str(e))
        return {
            "statusCode": 500,
            "headers": CORS_HEADERS,
            "body": json.dumps({"message": "Internal server error"})
        }
