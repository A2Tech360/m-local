"""Synthetic RPC visual checks. No real email, claims, or business writes."""
import argparse
import json
from pathlib import Path
import time
from playwright.sync_api import sync_playwright
from refresh_visual import analytics


def run(url, output):
    output.mkdir(parents=True, exist_ok=True)
    errors, shots, requests = [], [], []
    role = 'guest'
    item = dict(id='visual-offer', title='Harvest bowl for $8', description='Roasted seasonal vegetables, warm grains and lemon tahini.',
                restaurant='Arbor Leaf Kitchen', cuisine='Seasonal bowls', price=8, regular_price=12,
                address='120 Example Street, Ann Arbor', neighborhood='Kerrytown', state='active', remaining=5, quantity=8,
                eligibility='Valid university ID', terms='One bowl per student. Takeout only.', menu_item='Harvest bowl',
                dietary=['vegan'], reasons=[], is_demo=False, time_label='Until 3:00 PM', my_status='claimed',
                my_claim_id='visual-claim', my_qr_payload='mlocal:v1:'+'A'*43, my_title='Harvest bowl for $8',
                my_price_cents=800, my_terms='One bowl per student. Takeout only.', my_eligibility='Valid university ID',
                my_expires='3:00 PM', my_expires_ts=time.time()+1200, entrance_note='Use the side entrance.',
                note_date='2026-09-27', start_input='2026-09-27 11:00', end_input='2026-09-27 15:00')
    business = dict(ok=True, message='', slug='arbor-leaf', name=item['restaurant'], cuisine='Seasonal bowls',
                    blurb='A small neighborhood kitchen making bright, seasonal lunches. Stop by for a warm bowl and a little time away from campus.',
                    address=item['address'], neighborhood='Kerrytown', entrance_note=item['entrance_note'],
                    note_date=item['note_date'], is_demo=False, offers=[item])
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        page = browser.new_page(viewport=dict(width=390, height=844), reduced_motion='reduce')
        page.on('pageerror', lambda error: errors.append(str(error)))

        def rpc(route):
            name = route.request.url.rsplit('/', 1)[-1]
            requests.append(name)
            session = dict(authenticated=role!='guest', actor_id='visual-user', role=role,
                           restaurant_id='visual-node-id', display_name='Jordan Smith', is_demo=False, email_verified=role!='guest')
            tastes = dict(ok=True, message='', completed=True, signed_in=True, categories=[], diets=[], favorites=[], price_range='',
                          all_categories=[], all_diets=[], all_price_ranges=[])
            values = dict(current_session=session, get_business_profile=business, get_offer=item,
                          home_feed=dict(signed_in=True,personalized=True,completed=True,price_range='',favorites=[],show_samples=False,
                                         items=[dict(offer=item,place='arbor-leaf',place_labels=['Vegan'],categories=[],price_cents=800,
                                                     regular_cents=1200,price_range='',reasons=[],slot='more',is_favorite=False)],total_deals=1,note=''),
                          merchant_portal=dict(**{key:value for key,value in business.items() if key!='slug'},claims=[]),
                          get_account_profile=dict(ok=True,message='',display_name='Jordan Smith',email='jordan@example.test',role=role,email_verified=True,is_demo=False),
                          taste_choices=tastes,save_taste=tastes,toggle_favorite=tastes,
                          merchant_insights=analytics(30),offer_defaults=['2026-09-27 11:00','2026-09-27 15:00'])
            if name not in values:
                errors.append('Unexpected RPC: '+name)
                route.fulfill(status=500,json=dict(error='Unexpected fixture request'))
            else:
                route.fulfill(json=dict(ok=True,type='response',data=dict(result=values[name],reports=[]),error=None))

        page.route('**/function/**', rpc)

        def load(next_role, theme):
            nonlocal role
            role = next_role
            page.goto(url)
            page.evaluate('([role,theme])=>{localStorage.clear();localStorage.setItem("mlocal_theme",theme);if(role!=="guest")localStorage.setItem("jac_token","synthetic-token")}', [role,theme])
            page.reload()
            page.wait_for_load_state('networkidle')
            page.evaluate('document.fonts.ready')
            assert page.locator('html').get_attribute('data-theme') == theme

        def capture(name):
            assert page.evaluate('document.documentElement.scrollWidth<=innerWidth'), 'Page overflow: '+name
            assert not page.evaluate('''()=>[...document.querySelectorAll('input,select,textarea,button')].filter(el=>{const r=el.getBoundingClientRect();return r.width>0&&(r.left< -1||r.right>innerWidth+1)}).map(el=>el.textContent)'''), 'Control overflow: '+name
            logo = page.locator('img[alt="M Local"]').first
            assert logo.evaluate('(el)=>el.complete&&el.naturalWidth>0'), 'Logo failed: '+name
            page.screenshot(path=str(output/f'{name}.png'), full_page=True)
            shots.append(name)

        for width in (320,390,1440):
            page.set_viewport_size(dict(width=width,height=844 if width<700 else 1000))
            for theme in ('light','dark'):
                prefix=f'{width}-{theme}'
                load('guest',theme)
                capture(prefix+'-welcome')
                page.get_by_role('button',name='Find local deals').click()
                page.get_by_placeholder('Your name').wait_for()
                capture(prefix+'-signin')
                load('student',theme)
                page.get_by_text(item['title'],exact=True).wait_for()
                toolbar=page.locator('.ml-feed-toolbar')
                filter_button=toolbar.locator('button[aria-expanded]')
                refresh=toolbar.get_by_role('button',name='Refresh offers',exact=True)
                first,second=filter_button.bounding_box(),refresh.bounding_box()
                assert abs(first['y']-second['y'])<2 and first['x']+first['width']<=second['x'], 'Toolbar wraps'
                masthead=page.get_by_test_id('app-masthead')
                assert masthead.get_by_role('button',name='Log out',exact=True).count()==1
                capture(prefix+'-feed')
                filter_button.click()
                page.get_by_label('Maximum price',exact=True).focus()
                page.keyboard.press('Home')
                for _ in range(8): page.keyboard.press('ArrowRight')
                page.get_by_label('Vegan',exact=True).check()
                capture(prefix+'-filters')
                page.get_by_role('button',name='Show deals',exact=True).click()
                capture(prefix+'-filtered-feed')
                page.get_by_role('button',name='View Arbor Leaf Kitchen business profile',exact=True).click()
                page.get_by_role('heading',name='Arbor Leaf Kitchen',exact=True).wait_for()
                capture(prefix+'-business')
                page.get_by_role('button',name='Harvest bowl for $8',exact=False).click()
                page.get_by_test_id('claim-qr').wait_for()
                assert page.get_by_test_id('claim-qr').evaluate('(el)=>getComputedStyle(el).backgroundColor')=='rgb(255, 255, 255)'
                capture(prefix+'-claim')
                load('merchant',theme)
                page.get_by_text('Business insights',exact=True).wait_for()
                capture(prefix+'-insights')
                page.get_by_role('button',name='Manage Offers',exact=True).click()
                page.get_by_role('button',name='View business page',exact=True).wait_for()
                capture(prefix+'-manage')
                page.get_by_role('button',name='View business page',exact=True).click()
                page.get_by_role('heading',name='Arbor Leaf Kitchen',exact=True).wait_for()
                capture(prefix+'-owner-preview')
                page.get_by_role('button',name='Account You',exact=True).click()
                page.get_by_label('Appearance').wait_for()
                capture(prefix+'-account')
        assert not errors, errors
        (output/'report.json').write_text(json.dumps(dict(url=url,screenshots=shots,page_errors=errors,rpc_count=len(requests)),indent=2))
        browser.close()
    print(json.dumps(dict(screenshots=len(shots),page_errors=errors,rpc_count=len(requests))))


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--url',default='http://localhost:8155')
    parser.add_argument('--output',type=Path,default=Path('.jac/theme-profile-evidence'))
    args=parser.parse_args()
    run(args.url,args.output)
