"""Apply a genuine Apple provider token to the four measured acquisition pages."""
from html import escape
import json
from pathlib import Path
import re
from urllib.parse import urlencode
from check_site import PUBLIC, page_url, BASE

APP = 'https://apps.apple.com/us/app/iso-me/id6761960794'
CONFIG = PUBLIC.parent / 'content/acquisition.json'


def app_url(path):
    config = json.loads(CONFIG.read_text())
    token = config.get('providerToken')
    campaign = config['campaigns'].get(path)
    if token is None or campaign is None:
        return APP
    if not isinstance(token, str) or not re.fullmatch(r'[0-9]+', token):
        raise ValueError('Use the actual numeric provider token from an Apple-generated campaign link.')
    return APP + '?' + urlencode({'pt': token, 'ct': campaign, 'mt': '8'})


def update_download_links():
    pattern = re.compile(r'(<a\b[^>]*?\bhref=["\'])https://apps\.apple\.com/(?:us/)?app/(?:iso-me/)?id6761960794(?:\?[^"\']*)?(["\'])')
    for page in PUBLIC.rglob('*.html'):
        url = app_url(page_url(page).removeprefix(BASE))
        original = page.read_text()
        updated = pattern.sub(lambda match: match[1] + escape(url, quote=True) + match[2], original)
        if updated != original:
            page.write_text(updated)
    # A mismatched QR must never silently send desktop readers to an old campaign.
    declared = PUBLIC / 'assets/app-store-qr-url.txt'
    if declared.read_text().strip() != app_url('/'):
        raise ValueError('Regenerate the App Store QR and its URL file after changing the provider token.')
