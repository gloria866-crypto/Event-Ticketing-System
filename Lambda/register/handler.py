import json
import uuid
from datetime import datetime
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "shared"))
from db import get_event, put_registration, decrement_spots
from validators import validate_register_body


def lambda_handler(event, context):
    body = json.loads(event.get("body", "{}"))
    error = validate_register_body(body)
    if error:
        return {"statusCode": 400, "body": json.dumps({"message": error})}

    event_item = get_event(body["eventId"])
    if not event_item:
        return {"statusCode": 404, "body": json.dumps({"message": "Event not found"})}
    if int(event_item.get("availableSpots", 0)) <= 0:
        return {"statusCode": 409, "body": json.dumps({"message": "No available spots"})}

    registration_id = str(uuid.uuid4())
    put_registration({
        "registrationId": registration_id,
        "eventId": body["eventId"],
        "email": body["email"],
        "name": body["name"],
        "registeredAt": datetime.utcnow().isoformat(),
        "status": "active"
    })
    decrement_spots(body["eventId"])

    return {"statusCode": 201, "body": json.dumps({"registrationId": registration_id})}
