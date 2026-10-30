# Local subscription copy drafts for 1.7.19

> **Historical package:** superseded by [1.8](../1.8/README.md), now submitted with build 52 and all four subscriptions for App Review with MANUAL release. See [the current record](../../subscription-staging-1.8.md). The build-51 staging narrative below is preserved as historical evidence.

The nine app-version localizations and reviewer notes were subsequently staged, with user authorization, against uploaded **1.7.19/build 51** from pinned commit `d120326`. They remain an **unsubmitted draft**, not a published/released update or approved wording. The proposed extra subscription localizations and terms are still local; no website content or EULA selection was changed. See the [staging record](../../subscription-staging-1.7.19.md) for verified IDs and remaining approvals. Build 51 is now used; any replacement binary needs an unused build number.

The [live pricing hold](../../paid-tracking-rollout.md#live-pricing-hold--latest-instruction) remains mandatory. Do not change prices or schedule an increase when reviewing or staging this copy.

## Files

- `metadata/whereday/version/1.7.19/<locale>.json`: canonical app-version description, promotional text, and What's New for all nine existing locales. Keywords, support URL, and marketing URL are copied unchanged from 1.7.18. Earlier version metadata is untouched. Each description includes privacy and Terms of Use/EULA links.
- `subscription-localizations.json`: proposed group names and four subscription display names/descriptions for all nine locales (36 product localizations). This is a draft planning format, not a canonical app-version metadata file or an upload command input. Existing remote English product localizations were not changed.
- `terms-proposed.md`: proposed replacements for website terms sections 02, 04, 07, and 11, plus EULA/license review notes. It is deliberately outside `marketing/public`, `marketing/content`, and website generators. No effective date has been assigned and no existing legal page or EULA selection was changed.
- `reviewer-notes.txt`: proposed App Review notes, 3,684 characters before further edits, below the 4,000-character limit. Confirm the actual build number and prices before copying them into a future submission. The contact fields are not included; confirm them separately.
- `scripts/test_subscription_release_drafts.py`: offline structural checks for all drafts, character limits, locale coverage, preserved fields, links, and held prices in reviewer notes.

Paths in this document are relative to the repository root unless they name a file in this directory.

## Copy contract

The new-user rule is based on when the person first obtained Whereday, not whether they install an update, replay onboarding, or reinstall today. The intended migration recognizes verified original builds 1 through 50 as existing users. Build 51 is the intended first subscription build. Existing local grants remain sticky.

The drafts distinguish these groups:

- Existing users retain free tracking. Existing free users retain the export purchase requirement; the update does not give every existing user free export.
- Prior lifetime purchases stay valid, including Family Sharing on the original unlock. Existing users do not need to subscribe to keep their existing access.
- New users must confirm an eligible trial or hold valid purchased access before tracking. Weekly/yearly subscriptions offer seven days free when Apple reports eligibility, then renew automatically unless canceled. Lifetime is a separate one-time purchase, without a subscription trial. There is no monthly plan.
- New-cohort users retain viewing/export of existing records after expiration; new recording and manual visits require active access. Expiration does not delete their history.
- Family products share access with up to five other family members through Apple, not the person's location journal. Individual products are not shared.

Public listing drafts contain no fixed dollar amounts. Apple supplies the actual storefront price, interval, currency, eligibility, and confirmation. This avoids announcing held target lifetime prices as current. Reviewer notes use the held U.S. prices and the configured subscription prices because reviewers need to understand the actual products.

## Price references for internal review only

| Product | Current configuration | Target after the pricing hold is lifted |
|---|---:|---:|
| Individual Weekly | $0.99/week, unsubmitted subscription | Same |
| Individual Yearly | $29.99/year, unsubmitted subscription | Same |
| Family Weekly | $1.99/week, unsubmitted subscription | Same |
| Family Yearly | $49.99/year, unsubmitted subscription | Same |
| Individual Lifetime | $19.99 live U.S. price | $49.99 |
| Family Lifetime | $39.99 live U.S. price | $89.99 |
| Family Lifetime Upgrade | $19.99 live U.S. price | $40.00 |

The target IAP prices must not be applied until all four subscriptions are approved, the subscription-enabled app is live, and the user separately authorizes changing prices. No date-based increase is scheduled by this package. Preserve regional overrides again whenever a later price change is authorized.

## Review required before submission

1. Owner review of the policy, reviewer steps, plan names, and copy. The non-English text is draft translation, not certified or native-speaker-reviewed legal copy. The version localizations have been staged as drafts; native-language approval is still needed before submission. The legal proposal and reviewer instructions are in English only; do not assume the website terms have been localized.
2. Legal review of the proposed terms, trial/cancellation wording, consumer rights, and applicable Apple license. Confirm the existing App Store EULA selection. A website terms update does not set a custom EULA. The proposed copy flags the existing section 05 restrictions for reconciliation with the repository's AGPL license rather than silently changing license rights.
3. Separately authorize and time the legal-page update so the app's existing `/terms` link explains the subscription model during review. The draft listing link currently resolves to the existing old-model terms; offline validation verifies the link's presence and syntax, not the proposed terms being live. No URL checks or network fetches were run for draft validation.
4. Recheck the final distribution build, migration cutoff, sandbox eligibility, restore, expiry, Family Sharing, Watch, permissions, and UI paths. Reviewer steps are expected behavior to verify, not a claim that device QA has already passed.
5. Refresh App Review screenshots when authorized. Earlier local screenshots were captured from target-price StoreKit fixtures ($49.99/$89.99 lifetime), while live prices are held at $19.99/$39.99. Use screenshots that match the actual candidate and held purchase prices; do not solve a screenshot mismatch by changing live prices. The current UI may also differ from those earlier screenshots.
6. Confirm screenshots, iPad support, App Privacy disclosures (including limited technical services), paid agreements, the first-subscription review association, review contacts, and manual developer release. None are changed by this package.

Future website pricing/marketing changes must explain the new-user-only policy while keeping existing-user rights clear. Prepare those changes separately, and do not publish future prices as current. This draft package does not modify generated website content.

## Local validation

Run the copy checks without contacting Apple:

```sh
python3 -m unittest discover -s scripts -p test_subscription_release_drafts.py -v
```

Validate only the new version in a temporary canonical tree, so warnings in historical live-version descriptions do not obscure the draft result:

```sh
DRAFT_ROOT=$(mktemp -d /tmp/whereday-subscription-metadata.XXXXXX)
mkdir -p "$DRAFT_ROOT/version/1.7.19"
cp metadata/whereday/version/1.7.19/*.json "$DRAFT_ROOT/version/1.7.19/"
cp -R metadata/whereday/app-info "$DRAFT_ROOT/app-info"
asc --read-only metadata validate --dir "$DRAFT_ROOT" --subscription-app --output json
```

Do not add `--check-urls`, run a metadata push/apply (even a remote dry run), authenticate, or deploy as part of this local drafting task. The validation run scanned 18 files (nine existing app-info files and nine new version files) with **0 errors and 0 warnings**. All **6 offline copy tests passed**. They also cover all 36 subscription product descriptions against the 55-character limit and product names against the 30-character limit. Evidence is under `.asc/artifacts/paid-tracking/release-drafts-1.7.19/` (gitignored).
