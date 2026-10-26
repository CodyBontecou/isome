# Whereday release migration

The app formerly named iso.me is now Whereday. Its canonical website is https://whereday.com. The old website and www host redirect with the path and query preserved.

Keep the existing App Store app ID 6761960794, bundle identifiers, App Group, purchase product IDs, background task identifiers, Keychain services, widget kinds, and GPX namespace. These identify existing data and entitlements. The myself.md migration app code remains `iso.me` because it is a server contract. Both `isome://` and `whereday://` links are supported. Markdown detection accepts both product names; new exports use Whereday.

App Store version: 1.7.17. Final build: 48. Exact listing publication requires human approval of ASO Tracker audit revision `fd534245-8246-43b1-8b56-fab4f7f7f30b`; no submission to App Review has been made.

Validation: 342 signed simulator tests passed, zero failures. Website: 32 pages and 1,109 local targets passed static validation; six acquisition/redirect tests and nine Python content/report tests passed. The deployed site passed 31 HTML/Markdown pairs plus API, errors, HEAD, Accept negotiation, and asset checks. Ninety screenshots cover nine locales across iPhone, iPad, and Apple Watch, with the illustrated English layout retained and Arabic caption shaping corrected.

Current metadata proposals are in `metadata/whereday/`. In-app purchase proposals preserve descriptions, prices, and product IDs. Spanish Individual Lifetime uses `Whereday Individual vitalicio` to fit Apple’s 30-character limit. Copyright changes from `© 2026 iso.me` to `© 2026 Whereday`.

## Follow-up screenshot direction

The human accepted the newer five English iPhone images named `Whereday-01-places.png` through `Whereday-05-export.png` and requested regenerated iPad images. Preserve that English iPhone set. Its Apple snapshot and downloaded proof live locally under `screenshots/whereday/adopted-english/`.

The iPad replacement uses five real feature views per locale, rather than onboarding: map, controls, open export formats, export filters, and webhook delivery. `scripts/capture_ipad_features.py` captures a dedicated iPad simulator using synthetic data; `scripts/compose_ipad_field_notes.py` adds localized captions and the field-notes design. Generated files, per-locale previews, and checksums live under `screenshots/whereday/ipad-v2/`. The complete intended Store collection is now 99 images: 45 iPhone, 45 iPad, and nine Watch screenshots. This image-only direction does not change the approved listing text.

The human approved publication of ASO revision `fd534245-8246-43b1-8b56-fab4f7f7f30b` on 2026-10-26. All nine listing locales, privacy/marketing/support URLs, copyright, and 27 purchase names were saved to editable Apple drafts. Purchase names required new editable IAP versions because approved versions are locked. Build 48 processed as VALID and is attached to editable app version 1.7.17. No App Review submission was made.

The approved English image/source pack was handed off from the ASO chat at `aso-tool/artifacts/whereday-rebrand-review-v1/`. Its five original iPhone PNG checksums match the saved Apple gallery. Canonical brand source now uses those approved app captures and includes a portable exporter for the 5244×2950 App Store product-page header. The ASO chat saved and verified that header. Reviewer notes were updated to Whereday and version 1.7.17 build 48, preserving the existing review steps.
