import os
import logging
from functools import lru_cache

import boto3
from boto3.dynamodb.conditions import Key

logger = logging.getLogger()
logger.setLevel(logging.INFO)

@lru_cache(maxsize=1)
def _dynamodb():
    """Create the DynamoDB resource only when a database operation is needed."""
    return boto3.resource("dynamodb")


def _events_table():
    return _dynamodb().Table(os.environ.get("EVENTS_TABLE", "Events"))


def _registrations_table():
    return _dynamodb().Table(os.environ.get("REGISTRATIONS_TABLE", "Registrations"))


def get_event(event_id):
    return _events_table().get_item(Key={"eventId": event_id}).get("Item")


def list_events():
    return _events_table().scan().get("Items", [])


def decrement_spots(event_id):
    _events_table().update_item(
        Key={"eventId": event_id},
        UpdateExpression="SET availableSpots = availableSpots - :dec",
        ConditionExpression="availableSpots > :zero",
        ExpressionAttributeValues={":dec": 1, ":zero": 0}
    )


def increment_spots(event_id):
    _events_table().update_item(
        Key={"eventId": event_id},
        UpdateExpression="SET availableSpots = availableSpots + :inc",
        ExpressionAttributeValues={":inc": 1}
    )


def put_registration(item):
    _registrations_table().put_item(Item=item)


def get_registration(registration_id):
    return _registrations_table().get_item(Key={"registrationId": registration_id}).get("Item")


def get_registrations_by_email(email):
    return _registrations_table().query(
        IndexName="EmailIndex",
        KeyConditionExpression=Key("email").eq(email)
    ).get("Items", [])


def delete_registration(registration_id):
    _registrations_table().delete_item(Key={"registrationId": registration_id})
