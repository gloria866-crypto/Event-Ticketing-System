import json
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "shared"))
from db import get_registration, cancel_registration, increment_spots


def lambda_handler(event, context):
    registration_id = event.get("pathParameters", {}).get("id")
    if not registration_id:
        return {"statusCode": 400, "body": json.dumps({"message": "id is required"})}

    item = get_registration(registration_id)
    if not item:
        return {"statusCode": 404, "body": json.dumps({"message": "Registration not found"})}
    if item.get("status") == "cancelled":
        return {"statusCode": 409, "body": json.dumps({"message": "Already cancelled"})}

    cancel_registration(registration_id)
    increment_spots(item["eventId"])

    return {"statusCode": 200, "body": json.dumps({"message": "Registration cancelled"})}
