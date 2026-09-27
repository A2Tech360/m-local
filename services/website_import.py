"""Bounded public HTTPS reader. No scripts, cookies, credentials or model tools.

DNS answers are validated and the chosen public address is pinned to the socket;
TLS still verifies the original hostname. This prevents a second DNS lookup from
turning a public URL into a request to localhost or cloud metadata.
"""
from html.parser import HTMLParser
import http.client
import ipaddress
import json
import re
import socket
import ssl
import time
from urllib.parse import urljoin, urlsplit, urlunsplit
from urllib.robotparser import RobotFileParser

MAX_BYTES = 524288
AGENT = 'MLocalPreview/1.0'


def clean_url(value: str) -> str:
    if not isinstance(value, str) or len(value) > 2048 or re.search(r'[\s\\\x00-\x1f]', value):
        raise ValueError('Use a public https:// website address.')
    try:
        parsed = urlsplit(value)
        host = (parsed.hostname or '').lower().encode('idna').decode('ascii')
        if (parsed.scheme != 'https' or not host or parsed.username or parsed.password
                or parsed.port not in (None, 443) or '.' not in host
                or host.endswith(('.localhost', '.local', '.internal'))):
            raise ValueError()
        try:
            ip = ipaddress.ip_address(host)
        except ValueError:
            ip = None
        if ip is not None and not ip.is_global:
            raise ValueError()
        return urlunsplit(('https', host, parsed.path or '/', parsed.query, ''))
    except (ValueError, UnicodeError):
        raise ValueError('Use a public https:// website address.') from None


def public_target(value: str) -> tuple[str, str, str]:
    url = clean_url(value)
    host = urlsplit(url).hostname
    answers = socket.getaddrinfo(host, 443, type=socket.SOCK_STREAM)
    addresses = {answer[4][0] for answer in answers}
    if not addresses or any(not ipaddress.ip_address(ip).is_global for ip in addresses):
        raise ValueError('That website resolves to a private or reserved address.')
    return url, host, sorted(addresses)[0]


class PublicHTTPS(http.client.HTTPSConnection):
    def __init__(self, host: str, address: str):
        super().__init__(host, timeout=6, context=ssl.create_default_context())
        self.address = address

    def connect(self):
        raw = socket.create_connection((self.address, 443), timeout=self.timeout)
        try:
            self.sock = self._context.wrap_socket(raw, server_hostname=self.host)
        except Exception:
            raw.close()
            raise


def fetch_public(url: str, allowed=None) -> tuple[str, str, bytes]:
    deadline = time.monotonic() + 15
    for _ in range(4):
        if allowed is not None and not allowed(url):
            raise ValueError('This website does not allow automated import of that page.')
        url, host, address = public_target(url)
        parsed = urlsplit(url)
        connection = PublicHTTPS(host, address)
        try:
            connection.request('GET', parsed.path + ('?' + parsed.query if parsed.query else ''),
                               headers={'User-Agent': AGENT, 'Accept': 'text/html,text/plain', 'Accept-Encoding': 'identity'})
            response = connection.getresponse()
            if response.status in (301, 302, 303, 307, 308):
                destination = clean_url(urljoin(url, response.getheader('Location', '')))
                # Cross-site redirects require a fresh user-supplied URL and robots check.
                if urlsplit(destination).hostname != host:
                    raise ValueError('This website redirects to another host. Paste its final https:// address.')
                url = destination
                continue
            if response.status == 404 and parsed.path == '/robots.txt':
                return url, 'text/plain', b''
            if response.status != 200:
                raise ValueError('The website did not allow the import. You can enter its details manually.')
            if response.getheader('Content-Encoding', 'identity') != 'identity':
                raise ValueError('This website returned an unsupported compressed page.')
            length = response.getheader('Content-Length')
            if length and int(length) > MAX_BYTES:
                raise ValueError('This page is too large to import.')
            data = bytearray()
            while len(data) <= MAX_BYTES:
                if time.monotonic() > deadline:
                    raise ValueError('This website took too long to respond.')
                chunk = response.read1(min(16384, MAX_BYTES + 1 - len(data)))
                if not chunk:
                    break
                data.extend(chunk)
            if len(data) > MAX_BYTES:
                raise ValueError('This page is too large to import.')
            return url, response.getheader('Content-Type', '').split(';')[0].lower(), bytes(data)
        finally:
            connection.close()
    raise ValueError('This website redirected too many times.')


class Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.text = []
        self.title = []
        self.images = []
        self.links = []
        self.meta = {}
        self.ld = []
        self.script = None
        self.hidden = 0
        self.in_title = False
        self.link = None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag in ('script', 'style', 'noscript'):
            self.hidden += 1
            if tag == 'script' and attrs.get('type', '').lower() == 'application/ld+json':
                self.script = []
        elif tag == 'title':
            self.in_title = True
        elif tag == 'meta':
            self.meta[attrs.get('property', attrs.get('name', '')).lower()] = attrs.get('content', '')
        elif tag == 'img':
            self.images.append(attrs.get('src', ''))
        elif tag == 'a':
            self.link = [attrs.get('href', ''), '']

    def handle_data(self, data):
        if self.script is not None:
            self.script.append(data)
        if self.hidden:
            return
        if self.in_title:
            self.title.append(data)
        if self.link is not None:
            self.link[1] += data
        self.text.append(data.strip())

    def handle_endtag(self, tag):
        if tag in ('script', 'style', 'noscript'):
            if tag == 'script' and self.script is not None:
                try:
                    self.ld.append(json.loads(''.join(self.script)))
                except (ValueError, RecursionError):
                    pass
                self.script = None
            self.hidden = max(0, self.hidden - 1)
        if tag == 'title':
            self.in_title = False
        if tag == 'a' and self.link is not None:
            self.links.append(self.link)
            self.link = None


def candidates(values, base):
    result = []
    for value in values:
        if isinstance(value, dict):
            value = value.get('url', value.get('contentUrl', ''))
        if not isinstance(value, str) or not value:
            continue
        try:
            url = clean_url(urljoin(base, value))
            if url not in result:
                result.append(url)
        except ValueError:
            pass
    return result[:12]


def parse_page(html: str, url: str) -> dict:
    page = Page()
    page.feed(html[:MAX_BYTES])
    result = {'name': page.meta.get('og:site_name', ''.join(page.title))[:160],
              'description': page.meta.get('description', page.meta.get('og:description', ''))[:1000],
              'cuisine': '', 'address': '', 'menu_text': '', 'text': ' '.join(page.text)[:20000]}
    images = [page.meta.get('og:image', '')] + page.images
    menus = [href for href, label in page.links if 'menu' in (href + ' ' + label).lower()]
    queue = page.ld[:]
    for _ in range(100):
        if not queue:
            break
        item = queue.pop(0)
        if isinstance(item, list):
            queue.extend(item[:30])
            continue
        if not isinstance(item, dict):
            continue
        if '@graph' in item:
            queue.append(item['@graph'])
        kinds = item.get('@type', [])
        kinds = [kinds] if isinstance(kinds, str) else kinds
        if not isinstance(kinds, list) or not set(kinds).intersection({'Restaurant', 'CafeOrCoffeeShop', 'FoodEstablishment', 'LocalBusiness', 'Bakery', 'BarOrPub'}):
            continue
        for target, source in (('name', 'name'), ('description', 'description'), ('cuisine', 'servesCuisine')):
            value = item.get(source, '')
            if isinstance(value, list):
                value = ', '.join(v for v in value if isinstance(v, str))
            if isinstance(value, str) and value:
                result[target] = value[:1000]
        address = item.get('address', '')
        if isinstance(address, dict):
            address = ', '.join(str(address.get(k, '')) for k in ('streetAddress', 'addressLocality', 'addressRegion', 'postalCode') if address.get(k))
        if isinstance(address, str):
            result['address'] = address[:500]
        for field, out in (('image', images), ('hasMenu', menus), ('menu', menus)):
            value = item.get(field, [])
            out.extend(value if isinstance(value, list) else [value])
        break
    result['image_urls'] = candidates(images, url)
    result['menu_urls'] = candidates(menus, url)
    return result


def collect_website(url: str, fetch=fetch_public) -> dict:
    url = clean_url(url.strip())
    host = urlsplit(url).hostname
    robots_url = f'https://{host}/robots.txt'
    _, _, robot_data = fetch(robots_url)
    robots = RobotFileParser()
    robots.parse(robot_data.decode('utf-8', errors='replace').splitlines())
    if not robots.can_fetch(AGENT, url):
        raise ValueError('This website does not allow automated import. Enter its details manually.')
    reader = (lambda target: fetch_public(target, lambda dest: robots.can_fetch(AGENT, dest))) if fetch is fetch_public else fetch
    final, content_type, data = reader(url)
    if content_type not in ('text/html', 'application/xhtml+xml'):
        raise ValueError('Paste the business homepage; PDF menus can be linked during review.')
    if not robots.can_fetch(AGENT, final):
        raise ValueError('This website does not allow automated import.')
    result = parse_page(data.decode('utf-8', errors='replace'), final)
    result['website'] = final
    result['sources'] = [final]
    # A single menu HTML page keeps latency, cost and website load bounded.
    for menu in result['menu_urls']:
        if urlsplit(menu).hostname != host or urlsplit(menu).path.lower().endswith('.pdf') or not robots.can_fetch(AGENT, menu):
            continue
        try:
            menu_final, kind, body = reader(menu)
            if kind == 'text/html' and robots.can_fetch(AGENT, menu_final):
                parsed = parse_page(body.decode('utf-8', errors='replace'), menu_final)
                result['text'] = (result['text'] + '\nMENU PAGE:\n' + parsed['text'])[:24000]
                result['menu_text'] = parsed['text'][:4000]
                result['image_urls'] = candidates(result['image_urls'] + parsed['image_urls'], final)
                result['sources'].append(menu_final)
        except (ValueError, OSError, http.client.HTTPException):
            pass
        break
    return result
