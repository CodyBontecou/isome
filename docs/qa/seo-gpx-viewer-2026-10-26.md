# GPX guide: reproducible serializer and viewer evidence

October 26, 2026. Follow-up to the SEO implementation, on `main`.

## Project environment

Argent environment inspection confirms native Swift iOS + watchOS, not React
Native or Android. Project `IsoMe.xcodeproj`, scheme `IsoMe`, bundle ID
`com.bontecou.isome`; current source is 1.7.17 (47). No simulator was interacted
with for this check. Physical recording remains unverified in this batch.

## Serializer check

`python3 marketing/scripts/check_gpx_sample.py` compiles the unchanged GPX
extension from `ExportService.swift` against small fixture value types. It
invokes `exportLocationPointsToGPX`, the serializer used by the export adapter.
It does not exercise the full render pipeline, filters, recording, SwiftData,
purchase gating, filename planning, or sharing UI.

The GPX extension is byte-identical to the extension in release source
`6ae78e622c72ee051e6f14113082556c398d926a` (public 1.7.16 build 46).

The fixture has five invented coordinates from (0, 0) to (0.0004, 0.0004),
with times 12:00, 12:01, 12:02, 12:13 and 12:14 UTC on January 1, 2000.
Input order is reversed. Assertions verify sorted point times and coordinates,
no waypoints, two segments of three and two points, and equivalence to the
published sample except for the current metadata export time.

Use `--write` to deliberately regenerate the sample. The old three-point,
hand-authored example remains available and explicitly labelled.

## Viewer check

Loaded the exact synthetic serializer output into [gpx.studio](https://gpx.studio/)
using its documented [public URL integration](https://gpx.studio/help/integration).
The file was served from preview `a9b4412b.spotted-8ez.pages.dev`. HTTP returned
200, application/gpx+xml and the CORS allow-origin https://gpx.studio. Only the
new public synthetic sample has that CORS rule.

Observed one track, two segments in View → File tree, and two red lines with a
visible gap on the map. Displayed distance: 0.05 km; displayed moving/total
time: 03:00 / 03:00. The eleven-minute inter-segment gap is not included in that
displayed time. These are synthetic fixture results, not accuracy benchmarks.

Screenshot: `marketing/public/screenshots/gpx-studio-synthetic.png` (1280×720).
The public guide includes the screenshot, expected point/segment table, file
download, viewer link, and explicit evidence limits.

No personal location data was used, uploaded, or published. No physical iPhone
or Watch test was performed. The real recording → paid export → viewer path
and clean-destination restore remain open tasks.

Local guide verification: site checker passed 29 HTML pages and 952 local
targets; all five acquisition tests passed. At a 390-pixel viewport the page
width was 390 pixels, the viewer screenshot was 358 pixels wide, and no images
were broken. The table and screenshot were visually inspected on mobile.
