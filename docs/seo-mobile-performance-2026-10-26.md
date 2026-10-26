# Mobile acquisition-page performance audit

Measured October 26, 2026 against production at source commit `ac20d78`.

## Decision

Keep the current page-loading implementation. The four main acquisition pages
pass the existing strict Lighthouse check, with no measured loading problem
that warrants a code change. Continue the release and workflow evidence backlog
rather than spending time on speculative performance tuning.

## Lighthouse results

One sequential mobile navigation per URL using the repository's pinned
Lighthouse 13.5.0 script. Performance, accessibility, best practices, and SEO
each scored 100 on every page, with no run warnings.

| Page | LCP | CLS | Total blocking time | Transferred during audit |
| --- | ---: | ---: | ---: | ---: |
| Homepage | 1.07 s | 0 | 0 ms | 111.4 KiB |
| Private journal | 0.93 s | 0 | 0 ms | 200.8 KiB |
| GPX guide | 0.92 s | 0 | 0 ms | 40.6 KiB |
| Google comparison | 0.90 s | 0 | 0 ms | 16.8 KiB |

Transferred bytes are those observed in this navigation, not the total size
of every asset available on a long page. Below-fold lazy images may not load.

The mobile profile uses a 412×823 viewport at DPR 1.75, simulated 150 ms RTT,
1638.4 Kbps throughput and a 4× CPU slowdown. These are lab results from this
machine and run, not a field percentile or a guarantee for every visitor.
The Lighthouse SEO category is not a ranking or Google-indexation score.

## Homepage trace

An additional Chrome DevTools navigation used a different, explicitly emulated
profile: 390×844 at DPR 3, Slow 4G, 4× CPU slowdown and HTTP-cache bypass.
Observed LCP was 665 ms, with 237 ms TTFB, 428 ms render delay, and CLS 0.
Do not compare its observed timings directly with Lighthouse's simulated ones.
DevTools reported no CrUX field data for the page.

The image-delivery insight flagged the large map screenshot with an estimated
116.8 kB byte saving but **0 ms estimated FCP/LCP saving**. Existing homepage
image markup already has responsive sources. This is a possible bandwidth
experiment, not evidence of a current loading bottleneck; no image-quality
change was made solely for this warning.

The network-dependency insight included the analytics exclusion gate and
Cloudflare's email-decoding script, with no estimated savings. The external
gate transferred 606 bytes in this trace. No preconnect or analytics-gate
change was made. Existing privacy exclusions remain in effect.

## Limits and repeat command

[Google's Web Vitals guidance](https://web.dev/articles/vitals) distinguishes
lab data from real-user data and notes that a navigation-only Lighthouse run
cannot measure INP. Zero total blocking time is a useful lab observation, not
an INP measurement. No real-user Core Web Vitals pass, ranking improvement, or
download lift is claimed from this audit.

```sh
python3 marketing/scripts/audit_lighthouse.py \
  --device mobile \
  --path / \
  --path /blog/private-location-journal-iphone/ \
  --path /blog/record-iphone-route-gpx/ \
  --path /compare/google-maps-timeline/ \
  --output /private/tmp/isome-seo-performance
```

[Machine-readable results](seo-mobile-performance-2026-10-26.json) retain
fetch times, exact metrics, scores and settings. Full Lighthouse HTML/JSON
reports are retained locally in `build/seo-evidence/performance-20261026/`.
The DevTools trace findings are recorded above; its optional raw-file export
was unavailable under the tool's configured workspace roots.

No website assets, analytics behavior, app binaries or deployment were changed.
