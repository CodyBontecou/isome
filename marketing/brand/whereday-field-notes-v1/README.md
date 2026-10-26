# Whereday brand assets

Run `npm install` and `npm run build` in this directory to rebuild the illustrated English App Store screenshots, responsive website graphics, and social preview.

The source separates original background art from real simulator screenshots. Map, timeline, route, and export screens were captured from the Whereday release candidate. The Country Days screen retains the existing synthetic example. Do not replace these with private location history.

Generated `app-store/`, `headers/`, `review/`, and `manifest.json` are local review outputs. Website derivatives are written to `marketing/public/assets/whereday-field-notes-v1/`. The localized screenshot pipeline is `scripts/capture_localized_screenshots.py`; its nine-locale upload bundle and checksum manifest are under `screenshots/whereday/`.
