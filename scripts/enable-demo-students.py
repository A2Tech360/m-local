#!/usr/bin/env python3
"""Add the explicit demo student allowlist without changing accounts or ownership."""
import argparse
import json
from pathlib import Path
import shlex
from uuid import UUID


def migrate(directory: Path):
    accounts = json.loads((directory / 'qr-demo-accounts.json').read_text())
    actors = [UUID(accounts[role]['root_id']).hex for role in ('student_a', 'student_b')]
    target = directory / 'qr-demo.env'
    text = target.read_text()
    if any(line.startswith('export MLOCAL_DEMO_STUDENTS=') for line in text.splitlines()):
        return False
    with target.open('a') as stream:
        stream.write('\nexport MLOCAL_DEMO_STUDENTS=' + shlex.quote(json.dumps(actors)) + '\n')
    return True


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--state-dir', type=Path, default=Path('.jac'))
    args = parser.parse_args()
    changed = migrate(args.state_dir.resolve())
    print('Demo student allowlist added; restart the server with qr-demo.env.' if changed else 'Demo student allowlist already configured.')
