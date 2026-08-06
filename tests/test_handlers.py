import importlib.util
import json
import sys
from pathlib import Path
from unittest.mock import patch


PROJECT_ROOT = Path(__file__).resolve().parent.parent
LAMBDA_ROOT = PROJECT_ROOT / "Lambda"
SHARED_DIR = LAMBDA_ROOT / "shared"
sys.path.insert(0, str(SHARED_DIR))


def load_handler(handler_directory):
    """Load each handler.py file under a unique name for isolated tests."""
    module_name = f"{handler_directory}_handler"
    handler_path = LAMBDA_ROOT / handler_directory / "handler.py"
    sys.modules.pop(module_name, None)

    spec = importlib.util.spec_from_file_location(module_name, handler_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _register_event(body):
    return {"body": json.dumps(body), "pathParameters": {}}


@patch("db.decrement_spots")
@patch("db.put_registration")
@patch("db.get_event")
def test_register_success(mock_get_event, mock_put, mock_dec):
    mock_get_event.return_value = {"eventId": "evt-001", "availableSpots": 10}
    register_handler = load_handler("register")

    response = register_handler.lambda_handler(
        _register_event({"name": "John", "email": "john@example.com", "eventId": "evt-001"}),
        {},
    )

    assert response["statusCode"] == 201
    assert "registrationId" in json.loads(response["body"])


@patch("db.get_event")
def test_register_event_not_found(mock_get_event):
    mock_get_event.return_value = None
    register_handler = load_handler("register")

    response = register_handler.lambda_handler(
        _register_event({"name": "John", "email": "john@example.com", "eventId": "bad-id"}),
        {},
    )

    assert response["statusCode"] == 404


@patch("db.get_event")
def test_register_no_spots(mock_get_event):
    mock_get_event.return_value = {"eventId": "evt-001", "availableSpots": 0}
    register_handler = load_handler("register")

    response = register_handler.lambda_handler(
        _register_event({"name": "John", "email": "john@example.com", "eventId": "evt-001"}),
        {},
    )

    assert response["statusCode"] == 409


def test_register_invalid_body():
    register_handler = load_handler("register")
    response = register_handler.lambda_handler(_register_event({}), {})
    assert response["statusCode"] == 400


@patch("db.list_events")
def test_get_events(mock_list):
    mock_list.return_value = [{"eventId": "evt-001", "name": "Test Event", "availableSpots": 10}]
    events_handler = load_handler("events")
    response = events_handler.lambda_handler({}, {})

    assert response["statusCode"] == 200
    assert len(json.loads(response["body"])) == 1


@patch("db.get_registrations_by_email")
def test_get_registrations(mock_query):
    mock_query.return_value = [{"registrationId": "reg-001", "email": "john@example.com"}]
    registrations_handler = load_handler("registrations")
    response = registrations_handler.lambda_handler(
        {"pathParameters": {"email": "john@example.com"}},
        {},
    )

    assert response["statusCode"] == 200


def test_get_registrations_missing_email():
    registrations_handler = load_handler("registrations")
    response = registrations_handler.lambda_handler({"pathParameters": {}}, {})
    assert response["statusCode"] == 400


@patch("db.increment_spots")
@patch("db.delete_registration")
@patch("db.get_registration")
def test_cancel_success(mock_get, mock_delete, mock_inc):
    mock_get.return_value = {"registrationId": "reg-001", "eventId": "evt-001", "status": "active"}
    cancel_handler = load_handler("cancel")
    response = cancel_handler.lambda_handler({"pathParameters": {"id": "reg-001"}}, {})

    assert response["statusCode"] == 200


@patch("db.get_registration")
def test_cancel_not_found(mock_get):
    mock_get.return_value = None
    cancel_handler = load_handler("cancel")
    response = cancel_handler.lambda_handler({"pathParameters": {"id": "bad-id"}}, {})

    assert response["statusCode"] == 404
