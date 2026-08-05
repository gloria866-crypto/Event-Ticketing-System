import boto3

dynamodb = boto3.resource("dynamodb")
events_table = dynamodb.Table("Events")

EVENTS = [
    {
        "eventId": "evt-001",
        "name": "AWS re:Invent 2025",
        "description": "Annual AWS cloud computing conference",
        "date": "2025-12-01",
        "location": "Las Vegas, NV",
        "capacity": 500,
        "availableSpots": 500,
        "category": "Cloud",
        "price": "0.00"
    },
    {
        "eventId": "evt-002",
        "name": "PyCon 2025",
        "description": "Python programming language conference",
        "date": "2025-05-15",
        "location": "Pittsburgh, PA",
        "capacity": 300,
        "availableSpots": 300,
        "category": "Programming",
        "price": "0.00"
    },
    {
        "eventId": "evt-003",
        "name": "KubeCon 2025",
        "description": "Kubernetes and cloud native computing conference",
        "date": "2025-11-10",
        "location": "Atlanta, GA",
        "capacity": 400,
        "availableSpots": 400,
        "category": "DevOps",
        "price": "0.00"
    },
]


def seed():
    for event in EVENTS:
        events_table.put_item(Item=event)
        print(f"Seeded: {event['name']}")


if __name__ == "__main__":
    seed()
