"""Browser layout smoke checks against the compiled app using synthetic RPC data.

PowerShell: python tests/ui/refresh_visual.py --url http://localhost:8155 --output .jac/refresh-evidence
Requires Python Playwright and its Chromium browser. No email, shared database,
real credentials, or camera is used. The existing DOM/controller tests cover
request races, saved claims, retry behavior, and scanner state transitions.
"""
import argparse
from datetime import date, timedelta
import json
from pathlib import Path
import time
from playwright.sync_api import sync_playwright


def analytics(days):
    keys = ('claims redemptions unique_customers returning_customers value_cents '
            'savings_cents savings_known cohort_redeemed cancelled expired pending unknown_outcomes').split()
    start = date(2026, 9, 27) - timedelta(days=days)
    frames = []
    for day in range(days + 1):
        totals = dict.fromkeys(keys, 0)
        totals.update(claims=day*4, redemptions=day*3, unique_customers=day*2,
                      returning_customers=day, value_cents=day*2400,
                      cohort_redeemed=day*3, expired=day)
        daily = dict.fromkeys(keys, 0)
        if day:
            daily.update(claims=4, redemptions=3)
        frames.append(dict(day=day, date=str(start+timedelta(days=day)), totals=totals,
                           daily=daily, offers=[dict(title='Harvest bowl for $8', redemptions=day*3, value_cents=day*2400)] if day else []))
    return dict(ok=True, business_name='Arbor Leaf Kitchen', is_demo=True, period_days=days,
                timezone='America/Detroit', start_date=frames[1]['date'], end_date=frames[-1]['date'],
                as_of=1790553600, coverage_start_date=frames[1]['date'], warnings=[], frames=frames)


def run(url, output):
    output.mkdir(parents=True, exist_ok=True)
    errors, calls, screenshots = [], [], []
    role, held = 'guest', False
    offer = dict(id='visual-offer', title='Harvest bowl for $8', description='Roasted seasonal vegetables, warm grains and lemon tahini.',
                 restaurant='Arbor Leaf Kitchen', price=8, regular_price=12, address='120 Example Street',
                 neighborhood='Kerrytown', state='active', remaining=5, quantity=8, eligibility='Valid university ID',
                 terms='One bowl per student. Takeout only.', menu_item='Harvest bowl', dietary=['vegan'], reasons=['Available right now'],
                 is_demo=False, time_label='Until 3:00 PM', my_status='', my_claim_id='', my_qr_payload='',
                 my_title='', my_price_cents=0, my_terms='', my_eligibility='', my_expires='', my_expires_ts=0,
                 entrance_note='Use the side entrance.', note_date='2026-09-27', start_input='2026-09-27 11:00', end_input='2026-09-27 15:00')
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(viewport=dict(width=390, height=844), reduced_motion='reduce')
        page.on('pageerror', lambda error: errors.append(str(error)))

        def rpc(route):
            nonlocal held
            name = route.request.url.split('/')[-1]
            body = route.request.post_data_json or {}
            calls.append(dict(name=name, body=body))
            item = dict(offer)
            if held:
                item.update(my_status='claimed', my_claim_id='visual-claim', my_qr_payload='mlocal:v1:'+'A'*43,
                            my_title=offer['title'], my_price_cents=800, my_terms=offer['terms'], my_eligibility=offer['eligibility'],
                            my_expires='3:00 PM', my_expires_ts=time.time()+900)
            session = dict(authenticated=role!='guest', role=role, actor_id='visual-user', restaurant_id='visual-place' if role=='merchant' else '',
                           display_name='Jordan Smith', is_demo=False, email_verified=role!='guest')
            portal = dict(ok=True, name=offer['restaurant'], cuisine='Seasonal bowls', blurb=offer['description'], address=offer['address'],
                          neighborhood='Kerrytown', entrance_note='', note_date='', offers=[item], claims=[], is_demo=True, message='')
            choices = dict(ok=True, message='', signed_in=True, completed=True, categories=[], diets=[], price_range='', favorites=[],
                           all_categories=[dict(key='bowls', label='Bowls'),dict(key='pizza',label='Pizza')],
                           all_diets=[dict(key='vegan',label='Vegan'),dict(key='vegetarian',label='Vegetarian')],
                           all_price_ranges=[dict(key='5to8',label='$5 to $8')])
            results = dict(current_session=session, list_offers=[item], get_offer=item, merchant_portal=portal,
                           home_feed=dict(signed_in=role!='guest', personalized=role=='student', completed=True, price_range='', favorites=[],
                                          items=[dict(offer=item, place='visual-place', place_labels=['Vegan'], categories=['bowls'], price_cents=800,
                                                      regular_cents=1200, price_range='5to8', reasons=['In your price range'], slot='more', is_favorite=False)],
                                          total_deals=1, note=''),
                           taste_choices=choices, save_taste=choices, toggle_favorite=choices,
                           get_account_profile=dict(ok=True, display_name='Jordan Smith', email='jordan@example.test', email_verified=True, role=role),
                           offer_defaults=['2026-09-27 11:00','2026-09-27 15:00'],
                           request_email_code=dict(ok=True, challenge='visual-only', email='jordan@umich.edu', retry_after=60),
                           merchant_insights=analytics(30))
            if name not in results:
                errors.append('Unexpected RPC: '+name)
                route.fulfill(status=500, json=dict(error='Unexpected synthetic RPC'))
                return
            route.fulfill(json=dict(ok=True, type='response', data=dict(result=results[name], reports=[]), error=None))

        page.route('**/function/**', rpc)

        def load(new_role, audience='student', claim=False):
            nonlocal role, held
            role, held = new_role, claim
            page.goto(url)
            page.evaluate('([role,audience])=>{localStorage.clear();if(role!=="guest")localStorage.setItem("jac_token","visual-test-token");if(audience)localStorage.setItem("mlocal_audience",audience)}', [role,audience])
            page.reload()
            page.wait_for_load_state('networkidle')
            page.get_by_text('Opening M-Local...', exact=True).wait_for(state='hidden')
            page.evaluate('document.fonts.ready')

        def capture(name):
            page.wait_for_timeout(80)
            assert page.evaluate('document.documentElement.scrollWidth<=innerWidth'), f'Page overflow: {name}'
            overflow = page.evaluate('''()=>[...document.querySelectorAll('input,select,textarea')].filter(e=>{const r=e.getBoundingClientRect();return r.width>0&&(r.right>innerWidth+1||r.left< -1)}).map(e=>e.outerHTML.slice(0,120))''')
            assert not overflow, f'Control overflow: {name}: {overflow}'
            page.screenshot(path=str(output/f'{name}.png'), full_page=True)
            screenshots.append(name)

        load('guest', audience='')
        capture('welcome-390')
        page.get_by_role('button',name='Find local deals').click()
        page.get_by_placeholder('Your name').wait_for()
        capture('email-390')
        page.get_by_placeholder('Your name').fill('Jordan Smith')
        page.get_by_label('U-M uniqname').fill('jordan')
        page.get_by_role('button',name='Send verification code').click()
        page.get_by_label('Verification code',exact=True).wait_for()
        capture('verify-390')
        assert page.get_by_text('Keep browsing',exact=True).count()==0
        assert page.get_by_test_id('app-tabbar').count()==0
        assert not any(c['name'] in ('home_feed','merchant_portal','merchant_insights') for c in calls)

        load('guest', audience='business')
        page.get_by_role('button',name='List my business').click()
        page.get_by_role('button',name='Sign in',exact=True).click()
        page.get_by_label('Work email').wait_for()
        capture('business-signin-390')
        assert page.get_by_test_id('app-tabbar').count()==0
        page.get_by_role('button',name='Back',exact=True).click()
        page.get_by_role('button',name='Find local deals').wait_for()
        assert page.get_by_text(offer['title'],exact=True).count()==0

        load('student')
        page.get_by_text(offer['title'],exact=True).wait_for()
        capture('discovery-390')
        page.get_by_text(offer['title'],exact=True).scroll_into_view_if_needed()
        capture('deals-390')
        page.get_by_text('Edit my tastes',exact=True).click()
        page.get_by_text('Save my tastes',exact=True).wait_for()
        capture('tastes-390')
        load('student')
        page.get_by_text('Account',exact=True).click()
        page.get_by_label('Display name').wait_for()
        capture('account-390')
        page.get_by_test_id('app-tabbar').get_by_text('Offers',exact=True).click()
        page.get_by_text(offer['title'],exact=True).click()
        page.get_by_text('Claim this offer',exact=True).wait_for()
        capture('offer-390')

        load('student', claim=True)
        page.get_by_text(offer['title'],exact=True).click()
        page.get_by_text('Your saved claim',exact=True).wait_for()
        page.locator('.ml-qr-ticket').evaluate('(element)=>element.scrollIntoView({block:"center"})')
        capture('claim-390')
        assert page.locator('.ml-qr-ticket svg').count()==1

        for width in (320, 390, 1440):
            page.set_viewport_size(dict(width=width,height=900 if width==1440 else 844))
            load('student')
            trigger=page.locator('.ml-filters button[aria-expanded]')
            trigger.focus()
            trigger.press('Space')
            slider=page.get_by_role('slider',name='Maximum price')
            slider.wait_for()
            slider.focus()
            slider.press('Home')
            for _ in range(8):
                slider.press('ArrowRight')
            assert slider.input_value()=='8'
            page.locator('.ml-filters output').get_by_text('$8 or less',exact=True).wait_for()
            page.get_by_label('Right now',exact=True).check()
            page.get_by_label('Vegan',exact=True).check()
            trigger.scroll_into_view_if_needed()
            action_bounds=page.get_by_role('button',name='Show deals',exact=True).bounding_box()
            nav_bounds=page.get_by_test_id('app-tabbar').bounding_box()
            assert action_bounds['y']+action_bounds['height'] <= nav_bounds['y'], 'Filter actions must stay above navigation'
            capture(f'filters-{width}')
            page.get_by_role('button',name='Show deals',exact=True).click()
            page.wait_for_function("document.querySelector('.ml-filters button').getAttribute('aria-expanded')==='false'")
            page.wait_for_load_state('networkidle')
            assert [c for c in calls if c['name']=='home_feed'][-1]['body']==dict(price_range='0-8',window='now',diets='vegan')
            trigger.click()
            page.get_by_role('button',name='Clear all',exact=True).click()
            page.wait_for_load_state('networkidle')
            assert [c for c in calls if c['name']=='home_feed'][-1]['body']==dict(price_range='',window='any',diets='')
            page.get_by_role('button',name='Log out',exact=True).click()
            page.get_by_role('button',name='Find local deals').wait_for()
            page.get_by_role('button',name='List my business').wait_for()
            assert page.get_by_test_id('app-tabbar').count()==0
            assert page.get_by_text(offer['title'],exact=True).count()==0
            assert page.evaluate('localStorage.getItem("jac_token")') is None
            role='guest'  # The fixture now models the signed-out server response.
            page.reload()
            page.get_by_role('button',name='List my business').wait_for()
            capture(f'signed-out-{width}')
            load('merchant', audience='business')
            page.get_by_text('Manage',exact=True).click()
            page.get_by_text('Restaurant profile',exact=True).wait_for()
            capture(f'merchant-{width}')
            page.get_by_text('New offer',exact=True).click()
            page.get_by_placeholder('Lunch bowl for $7').wait_for()
            capture(f'editor-{width}')
            page.get_by_role('button',name='Cancel',exact=True).click()
            page.get_by_text('Redeem',exact=True).click()
            page.get_by_role('button',name='Start camera scan').wait_for()
            capture(f'scanner-{width}')
            page.get_by_text('Insights',exact=True).click()
            page.locator('.bi-metrics').wait_for()
            capture(f'insights-{width}')
        assert not errors, errors
        assert all(not c['name'].startswith(('save_','redeem_','claim_','set_')) for c in calls)
        report = dict(synthetic=True, screenshots=screenshots, rpc_calls=len(calls), page_errors=errors,
                      viewports=[320,390,1440], notes='No real email, database, camera, or business activity.')
        (output/'report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
        print(json.dumps(report,indent=2))
        browser.close()


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url',default='http://localhost:8155')
    parser.add_argument('--output',type=Path,default=Path('.jac/refresh-evidence'))
    args=parser.parse_args()
    run(args.url,args.output)
