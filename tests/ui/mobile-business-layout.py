"""Real Chromium geometry checks against the compiled UI with synthetic RPCs.

Run with Windows Python + Playwright after scripts/build.sh. No live data used.
"""
from datetime import date, timedelta
from pathlib import Path
import json
import os
from playwright.sync_api import sync_playwright, expect

ROOT = Path(__file__).resolve().parents[2]
DIST = Path(os.environ.get('MLOCAL_UI_APP_ROOT', ROOT)) / '.jac/client/dist'
KEYS = 'claims redemptions unique_customers returning_customers value_cents savings_cents savings_known cohort_redeemed cancelled expired pending unknown_outcomes'.split()

def insights(days=30):
    frames = [dict(day=i, date=str(date(2026, 9, 27)-timedelta(days=days-i)),
                   daily=dict.fromkeys(KEYS, 0), totals=dict.fromkeys(KEYS, 0), offers=[])
              for i in range(days+1)]
    return dict(ok=True, business_name='Fixture Kitchen', period_days=days, is_demo=True,
                start_date=frames[1]['date'], end_date=frames[-1]['date'], as_of=1790553600,
                coverage_start_date='', warnings=[], frames=frames)

with sync_playwright() as p:
    browser = p.chromium.launch(channel='chrome', headless=True)
    page = browser.new_page(viewport={'width':390, 'height':740})
    errors=[]
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.add_init_script("localStorage.setItem('jac_token','synthetic');localStorage.setItem('mlocal_audience','business');")
    requests=[]
    def route(r):
        path=r.request.url.split('business.test',1)[1].split('?')[0]
        if path == '/':
            bundle=next(DIST.glob('client.*.js')).name
            return r.fulfill(content_type='text/html',body=f'<html><body><div id="root"></div><script type="module" src="/{bundle}"></script></body></html>')
        asset=DIST/path.lstrip('/')
        if asset.is_file():
            return r.fulfill(path=str(asset),content_type='text/javascript' if path.endswith('.js') else 'text/css')
        name=path.rsplit('/',1)[-1]; requests.append(name)
        if name=='current_session':
            result=dict(authenticated=True,role='merchant',actor_id='fixture-merchant',restaurant_id='fixture',display_name='Fixture',email_verified=True,is_demo=True)
        elif name=='merchant_insights':
            result=insights((r.request.post_data_json or {}).get('days',30))
        elif name=='merchant_portal':
            result=dict(ok=True,name='Fixture Kitchen',cuisine='Seafood',blurb='Discover local seafood restaurants, find locations, browse our menus and more.',address='123 Fixture Ave',neighborhood='Kerrytown',entrance_note='Use the side door while sidewalk work continues',note_date='2026-09-27',offers=[],claims=[],is_demo=True,message='')
        else:
            raise AssertionError(f'Unexpected RPC {name}')
        r.fulfill(content_type='application/json',body=json.dumps(dict(ok=True,type='response',data=dict(result=result,reports=[]),error=None)))
    page.route('http://business.test/**',route)
    page.goto('http://business.test/')
    expect(page.locator('.bi-metrics')).to_be_visible()
    assert 'home_feed' not in requests
    evidence=ROOT/'.jac/business-ui-evidence'; evidence.mkdir(parents=True,exist_ok=True)
    page.screenshot(path=str(evidence/'insights-mobile.png'))
    page.get_by_role('button',name='Manage Offers',exact=True).click()
    expect(page.get_by_role('textbox',name='About',exact=True)).to_be_visible()
    for width in (320,390,430):
        page.set_viewport_size(dict(width=width,height=740))
        boxes=page.locator('input,textarea').evaluate_all('els => els.map(e=>({label:e.getAttribute("aria-label"),top:e.parentElement.getBoundingClientRect().top,bottom:e.getBoundingClientRect().bottom}))')
        for prev,nxt in zip(boxes,boxes[1:]):
            assert prev['bottom']+5<=nxt['top'], (width,prev,nxt)
        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth'), width
        save=page.get_by_role('button',name='Save profile',exact=True)
        save.scroll_into_view_if_needed()
        box=save.bounding_box(); nav=page.get_by_role('button',name='Insights Metrics',exact=True).bounding_box()
        assert box['y']+box['height']<=nav['y'], (width,box,nav)
    page.screenshot(path=str(evidence/'profile-mobile.png'))
    assert not errors,errors
    browser.close()
    print('PASS: Insights landing, no student feed RPC, profile field spacing and reachable Save at 320/390/430px; no browser errors.')
