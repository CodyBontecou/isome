# iOS test verification

Run `scripts/test-ios.sh` for iOS tests, including targeted runs with `-only-testing:IsoMeTests/CLASS`. CI uses the same runner. It preserves simulator signing needed by Keychain tests and prints the result bundle path.

For destination overrides, runner guardrail tests, or a Keychain entitlement setup failure, read [CONTRIBUTING.md — Run tests](CONTRIBUTING.md#run-tests). Treat setup failures as environment failures, not credential-logic regressions; report them rather than skipping the tests.
