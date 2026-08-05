import json
import sys
import os
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "Lambda", "shared"))

# ─── POST /register ──────────────────────────────────────────────────────────

def _register_event(body):
    return {"body": json.dumps(body), "pathParameters": {}}


@patch("db.decrement_spots")
@patch("db.put_registration")
@patch("db.get_event")
def test_register_success(mock_get_event, mock_put, mock_dec):
    mock_get_event.return_value = {"eventId": "evt-001", "availableSpots": 10}
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "Lambda", "register"))
    import handler as register_handler
    resp = register_handler.lambda_handler(_register_event({"name": "John", "email": "john@example.com", "eventId": "evt-001"}), {})
    assert resp["statusCode"] == 201
    assert "registrationId" in json.loads(resp["body"])


@patch("db.get_event")
def test_register_event_not_found(mock_get_event):
    mock_get_event.return_value = None
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "Lambda", "register"))
    import handler as register_handler
    resp = register_handler.lambda_handler(_register_event({"name": "John", "email": "john@example.com", "eventId": "bad-id"}), {})
    assert resp["statusCode"] == 404


@patch("db.get_event")
def test_register_no_spots(mock_get_event):
    mock_get_event.return_value = {"eventId": "evt-001", "availableSpots": 0}
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "Lambda", "register"))
    import handler as register_handler
    resp = register_handler.lambda_handler(_register_event({"name": "John", "email": "john@example.com", "eventId": "evt-001"}), {})
    assert resp["statusCode"] == 409


def test_register_invalid_body():
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "Lambda", "register"))
    import handler as register_handler
    resp = register_handler.lambda_handler(_register_event({}), {})
    assert resp["statusCode"] == 400


# ─── GET /events ─────────────────────────────────────────────────────────────

@patch("db.list_events")
def test_get_events(mock_list):
    mock_list.return_value = [{"eventId": "evt-001", "name": "Test Event", "availableSpots": 10}]
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "Lambda", "events"))
    import handler as events_handler
    resp = events_handler.lambda_handler({}, {})
    assert resp["statusCode"] == 200
    assert len(json.loads(resp["body"])) == 1


# ─── GET /registrations/{email} ──────────────────────────────────────────────

@patch("db.get_registrations_by_email")
def test_get_registrations(mock_query):
    mock_query.return_value = [{"registrationId": "reg-001", "email": "john@example.com"}]
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "Lambda", "registrations"))
    import handler as registrations_handler
    resp = registrations_handler.lambda_handler({"pathParameters": {"email": "john@example.com"}}, {})
    assert resp["statusCode"] == 200


def test_get_registrations_missing_email():
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "Lambda", "registrations"))
    import handler as registrations_handler
    resp = registrations_handler.lambda_handler({"pathParameters": {}}, {})
    assert resp["statusCode"] == 400


# ─── DELETE /registration/{id} ───────────────────────────────────────────────

@patch("db.increment_spots")
@patch("db.delete_registration")
@patch("db.get_registration")
def test_cancel_success(mock_get, mock_delete, mock_inc):
    mock_get.return_value = {"registrationId": "reg-001", "eventId": "evt-001", "status": "active"}
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "Lambda", "cancel"))
    import handler as cancel_handler
    resp = cancel_handler.lambda_handler({"pathParameters": {"id": "reg-001"}}, {})
    assert resp["statusCode"] == 200


@patch("db.get_registration")
def test_cancel_not_found(mock_get):
    mock_get.return_value = None
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "Lambda", "cancel"))
    import handler as cancel_handler
    resp = cancel_handler.lambda_handler({"pathParameters": {"id": "bad-id"}}, {})
    assert resp["statusCode"] == 404
