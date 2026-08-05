# Event Registration & Ticketing System

A serverless REST API built on AWS that replaces a traditional Microsoft Forms + Excel workflow for managing event registrations.

## Project Status

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Infrastructure Foundation | ✅ Complete |
| 2 | API Development | ✅ Complete |
| 3 | CI/CD Automation | ✅ Complete |
| 4 | Monitoring & Security | 🔄 In Progress |

---

## Architecture

```
Client → API Gateway (HTTP API) → Lambda Functions → DynamoDB
                                        ↓
                                  CloudWatch Logs & Alarms
```

- **Runtime**: Python 3.9
- **Infrastructure**: AWS Lambda, API Gateway v2 (HTTP), DynamoDB
- **IaC**: Terraform
- **CI/CD**: GitHub Actions
- **Monitoring**: CloudWatch Logs & Alarms

---

## Project Structure

```
Event-Ticketing-System/
├── .github/
│   └── workflows/
│       └── deploy.yml          # CI/CD pipeline
├── Infrastructure/
│   ├── main.tf                 # Terraform (DynamoDB, Lambda, API Gateway, IAM, CloudWatch)
│   └── parameters.json         # Project configuration reference
├── Lambda/
│   ├── events/
│   │   └── handler.py          # GET /events
│   ├── register/
│   │   └── handler.py          # POST /register
│   ├── registrations/
│   │   └── handler.py          # GET /registrations/{email}
│   ├── cancel/
│   │   └── handler.py          # DELETE /registration/{id}
│   └── shared/
│       ├── db.py               # DynamoDB helper functions
│       └── validators.py       # Input validation
├── scripts/
│   └── seed_data.py            # Seed sample events into DynamoDB
├── tests/
│   ├── test_validators.py      # Validator unit tests
│   └── test_handlers.py        # Handler unit tests (mocked DynamoDB)
├── .gitignore
├── requirements.txt
└── README.md
```

---

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/events` | List all available events |
| POST | `/register` | Register an attendee for an event |
| GET | `/registrations/{email}` | Get all registrations for an email |
| DELETE | `/registration/{id}` | Cancel a registration |

### GET /events

Returns all events from the Events table.

```bash
curl https://<API_URL>/events
```

Response `200`:
```json
[
  {
    "eventId": "evt-001",
    "name": "AWS re:Invent 2025",
    "description": "Annual AWS cloud computing conference",
    "date": "2025-12-01",
    "location": "Las Vegas, NV",
    "capacity": 500,
    "availableSpots": 498,
    "category": "Cloud",
    "price": "0.00"
  }
]
```

### POST /register

Registers an attendee. Validates input, checks capacity, and decrements available spots.

```bash
curl -X POST https://<API_URL>/register \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe", "email": "john@example.com", "eventId": "evt-001"}'
```

Request body:
```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "eventId": "evt-001"
}
```

Response `201`:
```json
{
  "message": "Registration successful",
  "registrationId": "a1b2c3d4-..."
}
```

| Status | Reason |
|--------|--------|
| 400 | Missing/invalid fields |
| 404 | Event not found |
| 409 | No available spots |

### GET /registrations/{email}

Returns all registrations for a given email using the `EmailIndex` GSI.

```bash
curl https://<API_URL>/registrations/john@example.com
```

Response `200`:
```json
[
  {
    "registrationId": "a1b2c3d4-...",
    "eventId": "evt-001",
    "email": "john@example.com",
    "name": "John Doe",
    "registeredAt": "2025-05-08T10:00:00",
    "status": "active"
  }
]
```

### DELETE /registration/{id}

Cancels a registration and restores the available spot on the event.

```bash
curl -X DELETE https://<API_URL>/registration/a1b2c3d4-...
```

Response `200`:
```json
{
  "message": "Registration cancelled successfully"
}
```

| Status | Reason |
|--------|--------|
| 400 | Missing id |
| 404 | Registration not found |

---

## Database Schema

### Events Table

| Attribute | Type | Key |
|-----------|------|-----|
| eventId | String | Partition Key |
| name | String | |
| description | String | |
| date | String | |
| location | String | |
| capacity | Number | |
| availableSpots | Number | |
| category | String | |
| price | String | |

### Registrations Table

| Attribute | Type | Key |
|-----------|------|-----|
| registrationId | String | Partition Key |
| email | String | GSI Partition Key (EmailIndex) |
| eventId | String | |
| name | String | |
| registeredAt | String | |
| status | String | |

---

## CI/CD Pipeline

The GitHub Actions workflow runs on every push to `main`:

1. **Test job** — installs dependencies and runs `pytest tests/ -v`
2. **Deploy job** (only runs if tests pass):
   - Configures AWS credentials from GitHub Secrets
   - Runs `terraform init`
   - Imports existing DynamoDB tables into state
   - Runs `terraform apply -auto-approve`

### Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |

---

## Local Setup

### Prerequisites

- Python 3.9+
- Terraform >= 1.0
- AWS CLI configured

### Install dependencies

```bash
pip install -r requirements.txt
```

### Run tests

```bash
python -m pytest tests/ -v
```

### Seed sample data

```bash
python scripts/seed_data.py
```

### Deploy infrastructure manually

```bash
cd Infrastructure
terraform init
terraform apply
```

---

## Monitoring

- CloudWatch Logs are enabled for all 4 Lambda functions automatically via `AWSLambdaBasicExecutionRole`
- CloudWatch Alarms trigger when any Lambda function exceeds **5 errors per minute**
- Lambda configuration: 128 MB memory, 30s timeout

---

## Environment Variables

Set automatically by Terraform on each Lambda function:

| Variable | Value |
|----------|-------|
| `EVENTS_TABLE` | `Events` |
| `REGISTRATIONS_TABLE` | `Registrations` |
