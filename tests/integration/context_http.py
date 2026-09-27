#!/usr/bin/env python3
"""Real Jac context reads across private fictional accounts and server restart.

Linux/WSL only. Uses a fresh retained store and a test-only read adapter, never
the running demo. Logs named checks, never passwords, tokens, or account IDs.
"""
import importlib.util
import json
import os
from pathlib import Path
import secrets
import shutil
import signal
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('provision', ROOT / 'scripts/provision-demo.py')
provision = importlib.util.module_from_spec(spec)
spec.loader.exec_module(provision)


def public_context(value):
    """Compare the DTO contract, excluding Jac's per-response object _jac_id."""
    fields = ('id', 'summary', 'publisher', 'source_url', 'checked_at',
              'valid_from', 'valid_until', 'state', 'is_demo', 'entrance_instruction')
    return {'state': value['state'], 'notices': [
        {field: notice[field] for field in fields} for notice in value['notices']]}


def main():
    if os.name != 'posix':
        raise RuntimeError('Run this check in WSL/Linux with Jac 0.37.23.')
    jac = os.environ.get('JAC_BIN', str(Path.home() / '.local/share/m-local/runtimes/0.37.23/jac'))
    version = subprocess.check_output([jac, '--version'], text=True).split()
    if version[:2] != ['jac', '0.37.23']:
        raise RuntimeError('Expected Jac 0.37.23.')
    cache = Path(os.environ.get('JAC_CACHE_HOME', str(Path.home() / '.cache/m-local')))
    (cache / 'test-runs').mkdir(parents=True, exist_ok=True)
    fixture = Path(tempfile.mkdtemp(prefix='context-http-', dir=cache / 'test-runs'))
    (fixture / 'services').mkdir()
    for source in (ROOT / 'services').glob('*.jac'):
        shutil.copy2(source, fixture / 'services' / source.name)
    shutil.copy2(ROOT / 'jac.toml', fixture / 'jac.toml')
    shutil.copy2(ROOT / 'tests/integration/context_probe.jac', fixture / 'main.jac')
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    api = f'http://127.0.0.1:{port}'
    child = None
    stream = None
    results = []

    def check(condition, name):
        results.append(bool(condition))
        print(('PASS ' if condition else 'FAIL ') + name, flush=True)

    def stop():
        nonlocal child, stream
        if child is not None and child.poll() is None:
            os.killpg(child.pid, signal.SIGTERM)
            try:
                child.wait(timeout=15)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait(timeout=10)
        child = None
        if stream:
            stream.close()
            stream = None

    def start(owners=None):
        nonlocal child, stream
        env = os.environ.copy()
        env.pop('MLOCAL_MERCHANT_OWNERS', None)
        if owners is not None:
            env['MLOCAL_MERCHANT_OWNERS'] = json.dumps(owners)
        pg = Path.home() / '.cache/jac/pg/dist/linux-amd64-18.6.0'
        if (pg / 'bin/postgres').is_file():
            env.setdefault('JAC_PG_DIST', str(pg))
        path = fixture / f'server-{time.time_ns()}.log'
        stream = os.fdopen(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), 'w')
        child = subprocess.Popen([jac, 'run', '--serve', '--no-client', '--host', '127.0.0.1',
                                  '--port', str(port), 'main.jac'], cwd=fixture, env=env,
                                 stdin=subprocess.DEVNULL, stdout=stream,
                                 stderr=subprocess.STDOUT, start_new_session=True)
        deadline = time.monotonic() + 90
        while time.monotonic() < deadline:
            if child.poll() is not None:
                raise RuntimeError('Test API stopped before readiness; private log retained.')
            try:
                with urllib.request.urlopen(api + '/healthz/ready', timeout=3) as response:
                    if response.status == 200:
                        return
            except (OSError, urllib.error.URLError):
                time.sleep(0.5)
        raise RuntimeError('Test API readiness exceeded 90 seconds; private log retained.')

    def call(name, token='', **params):
        headers = {'Content-Type': 'application/json'}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        request = urllib.request.Request(api + '/function/' + name, json.dumps(params).encode(),
                                         headers, method='POST')
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                envelope = json.load(response)
        except urllib.error.HTTPError as error:
            raise RuntimeError(f'{name} returned HTTP {error.code}; no response data printed.') from None
        if not envelope.get('ok'):
            raise RuntimeError(name + ' returned a runtime error; no response data printed.')
        return envelope['data']['result']

    try:
        print('Isolated context HTTP fixture: ' + str(fixture), flush=True)
        start()
        accounts = {}
        for role in ('student_a', 'student_b', 'merchant_leaf', 'merchant_noodle'):
            email = 'context-' + secrets.token_hex(8) + '@example.test'
            password = secrets.token_urlsafe(24)
            provision.post(api, '/user/register', {
                'identities': [{'type': 'email', 'value': email}],
                'credential': {'type': 'password', 'password': password},
            })
            accounts[role] = provision.post(api, '/user/login', {
                'identity': {'type': 'email', 'value': email},
                'credential': {'type': 'password', 'password': password},
            })
        owners = {'arbor-leaf-kitchen': accounts['merchant_leaf']['root_id'],
                  'maize-noodle-lab': accounts['merchant_noodle']['root_id']}
        stop()
        start(owners)
        # The first catalog request is authenticated: notices must not stay private
        # to whichever student happens to initialize the shared demo catalog.
        offers = call('list_offers', accounts['student_a']['token'])
        target = next(item for item in offers if item['restaurant'].startswith('Maize'))
        location = target['location_id']
        contexts = {}
        for role in ('student_a', 'guest', 'student_b', 'merchant_leaf'):
            token = '' if role == 'guest' else accounts[role]['token']
            contexts[role] = public_context(call('probe_context', token, location_id=location))
            context = contexts[role]
            check(context['state'] == 'current' and len(context['notices']) == 1,
                  role + ' reads the shared current notice')
        baseline = contexts['student_a']
        check(all(value == baseline for value in contexts.values()), 'all sessions receive the same public context')
        check(call('current_session', accounts['merchant_leaf']['token'])['role'] == 'merchant',
              'the merchant read used a real provisioned merchant session')
        check(len(baseline['notices']) == 1 and baseline['notices'][0]['is_demo']
              and baseline['notices'][0]['source_url'] == ''
              and baseline['notices'][0]['entrance_instruction'] == '',
              'simulation has no invented source or entrance instruction')
        other = next(item for item in offers if not item['restaurant'].startswith('Maize'))
        unrelated = call('probe_context', accounts['student_b']['token'], location_id=other['location_id'])
        check(unrelated['state'] == 'none' and unrelated['notices'] == [], 'unrelated location stays unknown')
        stop()
        start(owners)
        check(public_context(call('probe_context', location_id=location)) == baseline,
              'restart retains notice identity, evidence dates, and public visibility')
        print(f'Context HTTP: {sum(results)}/{len(results)} passed.', flush=True)
        return 0 if all(results) else 1
    finally:
        stop()


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, KeyError, StopIteration) as error:
        raise SystemExit('FAIL ' + str(error))
