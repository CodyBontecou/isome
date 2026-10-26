#!/usr/bin/env python3
"""Render articles and comparisons as static, crawlable HTML."""
from html import escape
import json
from pathlib import Path

MARKETING = Path(__file__).resolve().parent.parent
PUBLIC = MARKETING / "public"
BASE = "https://isome.isolated.tech"
APP = "https://apps.apple.com/us/app/iso-me/id6761960794"
REVIEWED = "2026-10-26"
PAGES = [
    {
        "path": "/integrations/",
        "section": "Integrations", "section_path": "/integrations/",
        "title": "Use Your iso.me Location History in Other Tools",
        "headline": "Use your location records in another tool",
        "description": "Choose a checked workflow for iso.me records: Markdown notes in Obsidian or optional Overland webhook batches to a Dawarich receiver.",
        "lede": "Choose where your records go, check the result, and keep the original journal. File handoff and live delivery have different requirements.",
        "source": "integrations.html",
    },
    {
        "path": "/integrations/dawarich/",
        "section": "Integrations", "section_path": "/integrations/", "breadcrumb": "Dawarich",
        "type": "BlogPosting",
        "title": "Send iso.me iPhone Location Points to Dawarich with Overland",
        "headline": "Send iso.me location points to Dawarich",
        "description": "Configure iso.me’s Overland webhook for Dawarich, check authentication and saved points, and understand why Test Connection does not prove storage.",
        "lede": "Pair the Overland payload with Dawarich’s batch endpoint, then verify the points at the destination. Webhooks are optional, off by default, and require iso.me’s export unlock.",
        "image": "/screenshots/dawarich-synthetic-points.png",
        "image_alt": "Dawarich 1.18.0 displaying three invented points sent by iso.me’s native webhook code",
        "source": "dawarich.html",
    },
    {
        "path": "/blog/track-days-in-country-iphone/",
        "section": "Guides", "section_path": "/blog/", "breadcrumb": "Country days",
        "type": "BlogPosting",
        "title": "Track Days Spent in Each Country on iPhone — iso.me",
        "headline": "How to track days spent in each country on iPhone",
        "description": "Count country dates from recorded visits, GPS points, and manual stays in iso.me. Understand travel days, timezones, gaps, and optional CSV export.",
        "lede": "Review country totals and the dates behind them, add missing stays, and keep a personal record without an iso.me account.",
        "source": "track-days-in-country-iphone.html",
    },
    {
        "path": "/compare/",
        "title": "Compare iPhone Location Journals — iso.me",
        "headline": "Choose how you keep your location history.",
        "description": "Compare iso.me with Google Timeline on iPhone: accounts, recording, backups, exports, and the limits of moving an existing archive.",
        "lede": "Understand the account, recording, backup, and export choices before changing the way you keep your own visits and routes.",
        "content": '<section class="card"><h2><a href="/compare/google-maps-timeline/">iso.me and Google Timeline</a></h2><p>A comparison of recording controls, device storage, backup, export formats, and payment. Learn where each fits and why your existing Google archive needs to be kept separately.</p><a href="/compare/google-maps-timeline/">Read the Google Timeline comparison</a></section><section><h2>New to recording your own history?</h2><p>Start with <a href="/blog/private-location-journal-iphone/">the private location journal guide</a>, or check <a href="/docs/export-import/">which files iso.me can export and restore</a>.</p></section>',
    },
    {
        "path": "/compare/google-maps-timeline/",
        "title": "Google Timeline Alternative for iPhone: iso.me Compared",
        "headline": "iso.me and Google Timeline on iPhone",
        "description": "Compare iso.me and Google Timeline for iPhone: accounts, local history, encrypted backup, GPX and CSV exports, pricing, and import limitations.",
        "lede": "Choose a location journal by the way you record, review, and keep a copy of your own history.",
        "source": "google-maps-timeline.html",
    },
    {
        "path": "/blog/view-location-history-iphone/",
        "section": "Guides",
        "section_path": "/blog/",
        "breadcrumb": "View location history",
        "type": "BlogPosting",
        "title": "How to See Your Location History on iPhone — iso.me",
        "headline": "How to see your location history on iPhone",
        "description": "Find iPhone location history in Apple Maps or Google Timeline, check Significant Locations settings, and preserve existing records before changing devices.",
        "lede": "Find the app and date that hold your saved visits, distinguish iPhone location settings from recorded history, and check existing copies before changing your setup.",
        "source": "view-location-history-iphone.html",
    },
    {
        "path": "/blog/record-iphone-route-gpx/",
        "section": "Guides",
        "section_path": "/blog/",
        "breadcrumb": "Record and export GPX",
        "type": "BlogPosting",
        "title": "How to Record an iPhone Route and Export GPX — iso.me",
        "headline": "How to record an iPhone route and export a GPX file",
        "description": "Record a route in iso.me, preview GPS points, export GPX to Files, and check the result. Includes a synthetic sample and clear free and paid limits.",
        "lede": "Start tracking in iso.me, stop after your trip, then select Points and GPX in Export. Recording and preview are free; saving the file requires the optional unlock.",
        "image": "/screenshots/export.png",
        "image_alt": "iso.me export interface with data types and file format choices",
        "source": "record-iphone-route-gpx.html",
    },
    {
        "path": "/blog/back-up-iphone-location-history/",
        "section": "Guides",
        "section_path": "/blog/",
        "breadcrumb": "Back up and restore history",
        "type": "BlogPosting",
        "title": "Back Up and Restore iPhone Location History — iso.me",
        "headline": "How to back up and restore your iso.me location history",
        "description": "Back up iso.me visits and GPS points as JSON. See a checked disk import, visit merging, repeated points, and what to verify before changing iPhones.",
        "lede": "Export Visits and Points separately as iso.me JSON, check the saved files, and keep the originals when importing on another iPhone.",
        "image": "/screenshots/export.png",
        "image_alt": "iso.me export interface with data and file format controls",
        "source": "back-up-iphone-location-history.html",
    },
    {
        "path": "/blog/iphone-location-tracking-battery/",
        "section": "Guides",
        "section_path": "/blog/",
        "breadcrumb": "Location tracking and battery",
        "type": "BlogPosting",
        "title": "iPhone GPS Tracking and Battery Use: iso.me Settings",
        "headline": "How to manage battery use while recording iPhone routes",
        "description": "Check iPhone battery activity, choose iso.me distance filters and auto-stop settings, and compare route detail without assuming a guaranteed battery saving.",
        "lede": "Check whether recording is still running, review iPhone’s battery report, and compare one setting at a time. A larger distance filter still uses high-accuracy GPS.",
        "source": "iphone-location-tracking-battery.html",
    },
    {
        "path": "/blog/missing-location-history-iphone/",
        "section": "Guides",
        "section_path": "/blog/",
        "breadcrumb": "Missing visits and route points",
        "type": "BlogPosting",
        "title": "Missing Visits or GPS Points in iso.me? iPhone Checks",
        "headline": "What to check when visits or route points are missing in iso.me",
        "description": "Check an empty iso.me outing, missing GPS points, visits, Watch sync, or export filters. Includes a checked zero-point example and steps that preserve your journal.",
        "lede": "Check the date and recording state, then separate missing points, missing visits, pending Watch transfers, and export filters. Keep existing records while you investigate.",
        "source": "missing-location-history-iphone.html",
    },
    {
        "path": "/blog/iphone-location-journal-obsidian/",
        "section": "Guides",
        "section_path": "/blog/",
        "breadcrumb": "Markdown journal in Obsidian",
        "type": "BlogPosting",
        "title": "Export an iPhone Location Journal to Obsidian — iso.me",
        "headline": "Read your iPhone location journal in Obsidian",
        "description": "Export iso.me visits as Markdown, copy the note into an Obsidian desktop vault, and keep your writing separate. Includes a synthetic sample and sync limits.",
        "lede": "Export visits as a Markdown file, copy it into your desktop vault, and check the rendered table. Keep your own writing separate from generated location notes.",
        "source": "iphone-location-journal-obsidian.html",
    },
]


# Not generated into public/ until the supporting App Store build is verified.
DRAFTS = [{
    "path": "/blog/import-google-timeline-iphone/", "section": "Guides", "section_path": "/blog/",
    "breadcrumb": "Import Google Timeline", "type": "BlogPosting", "robots": "noindex,follow",
    "title": "Import Google Timeline on iPhone — Release Preview — iso.me",
    "headline": "How to import Google Timeline into iso.me on iPhone",
    "description": "A release-preview walkthrough of supported Google JSON files, import preview, duplicate checks, and preserving the original archive.",
    "lede": "Prepared for the next supporting release. The verified public 1.7.16 build does not include this importer.",
    "source": "import-google-timeline-iphone.html",
}]


# Keep next steps specific to the task on each page.
RELATED = {
 '/integrations/dawarich/': [('/docs/webhooks/', 'Review send modes and queue limits', 'Check realtime, batching, retries, and manual-send behavior.'), ('/blog/back-up-iphone-location-history/', 'Keep a separate backup', 'A receiver copy is different from a restorable iso.me journal.')],
 '/blog/track-days-in-country-iphone/': [
     ('/blog/private-location-journal-iphone/', 'Record your next trip',
      'Start a local journal before you leave.'),
     ('/blog/back-up-iphone-location-history/', 'Keep the underlying records',
      'A country-date summary is not a complete backup.')],
 '/blog/view-location-history-iphone/': [('/blog/missing-location-history-iphone/',
                                          'Check missing iso.me records',
                                          'Diagnose recording gaps, hidden points, Watch '
                                          'transfers, and export filters.'),
                                         ('/blog/private-location-journal-iphone/',
                                          'Start a journal for future trips',
                                          'Set up recording before the next trip you want to '
                                          'remember.')],
 '/blog/record-iphone-route-gpx/': [('/blog/back-up-iphone-location-history/',
                                     'Keep a restorable copy',
                                     'GPX is a map file; retain supported visits and points '
                                     'separately for import.'),
                                    ('/blog/missing-location-history-iphone/',
                                     'Investigate an incomplete route',
                                     'Check recording state and filters before repeating the '
                                     'export.')],
 '/blog/back-up-iphone-location-history/': [('/blog/iphone-location-journal-obsidian/',
                                             'Make a readable Markdown note',
                                             'Copy a visit table into a desktop Obsidian vault.'),
                                            ('/docs/automatic-exports/',
                                             'Check scheduled copies',
                                             'Understand current-day exports, rewrite behavior, '
                                             'and background limits.')],
 '/blog/iphone-location-tracking-battery/': [('/blog/missing-location-history-iphone/',
                                              'Check a gap in your recording',
                                              'Separate missing records from hidden glitches and '
                                              'incomplete transfers.'),
                                             ('/blog/record-iphone-route-gpx/',
                                              'Save the route you recorded',
                                              'Preview points and write a portable GPX file.')],
 '/blog/missing-location-history-iphone/': [('/blog/back-up-iphone-location-history/',
                                             'Preserve the records you have',
                                             'Keep supported visit and point files before changing '
                                             'your setup.'),
                                            ('/docs/apple-watch/',
                                             'Check Watch recording and sync',
                                             'Read the status messages and verify the transferred '
                                             'day on your phone.')],
 '/blog/iphone-location-journal-obsidian/': [('/blog/back-up-iphone-location-history/',
                                              'Keep a separate restore copy',
                                              'A readable note with omitted fields may not be '
                                              'suitable for import.'),
                                             ('/docs/automatic-exports/',
                                              'Review automatic export behavior',
                                              'Check what a scheduled run writes and which files '
                                              'it can replace.')],
 '/compare/google-maps-timeline/': [('/blog/view-location-history-iphone/',
                                     'Find your existing records',
                                     'Check the service that recorded them before changing apps.'),
                                    ('/blog/record-iphone-route-gpx/',
                                     'Try the route export workflow',
                                     'See the free recording and preview steps before writing a '
                                     'GPX file.')]}


def related_navigation(path):
    items = RELATED.get(path, [])
    if not items:
        return ""
    links = "".join(f'<li><a href="{escape(url, quote=True)}">{escape(label)}</a><p>{escape(reason)}</p></li>' for url, label, reason in items)
    return f'<nav class="article-toc" aria-labelledby="read-next-title"><h2 id="read-next-title">Read next</h2><ul>{links}</ul></nav>'


def render(page):
    path = page["path"]
    url = BASE + path
    content = (MARKETING / "content" / page["source"]).read_text() if "source" in page else page["content"]
    section = page.get("section", "Compare")
    section_path = page.get("section_path", "/compare/")
    is_article = page.get("type") == "BlogPosting"
    image = BASE + page.get("image", "/screenshots/map.png")
    image_alt = page.get("image_alt", "iso.me map interface showing visits and route points")
    crumbs = [("iso.me", "/"), (section, section_path)]
    if path != section_path:
        crumbs.append((page.get("breadcrumb", "Google Timeline"), path))
    breadcrumb = {
        "@type": "BreadcrumbList",
        "itemListElement": [{"@type": "ListItem", "position": i, "name": name, "item": BASE + target} for i, (name, target) in enumerate(crumbs, 1)],
    }
    webpage = {"@type": "WebPage", "@id": url, "url": url, "name": page["title"], "description": page["description"], "inLanguage": "en", "dateModified": REVIEWED, "author": {"@type": "Person", "name": "Cody Bontecou", "url": "https://isolated.tech"}}
    if is_article:
        webpage.update({"@type": "BlogPosting", "headline": page["headline"], "datePublished": REVIEWED, "mainEntityOfPage": url, "image": image, "publisher": {"@type": "Organization", "name": "isolated.tech", "url": "https://isolated.tech"}})
    schema = json.dumps({"@context": "https://schema.org", "@graph": [webpage, breadcrumb]}, ensure_ascii=False, indent=2)
    nav_crumbs = "".join(f'<li>{escape(name)}</li>' if target == path else f'<li><a href="{target}">{escape(name)}</a></li>' for name, target in crumbs)
    # Preserve the site's existing production-host and analytics-gate behavior.
    home = (PUBLIC / "index.html").read_text()
    analytics = home[home.index("<!-- Cloudflare Web Analytics -->"):home.index("<!-- End Cloudflare Web Analytics -->") + len("<!-- End Cloudflare Web Analytics -->")]
    return f'''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{escape(page["title"])}</title>
  <meta name="description" content="{escape(page["description"], quote=True)}">
  <meta name="robots" content="{page.get('robots', 'index,follow')}">
  <link rel="canonical" href="{url}">
  <meta name="theme-color" content="#f5f4ef">
  <meta property="og:title" content="{escape(page["title"], quote=True)}">
  <meta property="og:description" content="{escape(page["description"], quote=True)}">
  <meta property="og:type" content="{'article' if is_article else 'website'}">
  <meta property="og:url" content="{url}">
  <meta property="og:image" content="{image}">
  <meta property="og:image:alt" content="{escape(image_alt, quote=True)}">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="{escape(page['title'], quote=True)}">
  <meta name="twitter:description" content="{escape(page['description'], quote=True)}">
  <meta name="twitter:image" content="{image}">
  <link rel="icon" href="/favicon.ico" sizes="any">
  <link rel="apple-touch-icon" href="/apple-touch-icon.png">
  <style>{(PUBLIC / 'assets' / 'seo.css').read_text()}</style>
  <script type="application/ld+json">{schema}</script>
</head>
<body>
  <a class="skip-link" href="#main">Skip to content</a>
  <nav class="site-nav" aria-label="Primary navigation">
    <a class="brand" href="/"><img src="/app-icon-28.webp" srcset="/app-icon-28.webp 1x, /app-icon-84.webp 3x" width="28" height="28" alt="">ISO.ME</a>
    <div class="nav-links"><a href="/blog/"{' aria-current="true"' if section == 'Guides' else ''}>Guides</a><a href="/compare/"{' aria-current="page"' if path == '/compare/' else ' aria-current="true"' if section == 'Compare' else ''}>Compare</a><a href="/docs/">Docs</a><a href="/#pricing">Pricing</a><a class="button" href="{APP}">Download free</a></div>
  </nav>
  <main id="main">
    <nav class="breadcrumbs" aria-label="Breadcrumb"><ol>{nav_crumbs}</ol></nav>
    {'<article aria-labelledby="article-title">' if is_article else ''}
    <header><p class="eyebrow">{'Practical iPhone guides' if is_article else 'iPhone location journals'}</p><h1 id="article-title">{escape(page["headline"])}</h1><p class="lede">{escape(page["lede"])}</p><p class="byline">By <a href="https://isolated.tech">Cody Bontecou</a>, iso.me’s developer · Reviewed <time datetime="{REVIEWED}">October 26, 2026</time></p></header>
    {content}
    {'</article>' if is_article else ''}
    {related_navigation(path)}
  </main>
  <footer class="site-footer"><a class="brand" href="/">ISO.ME · isolated.tech</a><div class="footer-links"><a href="/blog/">Guides</a><a href="/compare/">Compare</a><a href="/docs/">Docs</a><a href="/about">About</a><a href="/contact">Contact</a><a href="/privacy">Privacy</a><a href="/terms">Terms</a><a href="mailto:cody.bontecou@gmail.com">Support</a></div></footer>
  {analytics}
</body>
</html>
'''


def build():
    for page in PAGES:
        output = PUBLIC / page["path"].strip("/") / "index.html"
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(render(page))
        print(f"wrote {output.relative_to(PUBLIC)}")


if __name__ == "__main__":
    build()
