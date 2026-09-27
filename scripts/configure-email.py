#!/usr/bin/env python3
"""Configure the local SMTP sender without putting its secret in chat or shell history."""
import argparse
import getpass
import os
from pathlib import Path
import re
import secrets
import shlex
import smtplib
import ssl

PREFIX = 'MLOCAL_SMTP_'


def read_settings(path):
    values = {}
    if not path.exists():
        return values
    for line in path.read_text().splitlines():
        if line.startswith('export ' + PREFIX):
            words = shlex.split(line, comments=True)
            if len(words) == 2 and '=' in words[1]:
                key, value = words[1].split('=', 1)
                values[key] = value
    return values


def save_settings(path, values):
    old = path.read_text() if path.exists() else ''
    retained = [line for line in old.splitlines() if not line.startswith('export ' + PREFIX)]
    content = '\n'.join(retained).rstrip() + '\n\n'
    for key, value in values.items():
        if key not in {PREFIX + suffix for suffix in ('HOST', 'PORT', 'USERNAME', 'PASSWORD', 'FROM')}:
            raise ValueError('Unexpected setting.')
        if '\n' in value or '\r' in value or '\x00' in value:
            raise ValueError('Settings must be a single line.')
        content += f'export {key}={shlex.quote(value)}\n'
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temp = path.with_name(path.name + '.tmp-' + secrets.token_hex(6))
    fd = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(content)
        os.replace(temp, path)
        os.chmod(path, 0o600)
    finally:
        temp.unlink(missing_ok=True)


def check_settings(values):
    context = ssl.create_default_context()
    port = int(values.get(PREFIX + 'PORT', '465'))
    cls = smtplib.SMTP_SSL if port == 465 else smtplib.SMTP
    options = {'context': context} if port == 465 else {}
    with cls(values[PREFIX + 'HOST'], port, timeout=15, **options) as smtp:
        if port != 465:
            smtp.starttls(context=context)
        smtp.login(values[PREFIX + 'USERNAME'], values[PREFIX + 'PASSWORD'])


def collect_settings(provider):
    defaults = {'resend': ('smtp.resend.com', '465', 'resend'), 'gmail': ('smtp.gmail.com', '465', ''), 'custom': ('', '465', '')}
    host, port, username = defaults[provider]
    print('This saves the sender on this computer, outside Git. No email will be sent.')
    if provider == 'gmail':
        print('Use your dedicated Gmail account and its 16-character app password.')
        print('Do not enter your normal Google or university password.')
        sender = input('Dedicated Gmail address: ').strip().lower()
        if not re.fullmatch(r'[a-z0-9.]+@gmail\.com', sender):
            raise ValueError('Use a dedicated personal Gmail account for this setup.')
        username = sender
    else:
        host = input(f'SMTP host [{host}]: ').strip() or host
        port = input(f'SMTP port [{port}]: ').strip() or port
        username = input(f'SMTP username [{username}]: ').strip() or username
        sender = input('Authorized sender email address: ').strip()
    password = getpass.getpass('App password / provider API key (hidden): ')
    if provider == 'gmail':
        password = password.replace(' ', '')
        if not re.fullmatch(r'[a-z]{16}', password):
            raise ValueError('Use the 16-character Google app password.')
    if not host or not username or not password or not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', sender):
        raise ValueError('Host, username, sender email and provider credential are required.')
    if port not in ('465', '587'):
        raise ValueError('Use port 465 (TLS) or 587 (STARTTLS).')
    return {PREFIX + key: value for key, value in dict(HOST=host, PORT=port, USERNAME=username, PASSWORD=password, FROM=sender).items()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--provider', choices=('resend', 'gmail', 'custom'), default='resend')
    parser.add_argument('--check', action='store_true', help='Check saved SMTP credentials without sending email.')
    args = parser.parse_args()
    path = Path(__file__).resolve().parents[1] / '.jac/onboarding.env'
    if args.check:
        check_settings(read_settings(path))
        print('SMTP authentication succeeded. Inbox delivery still needs a real code test.')
        return
    values = collect_settings(args.provider)
    check_settings(values)
    save_settings(path, values)
    print('SMTP login verified and configuration saved. Restart the app, then test a code to an inbox you control.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, smtplib.SMTPException):
        raise SystemExit('Setup could not be completed. Check the provider, authorized sender, port and credential. No secret was printed.') from None
