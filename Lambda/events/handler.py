import json
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "shared"))
from db import list_events


def lambda_handler(event, context):
    return {"statusCode": 200, "body": json.dumps(list_events())}
