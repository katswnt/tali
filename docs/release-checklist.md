# Tali release checklist

## Automated

- [x] Run `./scripts/release-check.sh`
- [x] Confirm it regenerates the Xcode project without a diff
- [x] Confirm all 26 Swift tests and all 58 Worker tests pass
- [x] Confirm the npm audit reports no high or critical advisories
- [x] Confirm the managed local Worker/D1 test passes revisioned sync, SMS, tenant isolation, rotating-session lifecycle, rate limits, and retention
- [x] Confirm the `Tali` app and embedded Messages extension build without source warnings
- [x] Confirm all three deterministic iOS UI smoke journeys pass locally
- [x] Confirm `App/PrivacyInfo.xcprivacy` matches the production behavior and `docs/app-store-submission.md`

## Simulator

- [x] Launch without a SwiftData/App Group crash
- [ ] Add, edit, log, archive, and restore a habit
- [ ] Confirm duplicate habit names or aliases show an inline error
- [ ] Pull to refresh and confirm SMS events appear once
- [ ] Confirm the Texting sheet shows connection status and can sync manually
- [ ] Export CSV and JSON; verify archived habits, voided entries, notes, and timestamps are present
- [ ] Confirm the complete JSON archive includes both `local` and `server` sections when signed in
- [ ] List active devices, revoke a non-current session, and confirm that token becomes unauthorized
- [ ] Delete a test account and confirm server export, sync, and pairing access are revoked
- [x] Test maximum Dynamic Type, dark mode, and increased contrast
- [ ] Test VoiceOver focus order and labels on a physical device or with Accessibility Inspector
- [x] With accessibility Dynamic Type enabled, confirm Activity becomes a readable active-day list

## Physical iPhone

- [x] Confirm development team `7JZ2WK3L6X` resolves for both Tali targets
- [x] Confirm the same App Group is enabled for the app and Messages extension
- [x] Install and launch Tali from Xcode
- [x] Open Tali from the Messages app drawer
- [ ] Log a habit and insert an optional receipt
- [ ] Verify the app and extension see the same entry
- [ ] Verify Siri and Shortcuts discover Tali's App Intents
- [x] Pair the production SMS number, exercise the command grammar, and sync the result into the app
- [x] Save Tali's green contact card and photo through the native Contacts confirmation flow

## Archive and TestFlight

- [x] Create the App Store Connect record for `com.kathrynswint.Tali`
- [x] Confirm version `0.1.0` build `1` has not previously been uploaded
- [x] Add the TestFlight beta description, marketing URL, and privacy policy URL
- [x] Set `CURRENT_PROJECT_VERSION` to a value not previously uploaded
- [x] Archive with the `Tali` scheme using a generic iOS device destination
- [x] Validate the archive with Apple's distribution service with no privacy, entitlement, icon, or extension-version errors
- [x] Confirm the archive contains `PrivacyInfo.xcprivacy`, the Messages extension, App Group, and Sign in with Apple entitlements
- [ ] Reconcile App Privacy answers with `docs/app-store-submission.md`
- [x] Verify the privacy and support URLs are public and accurate
- [x] Upload build `0.1.0 (1)` to TestFlight and attach it to the `Tali Internal` group
- [x] Upload build `0.1.0 (2)` to TestFlight and attach it to the `Tali Internal` group
- [x] Upload build `0.1.0 (3)` to App Store Connect with App Shortcut registration enabled
- [x] Attach build `0.1.0 (3)` to the `Tali Internal` group
- [x] Upload build `0.1.0 (4)` with hardened iOS 26.5 Shortcuts discovery
- [ ] Attach build `0.1.0 (4)` to the `Tali Internal` group after Apple finishes processing it
- [x] Add Kathryn Swint as an internal tester and confirm App Store Connect reports `Invited`
- [ ] Install the current TestFlight build and complete internal testing on a physical iPhone

## SMS and carrier

- [ ] A2P campaign status is Verified
- [ ] Tali's number is in the `Tali SMS` Messaging Service sender pool
- [ ] Advanced Opt-Out is enabled and matches the registered messages
- [ ] Message-body redaction and Twilio retention settings match the deployed privacy policy
- [ ] Incoming webhook is `https://tali-sms.katswint.workers.dev/twilio/incoming` using HTTP POST
- [ ] Text `START`, `HELP`, a configured habit, `HABITS`, `UNDO`, and `STOP`
- [ ] Confirm Twilio logs contain no 11200, 30034, or signature failures
- [ ] Confirm `/twilio/status` records delivery categories without message contents or phone numbers
- [ ] Confirm the app syncs the SMS entry exactly once
