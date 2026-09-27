"""Verify the isolated dataset app over HTTP; never prints private credentials."""
import json
import sys
import secrets
import urllib.request
import urllib.error
from pathlib import Path


def call(name, token='', **params):
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    request = urllib.request.Request(
        'http://127.0.0.1:8300/function/' + name,
        json.dumps(params).encode(), headers)
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            body = json.load(response)
    except urllib.error.HTTPError as error:
        if error.code in (401, 403):
            return {'ok': False, 'http_status': error.code}
        raise
    assert body['ok'], body
    return body['data']['result']


feed = call('home_feed')
assert feed['show_samples']
offers = [item['offer'] for item in feed['items']]
assert len(offers) > 450
assert all(o['is_demo'] for o in offers)
assert all(not any(label in o[field].lower() for label in ('test', 'demo', 'fictional', 'simulated'))
           for o in offers for field in ('restaurant', 'title', 'description', 'terms', 'eligibility'))
assert len({o['id'] for o in offers}) == len(offers)
places = call('list_places', limit=500, offset=0) + call('list_places', limit=500, offset=500)
assert len(places) == 841
assert len({p['id'] for p in places}) == 841
filtered = call('home_feed', price_range='3-6', diets='vegetarian', window='now')
assert 0 < len(filtered['items']) < len(offers)
assert all(300 <= item['price_cents'] <= 600 and 'vegetarian' in item['offer']['dietary']
           and item['offer']['state'] != 'scheduled' for item in filtered['items'])
again = call('home_feed')
assert {item['offer']['id'] for item in again['items']} == {o['id'] for o in offers}
active = next(o for o in offers if o['state'] == 'active' and o['remaining'] > 0)
assert not call('claim_offer', offer_id=active['id'])['ok']
runtime = Path(sys.argv[1]).resolve().parent
assert runtime.name.startswith('m-local-dataset-test.') and runtime.parent == Path('/tmp')
sys.path.insert(0, str(runtime))
from services.email_codes import CodeStore
codes = []
challenge = CodeStore(runtime / '.jac/onboarding').request(
    'dataset' + secrets.token_hex(4), 'student', 'Dataset Test Student',
    lambda _email, code: codes.append(code))
session = call('verify_email_code', challenge=challenge['challenge'], code=codes[0])
assert session['ok']
token = session['token']
claim = call('claim_offer', token=token, offer_id=active['id'])
assert claim['ok'] and claim['qr_payload'].startswith('mlocal:v1:')
repeated = call('claim_offer', token=token, offer_id=active['id'])
assert repeated['qr_payload'] == claim['qr_payload']
assert call('cancel_claim', token=token, offer_id=active['id'])['ok']
result = {'places': len(places), 'test_offers': len(offers),
          'filtered_offers': len(filtered['items']), 'duplicate_offers': 0,
          'guest_claim_denied': True, 'repeat_read_stable': True,
          'student_claim_retry_cancel': True}
Path(sys.argv[1]).write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result))
