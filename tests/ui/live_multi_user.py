#!/usr/bin/env python3
"""Opt-in four-session Chromium acceptance through the disposable local gateway.

Run after tests/integration/multi_user_http.py creates .jac/multi-user-check.json
in the isolated onboarding-check workspace. The only origin is 127.0.0.1:8241,
whose gateway forwards to the disposable Jac app on 8240. All RPCs are real;
no email is sent and no requests are intercepted. Tokens are never printed.
"""
import argparse
import json
from pathlib import Path
import secrets

from playwright.sync_api import expect, sync_playwright


ORIGIN = 'http://127.0.0.1:8241'


def rpc(page, endpoint):
    """Read the real server using this page's own stored session."""
    assert endpoint in {'current_session', 'get_account_profile', 'merchant_portal', 'home_feed'}
    return page.evaluate('''async (endpoint) => {
        const token = localStorage.getItem('jac_token');
        const headers = {'Content-Type': 'application/json'};
        if (token) headers.Authorization = 'Bearer ' + token;
        const response = await fetch('/function/' + endpoint, {
            method: 'POST', headers, body: '{}'
        });
        if (!response.ok) throw new Error(endpoint + ': HTTP ' + response.status);
        const envelope = await response.json();
        if (!envelope.ok || !envelope.data || !('result' in envelope.data))
            throw new Error(endpoint + ': invalid RPC response');
        return envelope.data.result;
    }''', endpoint)


def session_matches(page, user):
    current = rpc(page, 'current_session')
    assert current['authenticated'], 'Expected an authenticated session'
    assert current['actor_id'] == user['actor_id'], 'A browser received another actor identity'
    assert current['role'] == ('merchant' if user['kind'] == 'business' else 'student')
    assert current['display_name'] == user['name'], 'Session name changed across users'
    if user['kind'] == 'business':
        assert current['restaurant_id'] == user['restaurant_id'], 'Restaurant ownership changed'


def phone_fits(page):
    assert page.evaluate('document.documentElement.scrollWidth <= innerWidth'), 'UI overflows 390px'


def draft_values(page):
    return page.get_by_role('form', name='New offer', exact=True).locator('input, textarea').evaluate_all(
        '(fields) => Object.fromEntries(fields.map(field => [field.placeholder, field.value]))')


def start_draft(page, title, price, index):
    page.get_by_text('Manage', exact=True).click()
    page.get_by_role('button', name='New offer', exact=True).click()
    form = page.get_by_role('form', name='New offer', exact=True)
    form.get_by_placeholder('Lunch bowl for $7').fill(title)
    form.get_by_placeholder('What the student gets').fill(f'Fictional meal from business {index}')
    form.get_by_placeholder('7.00', exact=True).fill(price)
    form.get_by_placeholder('11.50', exact=True).fill('12.00')
    # Chromium supplies Detroit's timezone data on Windows as well as Linux.
    start, end = page.evaluate('''() => [-5, 120].map(minutes => {
        const date = new Date(Date.now() + minutes * 60000);
        return new Date(date.getTime() - date.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
    })''')
    form.get_by_label('Starts *', exact=True).fill(start)
    form.get_by_label('Ends *', exact=True).fill(end)
    form.get_by_placeholder('10', exact=True).fill(str(5 + index))
    form.get_by_placeholder('Students with a valid ID').fill(f'Valid student ID, fixture {index}')
    form.get_by_placeholder('One per student. Dine-in only.').fill(f'One fictional meal from business {index}.')
    phone_fits(page)
    return draft_values(page)


def publish(page, title):
    with page.expect_response(lambda response: response.url == ORIGIN + '/function/save_offer'
                              and response.request.method == 'POST') as pending:
        page.get_by_role('button', name='Publish offer', exact=True).click()
    response = pending.value
    assert response.ok, 'Offer publication returned an HTTP failure'
    envelope = response.json()
    assert envelope.get('ok') and envelope.get('data', {}).get('result', {}).get('ok'), 'Offer publication failed'
    offer_id = envelope['data']['result']['code']
    assert offer_id, 'Confirmed publication did not return an offer ID'
    expect(page.get_by_role('form', name='New offer', exact=True)).to_have_count(0)
    expect(page.get_by_text(title, exact=True)).to_have_count(1)
    return offer_id


def refresh_feed(page, expected):
    page.get_by_text('Offers', exact=True).click()
    with page.expect_response(lambda response: response.url == ORIGIN + '/function/home_feed'
                              and response.request.method == 'POST') as pending:
        page.get_by_role('button', name='Refresh offers', exact=True).click()
    response = pending.value
    assert response.ok, 'Feed refresh returned an HTTP failure'
    envelope = response.json()
    assert envelope.get('ok'), 'Feed refresh returned a runtime failure'
    feed = envelope['data']['result']
    assert isinstance(feed['items'], list), 'Feed response is not a catalog'
    returned = {item['offer']['id'] for item in feed['items']}
    assert set(expected).issubset(returned), 'Published offers were absent from another session'
    for title in expected.values():
        expect(page.get_by_text(title, exact=True)).to_have_count(1)
    expect(page.get_by_role('button', name='Refresh offers', exact=True)).to_be_enabled()
    phone_fits(page)


def save_name(page, name):
    page.get_by_placeholder('Display name').fill(name)
    page.get_by_role('button', name='Save account', exact=True).click()
    expect(page.get_by_text('Profile saved.', exact=True)).to_be_visible()
    expect(page.get_by_role('button', name='Save account', exact=True)).to_be_disabled()
    assert rpc(page, 'get_account_profile')['display_name'] == name, 'Account edit did not persist'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--workspace', required=True, type=Path)
    parser.add_argument('--screenshots', type=Path, help='Optional directory for phone-width evidence')
    args = parser.parse_args()
    workspace = args.workspace.resolve()
    if workspace.name != 'onboarding-check' or not workspace.is_dir():
        raise SystemExit('Only the existing disposable onboarding-check workspace is supported.')
    receipt = json.loads((workspace / '.jac/multi-user-check.json').read_text(encoding='utf-8'))
    users = receipt['users']
    assert len(users) == 4 and [user['kind'] for user in users] == ['student', 'student', 'business', 'business']
    assert len({user['token'] for user in users}) == 4, 'Fixture sessions must be independent'
    assert len({user['actor_id'] for user in users}) == 4, 'Fixture actors must be independent'
    assert len({user['restaurant_id'] for user in users[2:]}) == 2, 'Businesses must have different restaurants'
    if args.screenshots:
        args.screenshots.mkdir(parents=True, exist_ok=True)
    suffix = receipt['run'] + '-' + secrets.token_hex(3)
    titles = ['Device A lunch ' + suffix, 'Device B lunch ' + suffix]
    errors = []
    with sync_playwright() as runtime:
        browser = runtime.chromium.launch(headless=True)
        contexts = [browser.new_context(viewport={'width': 390, 'height': 844},
                                       timezone_id='America/Detroit') for _ in users]
        pages = [context.new_page() for context in contexts]
        try:
            for index, (page, user) in enumerate(zip(pages, users)):
                page.set_default_timeout(15000)
                page.on('pageerror', lambda error, index=index: errors.append(f'Context {index + 1}: {error}'))
                page.goto(ORIGIN, wait_until='networkidle')
                # Seed exactly once; an init script would restore the token after logout.
                page.evaluate('''({token, audience}) => {
                    localStorage.setItem('jac_token', token);
                    localStorage.setItem('mlocal_audience', audience);
                }''', {'token': user['token'], 'audience': user['kind']})
                page.reload(wait_until='networkidle')
                expect(page.get_by_role('button', name='Sign out', exact=True)).to_be_visible()
                session_matches(page, user)
                assert rpc(page, 'get_account_profile')['email'] == user['email'], 'Private email crossed sessions'
                phone_fits(page)
            student_a, student_b, business_a, business_b = pages
            print('PASS four simultaneous 390px browser contexts have distinct verified actors and storage')

            draft_a = start_draft(business_a, titles[0], '3.50', 1)
            draft_b = start_draft(business_b, titles[1], '8.25', 2)
            assert draft_a != draft_b, 'The two composers must contain different unsaved values'
            for page in (student_a, student_b):
                unseen = {item['offer']['title'] for item in rpc(page, 'home_feed')['items']}
                assert not set(titles).intersection(unseen), 'An unsaved composer was published'
            first_id = publish(business_a, titles[0])
            for page in (student_a, student_b):
                refresh_feed(page, {first_id: titles[0]})
            assert draft_values(business_b) == draft_b, 'Publishing in one session changed another draft'
            refresh_feed(business_b, {first_id: titles[0]})
            business_b.get_by_text('Manage', exact=True).click()
            assert draft_values(business_b) == draft_b, 'Refreshing shared offers lost a private draft'
            if args.screenshots:
                business_b.get_by_placeholder('Lunch bowl for $7').scroll_into_view_if_needed()
                business_b.screenshot(path=str(args.screenshots / 'second-business-retained-draft-390.png'))
            second_id = publish(business_b, titles[1])
            expected = {first_id: titles[0], second_id: titles[1]}
            for page in pages:
                refresh_feed(page, expected)
            for page, own_id, other_id in ((business_a, first_id, second_id), (business_b, second_id, first_id)):
                owned = {offer['id'] for offer in rpc(page, 'merchant_portal')['offers']}
                assert own_id in owned and other_id not in owned, 'Private merchant catalog crossed owners'
            if args.screenshots:
                student_b.get_by_text(titles[1], exact=True).scroll_into_view_if_needed()
                student_b.screenshot(path=str(args.screenshots / 'student-shared-offers-390.png'))
            print('PASS both publications reach all sessions while business drafts and management stay separate')

            for page in (student_a, student_b):
                page.get_by_role('button', name='Account', exact=True).click()
            expect(student_b.get_by_placeholder('Display name')).to_have_value(users[1]['name'])
            renamed = 'Browser student A ' + suffix
            save_name(student_a, renamed)
            expect(student_b.get_by_placeholder('Display name')).to_have_value(users[1]['name'])
            assert rpc(student_b, 'get_account_profile')['display_name'] == users[1]['name'], 'Account edit leaked'
            assert rpc(student_a, 'current_session')['actor_id'] == users[0]['actor_id'], 'Edit changed actor identity'
            for page in (student_a, student_b):
                page.reload(wait_until='networkidle')
                page.get_by_role('button', name='Account', exact=True).click()
            expect(student_a.get_by_placeholder('Display name')).to_have_value(renamed)
            expect(student_b.get_by_placeholder('Display name')).to_have_value(users[1]['name'])
            # Restore through the same UI so the HTTP receipt still verifies after restart.
            save_name(student_a, users[0]['name'])
            session_matches(student_a, users[0])
            print('PASS student profile edit persists after reload without changing the other account; restored original name')

            student_a.get_by_role('button', name='Sign out', exact=True).click()
            expect(student_a.get_by_role('button', name='Open sign in', exact=True)).to_be_visible()
            assert student_a.evaluate('localStorage.getItem("jac_token")') is None, 'Logout retained the local token'
            assert not rpc(student_a, 'current_session')['authenticated'], 'Signed-out page still authenticates'
            for page, user in zip(pages[1:], users[1:]):
                assert page.evaluate('(token) => localStorage.getItem("jac_token") === token', user['token']), 'Logout crossed browser storage'
                page.reload(wait_until='networkidle')
                expect(page.get_by_role('button', name='Sign out', exact=True)).to_be_visible()
                session_matches(page, user)
                refresh_feed(page, expected)
            refresh_feed(student_a, expected)
            assert not errors, errors
            print('PASS logging out one browser preserves every other session and the shared public catalog; no page errors')
        finally:
            for context in contexts:
                context.close()
            browser.close()


if __name__ == '__main__':
    main()
