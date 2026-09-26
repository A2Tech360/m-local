#!/usr/bin/env python3
"""Create private local-only demo accounts through Jac's documented auth API."""
import argparse
import json
import os
from pathlib import Path
import secrets
import shlex
import urllib.error
import urllib.parse
import urllib.request
from uuid import UUID


def local_api(value):
    parsed = urllib.parse.urlsplit(value)
    if parsed.scheme != 'http' or parsed.hostname not in ('localhost', '127.0.0.1', '::1'):
        raise argparse.ArgumentTypeError('Use the local Jac API at http://localhost:8001.')
    if parsed.username or parsed.password or parsed.query or parsed.fragment or parsed.path not in ('', '/'):
        raise argparse.ArgumentTypeError('Supply only the local API origin.')
    return value.rstrip('/')


def post(api, path, body):
    req = urllib.request.Request(api + path, json.dumps(body).encode(),
                                 {'Content-Type': 'application/json'}, method='POST')
    try:
        with urllib.request.urlopen(req, timeout=20) as response:
            result = json.load(response)
    except urllib.error.HTTPError as error:
        raise RuntimeError(f'{path} returned HTTP {error.code}; no credentials were printed.') from None
    if not result.get('ok'):
        raise RuntimeError(f'{path} failed; inspect the local server log.')
    return result.get('data', {})


def private_write(path, text):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'w') as stream:
        stream.write(text)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--api', type=local_api, default='http://localhost:8001')
    args = parser.parse_args()
    directory = Path(__file__).resolve().parents[1] / '.jac'
    directory.mkdir(exist_ok=True)
    account_path = directory / 'qr-demo-accounts.json'
    env_path = directory / 'qr-demo.env'
    if account_path.exists() or env_path.exists():
        parser.error('Demo files already exist. Reuse them; this command never overwrites credentials.')
    accounts = {}
    suffix = secrets.token_hex(5)
    for role in ('student_a', 'student_b', 'merchant_leaf', 'merchant_noodle'):
        email = f'mlocal-{role}-{suffix}@example.test'
        password = secrets.token_urlsafe(24)
        post(args.api, '/user/register', {
            'identities': [{'type': 'email', 'value': email}],
            'credential': {'type': 'password', 'password': password},
        })
        login = post(args.api, '/user/login', {
            'identity': {'type': 'email', 'value': email},
            'credential': {'type': 'password', 'password': password},
        })
        root_id = str(UUID(login['root_id']))
        accounts[role] = {'email': email, 'password': password, 'root_id': root_id}
    mapping = {'arbor-leaf-kitchen': accounts['merchant_leaf']['root_id'],
               'maize-noodle-lab': accounts['merchant_noodle']['root_id']}
    private_write(account_path, json.dumps(accounts, indent=2) + '\n')
    private_write(env_path, 'export MLOCAL_MERCHANT_OWNERS=' + shlex.quote(json.dumps(mapping)) + '\n')
    print('Created .jac/qr-demo-accounts.json (private login details) and .jac/qr-demo.env.')
    print('Stop dev, run: source .jac/qr-demo.env; bash scripts/dev.sh')
    print('Keep these ignored local files private. Do not paste passwords into a PR or report.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, ValueError, KeyError) as error:
        raise SystemExit(str(error))
