import boto3

dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
events_table = dynamodb.Table("Events")

EVENTS = [
    {
        "eventId": "evt-001",
        "name": "Tech Innovation Summit 2026",
        "description": "A full-day event for builders, founders, and cloud enthusiasts.",
        "date": "2026-06-12",
        "location": "Accra, Ghana",
        "capacity": 500,
        "availableSpots": 500,
        "category": "Technology",
        "price": "0.00"
    },
    {
        "eventId": "evt-002",
        "name": "Python Community Day 2026",
        "description": "Hands-on talks and community sessions for Python developers.",
        "date": "2026-08-20",
        "location": "Kumasi, Ghana",
        "capacity": 300,
        "availableSpots": 300,
        "category": "Development",
        "price": "0.00"
    },
    {
        "eventId": "evt-003",
        "name": "Cloud Native Forum 2026",
        "description": "Practical cloud, DevOps, and platform engineering conversations.",
        "date": "2026-10-16",
        "location": "Takoradi, Ghana",
        "capacity": 400,
        "availableSpots": 400,
        "category": "Cloud",
        "price": "0.00"
    },
]


def seed():
    for event in EVENTS:
        events_table.update_item(
            Key={"eventId": event["eventId"]},
            UpdateExpression=(
                "SET #name = :name, description = :description, #date = :date, "
                "#location = :location, #capacity = :capacity, "
                "availableSpots = if_not_exists(availableSpots, :availableSpots), "
                "category = :category, price = :price"
            ),
            ExpressionAttributeNames={
                "#name": "name",
                "#date": "date",
                "#location": "location",
                "#capacity": "capacity",
            },
            ExpressionAttributeValues={f":{key}": value for key, value in event.items() if key != "eventId"},
        )
        print(f"Updated: {event['name']}")


if __name__ == "__main__":
    seed()
