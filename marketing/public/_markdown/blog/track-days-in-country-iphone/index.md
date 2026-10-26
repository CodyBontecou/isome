- [iso.me](https://isome.isolated.tech/)
- [Guides](https://isome.isolated.tech/blog/)
- Country days

Practical iPhone guides

# How to track days spent in each country on iPhone

Review country totals and the dates behind them, add missing stays, and keep a personal record without an iso.me account.

By [Cody Bontecou](https://isolated.tech), iso.me’s developer · Reviewed October 26, 2026

## Count the dates you can account for

In iso.me, open Timeline → Country Days to count local dates represented by your recorded visits, route points, and manual stays. Choose this year, the last 365 days, or all time, then open a country to review its dates. Viewing the counts and adding manual stays are free. Writing the CSV file requires the optional export purchase.

This guide covers Country Days in iso.me 1.7.16. It is a personal travel journal: its rules do not determine tax residency, immigration status, or how a visa counts a day.

Build your country record
- [Open your country totals](https://isome.isolated.tech/blog/track-days-in-country-iphone/#start)
- [Understand travel days and timezones](https://isome.isolated.tech/blog/track-days-in-country-iphone/#rules)
- [Add a missing stay](https://isome.isolated.tech/blog/track-days-in-country-iphone/#manual)
- [Identify countries in older records](https://isome.isolated.tech/blog/track-days-in-country-iphone/#privacy)
- [Save a CSV copy](https://isome.isolated.tech/blog/track-days-in-country-iphone/#csv)

## 1. Review the dates behind each total

- Open Timeline, then Country Days.
- Select a period. The default is this year; the other choices are the last 365 days and all time.
- Open a country and review the individual dates. A total is only useful when you understand which dates produced it.
- If older locations lack countries, use the analysis controls described below. If nothing was recorded for a stay, add it manually rather than expecting GPS to recreate it.

To collect new history, start recording before your trip. Start enables detailed GPS and visit monitoring together; Stop ends both. Read [the first-recording guide](https://isome.isolated.tech/blog/private-location-journal-iphone/) for permissions and recording controls.

![Country Days on iPhone, with period filters, country analysis, and Add stay controls](https://isome.isolated.tech/screenshots/country-days.webp)

Country Days before any country dates have been resolved. Captured in development build 1.7.17 (47), in an iOS 26.5 simulator on October 26, 2026; this is an interface example, not a recorded trip.

## 2. Check the counting rules

Presence dates, rather than a continuous travel guarantee
| Situation | How iso.me counts it
| Many points in the same country on one date | One day for that country, rather than one day per record.
| Two countries on a travel day | That date can count in both countries. Adding country totals may exceed the number of distinct dates.
| A record near midnight | The resolved location’s timezone determines the local date, rather than UTC or your phone’s current timezone.
| A completed visit with a verified departure | Its local date range can contribute multiple dates.
| An open visit or unverified departure | Only its arrival date is counted. Route points or manual stays can account for other dates.
| Unknown country, GPS outlier, or recording gap | No invented dates or automatic continuous stay.
| Overlapping manual and recorded presence | The date counts once per country; the source flags can show both.

### A simple border-crossing example

Imagine a recorded point in Portugal on October 1 and another in Spain later that local date. Each country gets October 1. If a manual Portugal stay also includes October 1, Portugal still gets one day. If October 2 has no usable evidence or manual stay, the app does not fill it merely because you have records before and after it.

This is an invented example of the counting rules, not a captured trip. Review gaps with the [missing-records checklist](https://isome.isolated.tech/blog/missing-location-history-iphone/) before changing your journal.

## 3. Add a stay that was not recorded

Use Add stay in Country Days. Choose the country and first and last dates, add an optional note, and save. Review the affected country’s dates afterwards. You can edit or delete a manual stay when you find a mistake.

A manual stay records your account of a trip; it does not create a GPS path. Keep tickets or other original records separately if you need them. Overlapping manual stays do not multiply the same country/date.

## 4. Identify countries in older locations

New recordings identify countries when network geocoding is enabled. Analyze saved locations checks earlier records in batches, with stop and resume controls. It can take time for a large archive.

Country identification uses Apple geocoding and follows your network-geocoding preference. A lookup sends coordinates to Apple; turning it off changes which unresolved locations can be assigned a country. Your journal remains on your device, and iso.me does not receive an archive of it. See the [privacy policy](https://isome.isolated.tech/privacy) for all network boundaries.

Analysis can identify a country for an existing coordinate. It cannot recover locations that were never recorded. Use a manual stay for dates you can account for independently.

## 5. Keep a CSV copy of your country dates

Use the export control in Country Days and save the CSV to a destination you choose. The file includes country codes, local dates, and recorded/manual source information. Viewing and editing your counts are free; writing this export requires the lifetime unlock. See [current pricing](https://isome.isolated.tech/#pricing).

Check a known date and a travel day in the saved file. A country-date CSV is a summary, not a backup of every visit, route point, or manual stay. Keep your underlying records using the [backup checklist](https://isome.isolated.tech/blog/back-up-iphone-location-history/).

## Remember the country.
Keep the dates behind the count.

Start a free local journal and review Country Days on your iPhone.

[Download free for iPhone](https://apps.apple.com/us/app/iso-me/id6761960794)

Reviewed October 26, 2026 against the source used for App Store 1.7.16 build 46, including CountryDaysView, CountryDayCalculator, and CountryDayResolver. The examples are synthetic. They do not represent a new physical travel test.

## Read next

- [Record your next trip](https://isome.isolated.tech/blog/private-location-journal-iphone/)

Start a local journal before you leave.

- [Keep the underlying records](https://isome.isolated.tech/blog/back-up-iphone-location-history/)

A country-date summary is not a complete backup.

Source: https://isome.isolated.tech/blog/track-days-in-country-iphone/
