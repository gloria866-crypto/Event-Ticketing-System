import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "Lambda", "shared"))
from validators import validate_register_body, is_valid_email


def test_valid_email():
    assert is_valid_email("user@example.com") is True


def test_invalid_email():
    assert is_valid_email("not-an-email") is False


def test_validate_register_body_valid():
    assert validate_register_body({"name": "John", "email": "john@example.com", "eventId": "evt-001"}) is None


def test_validate_register_body_missing_name():
    assert validate_register_body({"email": "john@example.com", "eventId": "evt-001"}) == "name is required"


def test_validate_register_body_short_name():
    assert validate_register_body({"name": "J", "email": "john@example.com", "eventId": "evt-001"}) == "name must be at least 2 characters"


def test_validate_register_body_missing_email():
    assert validate_register_body({"name": "John", "eventId": "evt-001"}) == "email is required"


def test_validate_register_body_invalid_email():
    assert validate_register_body({"name": "John", "email": "bad-email", "eventId": "evt-001"}) == "invalid email format"


def test_validate_register_body_missing_event_id():
    assert validate_register_body({"name": "John", "email": "john@example.com"}) == "eventId is required"
