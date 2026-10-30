# Whereday 1.8 privacy review

**Unpublished candidate review. No deployment, submission, release, price change or remote data deletion.**

The collector is removed in all build configurations, replacing the earlier Release-only disabling proposal. Preserve the first-paid cohort cutoff of 51. Scheduling still uses a separate Keychain identity, push token, time zone and configuration. Disabling a schedule does not prove deletion of its device registration. The [deployed-service audit](../1.7.19/privacy-deployed-audit.md) remains evidence for earlier events, retained claims, missing expiry and recovery limitations. Do not apply its build-51 six-type label blindly to a replacement candidate.

## Shared removal policy

The candidate contains no custom analytics client, event queue, upload job, persistent analytics identifier, pricing-experiment assignment or app advertising-attribution collector. Debug flags and bundle/environment endpoints cannot re-enable the removed implementation. Upgrade cleanup removes known analytics-only local state while preserving purchase entitlements, local content, export history, scheduling identities and app settings used by essential features.

The analytics-only Worker is replaced locally with a storage-free retirement responder: legacy uploads receive HTTP 204 and are discarded without reading the body. No D1/KV binding, analytics cron, aggregate generation or analytics retention mechanism remains in the candidate Worker. The abandoned opt-in/30-day event design is superseded and its unapplied migration is removed. Historical applied migrations remain as provenance. No migrations or remote deletions were executed.

## Older versions and existing records

This is an unpublished source change. Previously distributed binaries, submitted builds and deployed services remain unchanged and can still send/accept analytics. No claim that collection has stopped in production is approved here. Retained installation-linked events are pseudonymous, not anonymous. Updating or uninstalling does not erase previously received events, operator exports, provider logs or recovery copies.

After separate owner approval: deploy the discard responder first, confirm writes have stopped, erase the dedicated analytics database and analytics-only exports, review processor logs/recovery retention, and record actual deletion/expiry evidence. Inspect ownership before deleting resources. Do not reassign analytics identifiers to essential services. A new signed app candidate and an approved cutover are required before the replacement policy becomes effective.

## Essential services and review decisions

Purchase validation/restoration, scheduling, provider authorization, selected file/API destinations, local diagnostics and support remain governed by their actual purpose and existing implementation. They must not gain product-event logging. Removing analytics does not establish a new retention or deletion guarantee for those services. Do not claim universal “Data Not Collected,” “anonymous,” “no servers,” or deletion on uninstall.

Before submission, review App Privacy / Play Data Safety for the exact candidate and every essential processor. Remove analytics purposes only where no remaining collection supports them; retain App Functionality declarations for applicable identifiers, purchase verification and scheduling. Verify provider logs, account linkage, legal URLs and native-language text. No questionnaire or store metadata was changed remotely. Prices and product IDs are unchanged. Myself.md claim entry points remain disabled; earlier retained grants need their existing disclosure.

Website traffic measurement is separate from in-app collection and remains disclosed under the website policy. No website measurement exemptions are asserted by this change.
