# Missing-history guide: diagnostic evidence and export checks

Reviewed October 26, 2026. Improves the existing
`/blog/missing-location-history-iphone/` and adds a contextual link from
`/docs/export-import/`. The established title and URL are retained.

## Why this task

The discovery pass is complete. The remaining major new workflow claims need
a supporting public importer release, a physical route/Watch check, or a
successful clean-destination restore. This improvement uses existing verified
evidence to answer a distinct troubleshooting intent on its existing URL.
It is an editorial priority based on usefulness and product fit; no new query
volume, ranking, or conversion result establishes it as a search winner.

## Evidence reviewed

- Release source `6ae78e622c72ee051e6f14113082556c398d926a`, 1.7.16 (46):
  `LocationManager.saveLocationPoints` accepts reported accuracy 0–100 m.
- Released `ExportOptions.filterVisits` selects arrival time, the optional
  time-of-day window, completion, and duration. `filterPoints` selects point
  time, time of day, outliers, and accuracy cap. The released
  `IsoMeExportKitAdapter` invokes those filters. In particular, a visit arriving
  before a selected date range is excluded even if departure falls inside it.
- Existing [recording-state evidence](seo-journal-recording-state-2026-10-26.md):
  eight-second isolated simulator outing, zero points. Reused its unchanged
  screenshot with explicit setup/limits; no new device test was performed.
- Existing [GPX evidence](seo-gpx-viewer-2026-10-26.md): five invented points,
  actual serializer, checked viewer. Linked as a file example, not recovery.
- Apple's [Location Services guidance](https://support.apple.com/en-us/102515),
  fetched October 26, 2026, published May 20, 2026: permission settings,
  acquisition time, and obstacles to satellite visibility. No personal
  location, Apple account, or platform location-history settings were accessed.

## Published content

The guide now shows the checked empty outing, gives a five-step non-destructive
export diagnosis, answers four practical questions, and labels old import
behavior with its verified release. The export reference links directly to
that diagnosis. The shared design, canonical, download destination, and page
count are retained; Markdown and metadata are regenerated.

Static checks pass: 31 HTML pages (including 404), 30 public Markdown pages,
1,057 local targets, metadata, JSON-LD, IDs, sitemap, and `git diff --check`.
At 390 px, viewport and document width both measure 390 px.

No new native workflow success, recoverability guarantee, field performance,
Google indexation, rankings, outreach, campaign creation, or app binary release
is claimed. No duplicate indexing request is needed for this content update.
