# Complimentary myself.md access

The claim flow is currently hidden behind the build-time `MyselfClaimFeature.isEnabled` flag in `IsoMe/Views/MyselfClaimView.swift` (default `false`). This hides the Settings section and release-note mention, ignores claim deep links, and prevents purchase verification. Set it to `true` to restore the flow in a future build after completing the validation below.

When enabled, Settings includes **Claim myself.md access**. The user explicitly agrees to submit purchase evidence, the myself.md service verifies it, and a short-lived browser link lets them sign in and claim lifetime access for one account. No health or location data is sent.

iso.me retains its existing purchase and export policies. Base Individual and Family lifetime purchasers qualify. Family-shared recipients and upgrade-only products cannot claim separately. Health.md also honors its existing original-download cutoff of April 26, 2026, 00:00 UTC. Health.md Google Play purchasers qualify through `health_md_premium_lifetime`; F-Droid and the free Mac companion do not prove a paid purchase.

The production claim service defaults to `https://myself.md`. Swift builds can override it with `MyselfClaimServerURL` in Info.plist for an HTTPS test service. Health.md Android currently targets the production host. The server requires the legacy apps' Apple app IDs and signing credentials, or Google Android Publisher credentials with Health.md access. It rejects sandbox evidence unless running a separate sandbox service.

Deploy the myself.md backend/dashboard before releasing these buttons. Then validate live store proofs, cancel/retry, expired links, signing in as the wrong account, restore, and the one-account claim rule. The user must sign into the same account in myself.md to retrieve access. Do not advertise this flow as live until the backend is configured and deployed.

The complete setup, qualification matrix, and time.md operator grant instructions are in `shared-js-app/docs/customer-migration.md` in the companion myself.md repository. Explain the existing-customer migration in App Review notes.

## Direct claim-screen handoff

`isome://myself/claim` presents the same `MyselfClaimView(app: "iso.me")` used by Settings, including on cold launch. The exact route accepts no credentials, port, query or fragment. Opening it does not verify a purchase, sync the App Store, start OAuth or grant access; the user must choose Verify purchase and continue. Existing `isome://stop` behavior is preserved. Updated app binaries are required for this route.
