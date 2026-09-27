"""Opt-in Chromium smoke test against the disposable account-post HTTP workspace.

Requires Python Playwright with Chromium installed, and the running isolated
onboarding-check app at port 8240 after account_posts_http.py. Uses real RPCs.
No mail is sent; the pending-company session comes from the HTTP test receipt.
"""
import argparse
import json
from pathlib import Path
import secrets

from playwright.sync_api import sync_playwright, expect


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--workspace', required=True, type=Path)
    parser.add_argument('--screenshots', required=True, type=Path)
    args = parser.parse_args()
    if args.workspace.name != 'onboarding-check':
        raise SystemExit('Only the disposable onboarding-check workspace is supported.')
    accounts = json.loads((args.workspace / '.jac/qr-demo-accounts.json').read_text())
    receipt = json.loads((args.workspace / '.jac/account-post-check.json').read_text())
    args.screenshots.mkdir(parents=True, exist_ok=True)
    run = secrets.token_hex(4)
    origin = 'http://127.0.0.1:8240'
    with sync_playwright() as runtime:
        browser = runtime.chromium.launch(headless=True)
        context = browser.new_context(viewport={'width': 390, 'height': 844})
        page = context.new_page()
        errors = []
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.goto(origin, wait_until='networkidle')
        expect(page.get_by_role('heading', name='Welcome to M-Local')).to_be_visible()
        page.get_by_role('button', name='List my business', exact=False).click()
        expect(page.get_by_placeholder('Your name')).to_be_visible()
        page.get_by_role('button', name='I already have an account', exact=True).click()
        expect(page.get_by_placeholder('Your name')).to_have_count(0)
        page.screenshot(path=str(args.screenshots / 'business-signin-390.png'))
        page.get_by_role('button', name='Existing restaurant sign-in', exact=True).click()
        page.get_by_placeholder('Email', exact=True).fill(accounts['merchant_leaf']['email'])
        page.get_by_placeholder('Password', exact=True).fill(accounts['merchant_leaf']['password'])
        page.get_by_role('button', name='Sign in', exact=True).click()
        expect(page.get_by_text('Manage', exact=True)).to_be_visible()
        page.get_by_text('Manage', exact=True).click()
        expect(page.get_by_text('New offer', exact=True)).to_be_visible()
        page.get_by_text('New offer', exact=True).click()
        title = 'Browser lunch ' + run
        page.get_by_placeholder('Lunch bowl for $7').fill(title)
        page.get_by_placeholder('7.00', exact=True).fill('6.50')
        page.get_by_placeholder('One per student. Dine-in only.').fill('One per student. Fictional browser test.')
        page.get_by_text('Offers', exact=True).click()
        page.get_by_text('Manage', exact=True).click()
        expect(page.get_by_placeholder('Lunch bowl for $7')).to_have_value(title)
        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth'), 'Composer overflows phone width'
        page.get_by_placeholder('Lunch bowl for $7').scroll_into_view_if_needed()
        page.screenshot(path=str(args.screenshots / 'offer-composer-390.png'))
        page.get_by_role('button', name='Publish offer', exact=True).click()
        expect(page.get_by_placeholder('Lunch bowl for $7')).to_have_count(0)
        expect(page.get_by_text(title, exact=True)).to_have_count(1)
        page.get_by_text('Offers', exact=True).click()
        expect(page.get_by_text(title, exact=True)).to_have_count(1)
        page.reload(wait_until='networkidle')
        expect(page.get_by_text(title, exact=True)).to_have_count(1)
        page.get_by_text('Account', exact=True).click()
        name = 'Browser owner ' + run
        page.get_by_placeholder('Display name').fill(name)
        page.get_by_role('button', name='Save account', exact=True).click()
        expect(page.get_by_text('Profile saved.', exact=True)).to_be_visible()
        page.reload(wait_until='networkidle')
        expect(page.get_by_text(name, exact=True)).to_be_visible()
        print('PASS real merchant sign-in, retained offer draft, publication, reload and account-name persistence at 390px')
        context.close()

        context = browser.new_context(viewport={'width': 390, 'height': 844})
        context.add_init_script('localStorage.setItem("jac_token", ' + json.dumps(receipt['business_token']) +
                                '); localStorage.setItem("mlocal_audience", "business");')
        page = context.new_page()
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.goto(origin, wait_until='networkidle')
        page.get_by_text('Business profile', exact=True).click()
        expect(page.get_by_placeholder('Business name')).to_have_value(receipt['business_name'])
        description = 'Edited in Chromium ' + run
        page.get_by_placeholder('About your business').fill(description)
        page.get_by_role('checkbox').check()
        page.get_by_role('button', name='Save business for review', exact=True).click()
        expect(page.get_by_text('Pending review.', exact=True)).to_be_visible()
        page.get_by_text('Close business profile', exact=True).click()
        page.get_by_text('Business profile', exact=True).click()
        expect(page.get_by_placeholder('About your business')).to_have_value(description)
        expect(page.get_by_text('Manage', exact=True)).to_have_count(0)
        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth'), 'Business profile overflows phone width'
        page.get_by_placeholder('Business name').scroll_into_view_if_needed()
        page.screenshot(path=str(args.screenshots / 'business-profile-390.png'))
        print('PASS real company profile edit/reopen with pending approval and no merchant controls at 390px')
        context.close()
        browser.close()
        assert not errors, errors


if __name__ == '__main__':
    main()
