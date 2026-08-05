import re

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def is_valid_email(email: str) -> bool:
    return bool(EMAIL_RE.match(email))


def validate_register_body(body: dict) -> str | None:
    if not body.get("name"):
        return "name is required"
    if not body.get("email"):
        return "email is required"
    if not is_valid_email(body["email"]):
        return "invalid email format"
    if not body.get("eventId"):
        return "eventId is required"
    return None
