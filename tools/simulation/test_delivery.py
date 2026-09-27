"""Append to the ISOLATED COPY of email_codes.py for local testing only.

No email leaves the machine. Never deploy this fixture or append it in the repo.
"""


def delivery_ready() -> bool:
    return True


def send_code(email: str, code: str):
    directory = Path('.jac/test-outbox')
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    destination = directory / 'latest.json'
    fd = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, 'w') as stream:
        json.dump({'email': email, 'code': code, 'test_only': True}, stream)
