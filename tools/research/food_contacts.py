"""Public-page research only; never sends mail or grants business ownership.

PowerShell: python tools/research/food_contacts.py scan
PowerShell: python tools/research/food_contacts.py build
Resumes from JSONL checkpoints; SQLite is a standalone research database.
"""
from __future__ import annotations

import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
import hashlib
import ipaddress
import json
from pathlib import Path
import re
import socket
import sqlite3
import threading
import time
from urllib.parse import unquote, urljoin, urlsplit, urlunsplit
from urllib.robotparser import RobotFileParser

import requests
from bs4 import BeautifulSoup

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'data' / 'research'
FOOD = {'restaurant', 'fast_food', 'cafe', 'bar', 'bakery', 'dessert'}
AGENT = 'MLocalPublicContactResearch/1.0'
EMAIL = re.compile(r'(?<![\w.+-])[A-Z0-9.!#$%&\'*+/=?^_`{|}~-]+@[A-Z0-9-]+(?:\.[A-Z0-9-]+)+', re.I)
LOCK = threading.Lock()
HOST_LOCKS: dict[str, threading.Lock] = {}
ROBOTS: dict[str, tuple[RobotFileParser | None, str]] = {}


def now():
    return datetime.now(timezone.utc).isoformat()


def records():
    return [p for p in json.loads((ROOT / 'data/simulation/places.json').read_text(encoding='utf-8')) if p['category'] in FOOD]


def canonical(url):
    url = url.strip()
    if '://' not in url:
        url = 'https://' + url
    p = urlsplit(url)
    return urlunsplit((p.scheme, p.netloc.lower(), p.path or '/', p.query, ''))


def safe_url(url):
    p = urlsplit(url)
    if p.scheme not in {'https', 'http'} or not p.hostname or p.username or p.password:
        raise ValueError('unsupported URL')
    if p.port not in {None, 80, 443}:
        raise ValueError('unsupported port')
    for addr in socket.getaddrinfo(p.hostname, p.port or 443, type=socket.SOCK_STREAM):
        if not ipaddress.ip_address(addr[4][0]).is_global:
            raise ValueError('non-public destination')


def fetch(url):
    started = time.monotonic()
    for _ in range(6):
        safe_url(url)
        with requests.get(url, timeout=(5, 9), allow_redirects=False, stream=True,
                          headers={'User-Agent': AGENT}) as r:
            if r.is_redirect:
                url = urljoin(url, r.headers['Location'])
                continue
            r.raise_for_status()
            content_type = r.headers.get('Content-Type', '')
            if not any(t in content_type.lower() for t in ('text/', 'html', 'xml')):
                raise ValueError('non-text response: ' + content_type[:70])
            chunks, size = [], 0
            for chunk in r.iter_content(16384):
                size += len(chunk)
                if size > 1_500_000 or time.monotonic() - started > 20:
                    break
                chunks.append(chunk)
            return url, b''.join(chunks).decode(r.encoding or 'utf-8', errors='replace')
    raise ValueError('redirect limit')


def allowed(url):
    p = urlsplit(url)
    origin = f'{p.scheme}://{p.netloc}'
    if origin not in ROBOTS:
        try:
            _, txt = fetch(origin + '/robots.txt')
            parser = RobotFileParser()
            parser.parse(txt.splitlines())
            ROBOTS[origin] = (parser, '')
        except requests.HTTPError as exc:
            status = exc.response.status_code
            ROBOTS[origin] = (None, '' if status == 404 else f'robots HTTP {status}')
        except Exception:
            ROBOTS[origin] = (None, 'robots unavailable')
    parser, error = ROBOTS[origin]
    return (False, error) if error else (parser.can_fetch(AGENT, url) if parser else True, 'robots disallow')


def role(email):
    local = email.split('@')[0].lower()
    if re.search(r'privacy|legal|accessib|abuse|security|webmaster|noreply|no-reply|donotreply', local):
        return 'restricted_purpose'
    if re.search(r'career|jobs|hiring|employment|recruit|resume', local):
        return 'hiring'
    if re.search(r'cater|events|parties|reservation|booking', local):
        return 'events_or_reservations'
    if re.search(r'press|media|marketing', local):
        return 'media_or_marketing'
    return 'public_business_contact_candidate'


def extract(html, url):
    soup = BeautifulSoup(html, 'html.parser')
    for tag in soup(['script', 'style', 'noscript', 'svg']):
        tag.decompose()
    evidence = []
    for a in soup.select('a[href]'):
        href = a.get('href', '')
        if href.lower().startswith('mailto:'):
            for email in EMAIL.findall(unquote(href[7:].split('?')[0])):
                evidence.append((email, a.parent.get_text(' ', strip=True)[:300], 'mailto'))
    for tag in soup.select('[data-cfemail]'):
        try:
            b = bytes.fromhex(tag['data-cfemail'])
            email = ''.join(chr(x ^ b[0]) for x in b[1:])
            if EMAIL.fullmatch(email):
                evidence.append((email, 'Public Cloudflare-protected email link', 'public_obfuscated_email'))
        except (ValueError, IndexError):
            pass
    text = soup.get_text(' ', strip=True)
    for match in EMAIL.finditer(text):
        evidence.append((match.group(), text[max(0, match.start()-90):match.end()+90], 'visible_text'))
    contacts = {}
    for email, context, method in evidence:
        email = email.strip('.;,').lower()
        if email.endswith(('.png', '.jpg', '.jpeg', '.webp', '.svg', '.js', '.css')):
            continue
        if email.split('@')[1] in {'example.com', 'example.org', 'domain.com', 'email.com', 'sentry.io', 'wixpress.com'}:
            continue
        contacts.setdefault(email, {'email': email, 'source_url': url, 'evidence': context,
                                   'extraction_method': method, 'contact_role': role(email)})
    links = []
    origin_host = urlsplit(url).hostname
    for a in soup.select('a[href]'):
        target = urljoin(url, a['href'])
        p = urlsplit(target)
        if p.scheme not in {'http', 'https'} or p.hostname != origin_host:
            continue
        label = a.get_text(' ', strip=True).lower() + ' ' + p.path.lower()
        if re.search(r'privacy|terms|cart|checkout|login|career|jobs', label):
            continue
        score = 3 if 'contact' in label else 2 if 'about' in label else 1 if re.search(r'location|visit', label) else 0
        if score:
            links.append((score, canonical(target)))
    links = list(dict.fromkeys(link for _, link in sorted(links, key=lambda pair: -pair[0])))
    return list(contacts.values()), links


def scan_site(url):
    host = urlsplit(url).hostname
    with LOCK:
        lock = HOST_LOCKS.setdefault(host, threading.Lock())
    with lock:
        result = {'website': url, 'checked_at': now(), 'pages': [], 'contacts': [], 'errors': []}
        queue, visited = [url], set()
        for _ in range(4):
            if not queue:
                break
            current = queue.pop(0)
            if current in visited:
                continue
            visited.add(current)
            try:
                permit, reason = allowed(current)
                if not permit:
                    result['errors'].append({'url': current, 'reason': reason})
                    continue
                final, html = fetch(current)
                contacts, links = extract(html, final)
                redirected_host = urlsplit(final).hostname
                original_base = (host or '').removeprefix('www.')
                final_base = (redirected_host or '').removeprefix('www.')
                result['pages'].append({'requested_url': current, 'source_url': final,
                    'sha256': hashlib.sha256(html.encode()).hexdigest(), 'checked_at': now(),
                    'cross_domain_redirect': original_base != final_base})
                result['contacts'].extend(contacts)
                queue.extend(x for x in links if x not in visited and x not in queue)
                time.sleep(0.4)
            except Exception as exc:
                result['errors'].append({'url': current, 'reason': str(exc)[:220]})
        return result


def scan():
    OUT.mkdir(parents=True, exist_ok=True)
    checkpoint = OUT / 'food-website-checks.jsonl'
    done = set()
    if checkpoint.exists():
        done = {json.loads(line)['website'] for line in checkpoint.read_text(encoding='utf-8').splitlines() if line}
    urls = sorted({canonical(p['website']) for p in records() if p.get('website')})
    pending = [url for url in urls if url not in done]
    print(f'{len(urls)} distinct URLs; {len(done)} checkpointed; {len(pending)} pending', flush=True)
    with checkpoint.open('a', encoding='utf-8') as out, ThreadPoolExecutor(max_workers=12) as pool:
        futures = {pool.submit(scan_site, url): url for url in pending}
        for i, future in enumerate(as_completed(futures), 1):
            result = future.result()
            out.write(json.dumps(result, ensure_ascii=False) + '\n')
            out.flush()
            if i % 20 == 0 or i == len(pending):
                print(f'Checked {i}/{len(pending)} remaining websites', flush=True)


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    places = records()
    checks_file = OUT / 'food-website-checks.jsonl'
    checks = {r['website']: r for r in (json.loads(line) for line in checks_file.read_text(encoding='utf-8').splitlines())} if checks_file.exists() else {}
    manual = []
    for path in sorted(OUT.glob('manual-food-*.json')):
        rows = json.loads(path.read_text(encoding='utf-8-sig'))
        manual.extend(rows if isinstance(rows, list) else rows.get('records', rows.get('contacts', [])))
    initial = json.loads((OUT / 'business-email-candidates.json').read_text(encoding='utf-8'))
    manual.extend(initial['contacts'])
    # Rebuild a derived research snapshot; never attach to the application store.
    db = sqlite3.connect(':memory:')
    db.executescript('''
    CREATE TABLE IF NOT EXISTS businesses (
      place_id TEXT PRIMARY KEY, name TEXT NOT NULL, category TEXT NOT NULL,
      address_json TEXT NOT NULL, catalog_website TEXT, catalog_source_url TEXT,
      research_status TEXT NOT NULL, checked_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS contact_candidates (
      place_id TEXT NOT NULL REFERENCES businesses(place_id), email TEXT NOT NULL,
      source_url TEXT NOT NULL, source_type TEXT NOT NULL, contact_role TEXT NOT NULL,
      evidence TEXT, checked_at TEXT NOT NULL, review_status TEXT NOT NULL,
      ownership_verified INTEGER NOT NULL DEFAULT 0 CHECK(ownership_verified=0),
      claim_enabled INTEGER NOT NULL DEFAULT 0 CHECK(claim_enabled=0),
      PRIMARY KEY(place_id,email,source_url));
    CREATE TABLE IF NOT EXISTS research_notes (
      place_id TEXT NOT NULL, source_url TEXT, note TEXT NOT NULL, checked_at TEXT NOT NULL,
      UNIQUE(place_id,source_url,note));
    CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS business_research_flags (
      place_id TEXT NOT NULL REFERENCES businesses(place_id), flag TEXT NOT NULL,
      source_url TEXT NOT NULL, reason TEXT NOT NULL,
      UNIQUE(place_id,flag,source_url,reason));
    ''')
    db.execute('PRAGMA foreign_keys=ON')
    ids = {p['id'] for p in places}
    manual_by_id = {}
    for row in manual:
        if row.get('place_id') not in ids:
            raise ValueError('Unknown place ID in manual research: ' + str(row.get('place_id')))
        manual_by_id.setdefault(row['place_id'], []).append(row)
    for p in places:
        site = canonical(p['website']) if p.get('website') else ''
        check = checks.get(site)
        rows = manual_by_id.get(p['id'], [])
        candidates = list(check['contacts']) if check else []
        status = 'website_not_recorded' if not site else 'website_not_checked'
        if check:
            status = 'no_email_found_on_checked_pages' if check['pages'] else 'website_fetch_blocked_or_failed'
            for error in check['errors']:
                db.execute('INSERT OR IGNORE INTO research_notes VALUES(?,?,?,?)', (p['id'],error['url'],error['reason'],check['checked_at']))
        if rows:
            status = 'manual_research_no_email' if not candidates else status
        for row in rows:
            if row.get('email'):
                candidates.append(dict(row, extraction_method='manual_official_source', evidence=row.get('notes','Published business contact; owner authority unverified')))
            if row.get('notes'):
                db.execute('INSERT OR IGNORE INTO research_notes VALUES(?,?,?,?)', (p['id'],row.get('source_url') or '',row['notes'],now()))
        if candidates:
            status = 'contact_candidates_require_review'
        db.execute('INSERT OR REPLACE INTO businesses VALUES(?,?,?,?,?,?,?,?)', (p['id'],p['name'],p['category'],json.dumps(p['address']),p.get('website'),p['source_url'],status,now()))
        for c in candidates:
            email = c['email'].strip().lower()
            if not EMAIL.fullmatch(email):
                raise ValueError('Invalid candidate email: '+email)
            db.execute('INSERT OR IGNORE INTO contact_candidates VALUES(?,?,?,?,?,?,?,?,0,0)',
                (p['id'],email,c['source_url'],c.get('source_type','catalog_website_extraction'),
                 c.get('contact_role',role(email)),c.get('evidence',''),c.get('checked_at',now()),
                 'source_review_required' if c.get('extraction_method') != 'manual_official_source' else 'published_contact_only'))
    db.execute('INSERT OR REPLACE INTO metadata VALUES(?,?)', ('policy','Research candidates only. No inbox-control or owner-authority verification. All claims disabled.'))
    db.execute('INSERT OR REPLACE INTO metadata VALUES(?,?)', ('catalog_license','OpenStreetMap contributors, ODbL-1.0; https://www.openstreetmap.org/copyright'))
    # Retain rejected evidence for auditing, but keep it out of the review queue.
    provider_domains = {'godaddy.com','getbento.com','bentobox.com','popmenu.com','wix.com',
                        'toasttab.com','chownow.com','beyondmenu.com','menufy.com',
                        'clover.com','squareup.com','owner.com','qmenu.us'}
    other_cities = ('toledo','grandrapids','chophousegr','westland','brownstown',
                   'byroncenter','eastbeltline','grandhaven','grandledge','grandville',
                   'holland','kalamazoo','milford','northland','okemos','plainfield')
    for place_id, email in db.execute('SELECT DISTINCT place_id,email FROM contact_candidates').fetchall():
        local, domain = email.split('@')
        if domain in provider_domains:
            db.execute('UPDATE contact_candidates SET review_status=? WHERE place_id=? AND email=?',
                       ('excluded_vendor_or_placeholder',place_id,email))
        elif any(city in local for city in other_cities):
            db.execute('UPDATE contact_candidates SET review_status=? WHERE place_id=? AND email=?',
                       ('excluded_other_location',place_id,email))
    db.execute("UPDATE contact_candidates SET review_status='third_party_confirmation_required' WHERE source_type='third_party'")
    db.execute("UPDATE contact_candidates SET review_status='corporate_shared_inbox' WHERE contact_role LIKE 'corporate%' AND review_status NOT LIKE 'excluded_%'")
    decisions_file = OUT / 'contact-review-decisions.json'
    if decisions_file.exists():
        decisions = json.loads(decisions_file.read_text(encoding='utf-8-sig'))
        if isinstance(decisions, dict):
            decisions = decisions.get('decisions', decisions.get('records', []))
        for decision in decisions:
            matches = [decision['place_id']] if decision.get('place_id') else [p['id'] for p in places if p.get('website') and urlsplit(canonical(p['website'])).hostname.removeprefix('www.') == urlsplit(canonical(decision['website'])).hostname.removeprefix('www.')]
            for place_id in matches:
                if decision.get('email'):
                    db.execute('UPDATE contact_candidates SET review_status=? WHERE place_id=? AND email=?',
                               (decision['review_status'],place_id,decision['email'].lower()))
                else:
                    db.execute("UPDATE contact_candidates SET review_status=? WHERE place_id=? AND review_status NOT LIKE 'excluded_%'",
                               (decision['review_status'],place_id))
                db.execute('INSERT OR IGNORE INTO research_notes VALUES(?,?,?,?)',
                           (place_id,decision.get('source_url') or '',decision['reason'],now()))
                db.execute('INSERT OR IGNORE INTO business_research_flags VALUES(?,?,?,?)',
                           (place_id,decision['review_status'],decision.get('source_url') or '',decision['reason']))
    db.executescript('''
    CREATE VIEW IF NOT EXISTS contact_review_queue AS
    SELECT b.name,b.category,c.*,
      (SELECT count(DISTINCT other.place_id) FROM contact_candidates other WHERE other.email=c.email) AS businesses_sharing_email
    FROM contact_candidates c JOIN businesses b USING(place_id)
    WHERE c.review_status NOT LIKE 'excluded_%'
      AND c.contact_role NOT IN ('restricted_purpose','hiring','media_or_marketing');
    CREATE VIEW IF NOT EXISTS unresolved_businesses AS
    SELECT b.* FROM businesses b WHERE NOT EXISTS
      (SELECT 1 FROM contact_review_queue q WHERE q.place_id=b.place_id);
    ''')
    db.commit()
    summary = {
      'generated_at': now(), 'business_records': db.execute('SELECT count(*) FROM businesses').fetchone()[0],
      'businesses_with_email_candidates': db.execute('SELECT count(DISTINCT place_id) FROM contact_candidates').fetchone()[0],
      'unique_email_addresses': db.execute('SELECT count(DISTINCT email) FROM contact_candidates').fetchone()[0],
      'source_linked_contact_rows': db.execute('SELECT count(*) FROM contact_candidates').fetchone()[0],
      'businesses_with_reviewable_candidates': db.execute('SELECT count(DISTINCT place_id) FROM contact_review_queue').fetchone()[0],
      'businesses_without_reviewable_candidates': db.execute('SELECT count(*) FROM unresolved_businesses').fetchone()[0],
      'unique_reviewable_email_addresses': db.execute('SELECT count(DISTINCT email) FROM contact_review_queue').fetchone()[0],
      'excluded_contact_rows': db.execute("SELECT count(*) FROM contact_candidates WHERE review_status LIKE 'excluded_%'").fetchone()[0],
      'manually_source_checked_businesses': db.execute("SELECT count(DISTINCT place_id) FROM contact_candidates WHERE review_status='published_contact_only'").fetchone()[0],
      'contact_review_status_counts': dict(db.execute('SELECT review_status,count(*) FROM contact_candidates GROUP BY review_status')),
      'website_urls_checked': len(checks),
      'research_status_counts': dict(db.execute('SELECT research_status,count(*) FROM businesses GROUP BY research_status')),
      'claim_enabled': db.execute('SELECT coalesce(sum(claim_enabled),0) FROM contact_candidates').fetchone()[0],
      'ownership_verified': db.execute('SELECT coalesce(sum(ownership_verified),0) FROM contact_candidates').fetchone()[0],
      'integrity_check': db.execute('PRAGMA integrity_check').fetchone()[0]
    }
    import csv
    with (OUT / 'food-business-contacts.csv').open('w', encoding='utf-8-sig', newline='') as handle:
        query = db.execute('''SELECT b.place_id,b.name,b.category,c.email,c.contact_role,c.source_url,c.source_type,
          c.review_status,b.research_status,c.ownership_verified,c.claim_enabled
          FROM businesses b LEFT JOIN contact_candidates c ON b.place_id=c.place_id ORDER BY b.name,c.email''')
        writer = csv.writer(handle)
        writer.writerow([column[0] for column in query.description])
        writer.writerows(query)
    (OUT / 'food-research-summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
    with (OUT / 'food-contact-review-queue.csv').open('w',encoding='utf-8-sig',newline='') as handle:
        query = db.execute('''SELECT name,category,place_id,email,contact_role,review_status,
          group_concat(DISTINCT source_url) AS source_urls,max(businesses_sharing_email) AS businesses_sharing_email
          FROM contact_review_queue GROUP BY place_id,email ORDER BY name,email''')
        writer = csv.writer(handle)
        writer.writerow([column[0] for column in query.description])
        writer.writerows(query)
    print(json.dumps(summary,indent=2))
    with sqlite3.connect(OUT / 'food-business-contacts.sqlite3') as disk:
        db.backup(disk)
    db.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['scan','build'])
    args = parser.parse_args()
    scan() if args.action == 'scan' else build()
