"""Private single-host onboarding state, separate from the public Jac graph.

SQLite transactions serialize OTP consumption across threads/processes. All
replicas must share this directory on one host; do not deploy independent copies.
"""
from contextlib import contextmanager
from email.message import EmailMessage
import hashlib
import hmac
import json
import os
from pathlib import Path
import re
import secrets
import smtplib
import sqlite3
import ssl
import time


def account_email(value: str, kind: str) -> str:
    value = value.strip().lower()
    if kind == 'student':
        if not re.fullmatch(r'[a-z][a-z0-9]{1,31}', value):
            raise ValueError('Enter only your U-M uniqname, before @umich.edu.')
        return value + '@umich.edu'
    if kind != 'business' or len(value) > 254 or not re.fullmatch(r'[a-z0-9.!#$%&\x27*+/=?^_`{|}~-]+@[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?\.[a-z]{2,63}', value):
        raise ValueError('Enter a valid work email address.')
    return value


def validated_name(value: str) -> str:
    value = value.strip()
    if not 1 <= len(value) <= 80 or any(ord(c) < 32 or 127 <= ord(c) < 160 for c in value):
        raise ValueError('Enter your name (up to 80 characters, without control characters).')
    return value


class CodeStore:
    def __init__(self, directory: Path, clock=time.time):
        self.clock = clock
        self.directory = directory
        directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        key_path = directory / 'code.key'
        try:
            fd = os.open(key_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        except FileExistsError:
            pass
        else:
            with os.fdopen(fd, 'wb') as stream:
                stream.write(secrets.token_bytes(32))
        self.key = key_path.read_bytes()
        if len(self.key) != 32:
            raise RuntimeError('Onboarding key is unavailable.')
        self.path = directory / 'onboarding.sqlite3'
        with self.transaction() as db:
            db.execute('CREATE TABLE IF NOT EXISTS codes (challenge TEXT PRIMARY KEY, email TEXT, kind TEXT, name TEXT, digest TEXT, expires REAL, attempts INTEGER, delivered INTEGER)')
            db.execute('CREATE TABLE IF NOT EXISTS sends (email TEXT, at REAL)')
            db.execute('CREATE INDEX IF NOT EXISTS sends_email_at ON sends(email, at)')
            db.execute('CREATE TABLE IF NOT EXISTS accounts (actor TEXT PRIMARY KEY, email TEXT UNIQUE, kind TEXT, name TEXT)')
            db.execute('CREATE TABLE IF NOT EXISTS display_names (actor TEXT PRIMARY KEY, name TEXT)')
            db.execute('CREATE TABLE IF NOT EXISTS provisioning (email TEXT PRIMARY KEY, marker TEXT, kind TEXT, name TEXT)')
            db.execute('CREATE TABLE IF NOT EXISTS drafts (actor TEXT PRIMARY KEY, body TEXT, updated REAL)')
            db.execute('CREATE TABLE IF NOT EXISTS imports (actor TEXT, at REAL)')
        os.chmod(self.path, 0o600)

    @contextmanager
    def transaction(self):
        db = sqlite3.connect(self.path, timeout=15, isolation_level=None)
        db.row_factory = sqlite3.Row
        try:
            db.execute('BEGIN IMMEDIATE')
            yield db
            db.commit()
        except Exception:
            db.rollback()
            raise
        finally:
            db.close()

    def digest(self, challenge, code):
        return hmac.new(self.key, (challenge + ':' + code).encode(), hashlib.sha256).hexdigest()

    def request(self, value, kind, name, send):
        email = account_email(value, kind)
        # Blank means returning sign-in; account existence is checked only after
        # inbox proof. Named requests keep the existing create-or-resume flow.
        name = validated_name(name) if name else ''
        now = self.clock()
        challenge = secrets.token_urlsafe(32)
        code = f'{secrets.randbelow(1000000):06d}'
        with self.transaction() as db:
            db.execute('DELETE FROM sends WHERE at < ?', (now - 86400,))
            db.execute('DELETE FROM codes WHERE expires < ?', (now,))
            recent = db.execute('SELECT at FROM sends WHERE email=? AND at>?', (email, now - 3600)).fetchall()
            if recent and now - max(r['at'] for r in recent) < 60:
                raise ValueError('Please wait 60 seconds before requesting another code.')
            if len(recent) >= 5:
                raise ValueError('Too many code requests. Please try again in an hour.')
            hourly = db.execute('SELECT COUNT(*) FROM sends WHERE at>?', (now - 3600,)).fetchone()[0]
            daily = db.execute('SELECT COUNT(*) FROM sends').fetchone()[0]
            if hourly >= 60 or daily >= 300:
                raise ValueError('Email sign-in is busy. Please try again later.')
            db.execute('INSERT INTO sends VALUES (?,?)', (email, now))
            db.execute('DELETE FROM codes WHERE email=?', (email,))
            db.execute('INSERT INTO codes VALUES (?,?,?,?,?,?,0,0)', (challenge, email, kind, name, self.digest(challenge, code), now + 600))
        try:
            send(email, code)
        except Exception:
            with self.transaction() as db:
                db.execute('DELETE FROM codes WHERE challenge=?', (challenge,))
            raise ValueError('We could not send the email. Please try again later.') from None
        with self.transaction() as db:
            db.execute('UPDATE codes SET delivered=1 WHERE challenge=?', (challenge,))
        return {'ok': True, 'challenge': challenge, 'email': email, 'retry_after': 60,
                'message': 'Check your inbox for a six-digit code. It expires in 10 minutes.'}

    def consume(self, challenge, code):
        result = None
        if len(challenge) > 128 or len(code) > 20:
            raise ValueError('That code is invalid or expired. Request a new code.')
        with self.transaction() as db:
            row = db.execute('SELECT * FROM codes WHERE challenge=?', (challenge,)).fetchone()
            if row and row['delivered'] and row['expires'] > self.clock() and row['attempts'] < 5:
                db.execute('UPDATE codes SET attempts=attempts+1 WHERE challenge=?', (challenge,))
                if hmac.compare_digest(self.digest(challenge, code.strip()), row['digest']):
                    result = {key: row[key] for key in ('email', 'kind', 'name')}
                    db.execute('DELETE FROM codes WHERE challenge=?', (challenge,))
        if result is None:
            raise ValueError('That code is invalid or expired. Request a new code after five attempts.')
        return result

    def pending_count(self):
        with self.transaction() as db:
            return db.execute('SELECT COUNT(*) FROM codes WHERE delivered=1').fetchone()[0]

    def remember_account(self, actor, email, kind, name):
        with self.transaction() as db:
            db.execute('INSERT OR IGNORE INTO accounts VALUES (?,?,?,?)', (actor, email, kind, name))
            db.execute('DELETE FROM provisioning WHERE email=?', (email,))

    def provisioning(self, email, kind=None, name=None):
        with self.transaction() as db:
            if kind is not None:
                db.execute('INSERT OR IGNORE INTO provisioning VALUES (?,?,?,?)', (email, secrets.token_urlsafe(32), kind, name))
            row = db.execute('SELECT * FROM provisioning WHERE email=?', (email,)).fetchone()
            return dict(row) if row else {}

    def account(self, actor):
        with self.transaction() as db:
            row = db.execute('SELECT email,kind,name FROM accounts WHERE actor=?', (actor,)).fetchone()
            return dict(row) if row else {}

    def display_name(self, actor: str, fallback: str = '') -> str:
        with self.transaction() as db:
            row = db.execute('SELECT name FROM accounts WHERE actor=?', (actor,)).fetchone()
            if row is None:
                row = db.execute('SELECT name FROM display_names WHERE actor=?', (actor,)).fetchone()
            return row['name'] if row else fallback

    def save_display_name(self, actor: str, name: str) -> str:
        if not actor:
            raise ValueError('Sign in before editing your profile.')
        name = validated_name(name)
        with self.transaction() as db:
            changed = db.execute('UPDATE accounts SET name=? WHERE actor=?', (name, actor)).rowcount
            if not changed:
                # Demo and other runtime accounts may have preferences without
                # gaining a verified email record or application authority.
                db.execute('INSERT INTO display_names VALUES (?,?) ON CONFLICT(actor) DO UPDATE SET name=excluded.name', (actor, name))
        return name

    def reserve_import(self, actor):
        now = self.clock()
        with self.transaction() as db:
            db.execute('DELETE FROM imports WHERE at<?', (now - 3600,))
            recent = db.execute('SELECT at FROM imports WHERE actor=?', (actor,)).fetchall()
            count = db.execute('SELECT COUNT(*) FROM imports').fetchone()[0]
            if len(recent) >= 5 or count >= 30 or (recent and now - max(r['at'] for r in recent) < 30):
                raise ValueError('Please wait before importing again. Each account can import five sites per hour.')
            db.execute('INSERT INTO imports VALUES (?,?)', (actor, now))

    def save_draft(self, actor, body):
        with self.transaction() as db:
            db.execute('INSERT INTO drafts VALUES (?,?,?) ON CONFLICT(actor) DO UPDATE SET body=excluded.body,updated=excluded.updated', (actor, json.dumps(body), self.clock()))

    def draft(self, actor):
        with self.transaction() as db:
            row = db.execute('SELECT body FROM drafts WHERE actor=?', (actor,)).fetchone()
            return json.loads(row['body']) if row else {}


def store() -> CodeStore:
    return CodeStore(Path(os.environ.get('MLOCAL_ONBOARDING_DIR', '.jac/onboarding')).resolve())


def delivery_ready() -> bool:
    return all(os.environ.get(name, '').strip() for name in ('MLOCAL_SMTP_HOST', 'MLOCAL_SMTP_FROM', 'MLOCAL_SMTP_USERNAME', 'MLOCAL_SMTP_PASSWORD'))


def send_code(email: str, code: str):
    if not delivery_ready():
        raise ValueError('Email sign-in is not enabled yet. The host needs to configure an email sender.')
    message = EmailMessage()
    message['From'] = os.environ['MLOCAL_SMTP_FROM']
    message['To'] = email
    message['Subject'] = f'{code} is your M-Local verification code'
    message.set_content(f'Your M-Local code is: {code}\n\nIt expires in 10 minutes and works once.\nIf you did not request this code, ignore this email.\nM-Local will never ask for your university password.')
    port = int(os.environ.get('MLOCAL_SMTP_PORT', '587'))
    context = ssl.create_default_context()
    if port == 465:
        smtp = smtplib.SMTP_SSL(os.environ['MLOCAL_SMTP_HOST'], port, timeout=10, context=context)
    else:
        smtp = smtplib.SMTP(os.environ['MLOCAL_SMTP_HOST'], port, timeout=10)
    with smtp:
        if port != 465:
            smtp.starttls(context=context)
        smtp.login(os.environ['MLOCAL_SMTP_USERNAME'], os.environ['MLOCAL_SMTP_PASSWORD'])
        refused = smtp.send_message(message)
        if refused:
            raise OSError('Recipient refused')
