import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource("dynamodb")

_events = dynamodb.Table("Events")
_registrations = dynamodb.Table("Registrations")


def get_event(event_id):
    return _events.get_item(Key={"eventId": event_id}).get("Item")


def list_events():
    return _events.scan().get("Items", [])


def decrement_spots(event_id):
    _events.update_item(
        Key={"eventId": event_id},
        UpdateExpression="SET availableSpots = availableSpots - :dec",
        ExpressionAttributeValues={":dec": 1}
    )


def increment_spots(event_id):
    _events.update_item(
        Key={"eventId": event_id},
        UpdateExpression="SET availableSpots = availableSpots + :inc",
        ExpressionAttributeValues={":inc": 1}
    )


def put_registration(item):
    _registrations.put_item(Item=item)


def get_registration(registration_id):
    return _registrations.get_item(Key={"registrationId": registration_id}).get("Item")


def get_registrations_by_email(email):
    return _registrations.query(
        IndexName="EmailIndex",
        KeyConditionExpression=Key("email").eq(email)
    ).get("Items", [])


def cancel_registration(registration_id):
    _registrations.update_item(
        Key={"registrationId": registration_id},
        UpdateExpression="SET #s = :cancelled",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={":cancelled": "cancelled"}
    )
