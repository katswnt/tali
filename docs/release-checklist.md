# Tali release checklist

## Automated

- [ ] Run `./scripts/release-check.sh`
- [ ] Confirm it regenerates the Xcode project without a diff
- [ ] Confirm all 19 Swift tests and all 29 Worker tests pass
- [ ] Confirm the npm audit reports no high or critical advisories
- [ ] Confirm the managed local Worker/D1 test passes sync, SMS, tenant isolation, account lifecycle, rate limits, and retention
- [ ] Confirm the `Tali` app and embedded Messages extension build without warnings
- [ ] Confirm `App/PrivacyInfo.xcprivacy` matches the production behavior and `docs/app-store-submission.md`

## Simulator

- [ ] Launch without a SwiftData/App Group crash
- [ ] Add, edit, log, archive, and restore a habit
- [ ] Confirm duplicate habit names or aliases show an inline error
- [ ] Pull to refresh and confirm SMS events appear once
- [ ] Confirm the Texting sheet shows connection status and can sync manually
- [ ] Export CSV and JSON; verify archived habits, voided entries, notes, and timestamps are present
- [ ] Confirm the complete JSON archive includes both `local` and `server` sections when signed in
- [ ] List active devices, revoke a non-current session, and confirm that token becomes unauthorized
- [ ] Delete a test account and confirm server export, sync, and pairing access are revoked
- [ ] Test large Dynamic Type, dark mode, and VoiceOver labels
- [ ] With accessibility Dynamic Type enabled, confirm Activity becomes a readable active-day list

## Physical iPhone

- [ ] Confirm development team `7JZ2WK3L6X` resolves for both Tali targets
- [ ] Confirm the same App Group is enabled for the app and Messages extension
- [ ] Install and launch Tali from Xcode
- [ ] Open Tali from the Messages app drawer
- [ ] Log a habit and insert an optional receipt
- [ ] Verify the app and extension see the same entry
- [ ] Verify Siri and Shortcuts discover Tali's App Intents

## Archive and TestFlight

- [ ] Increment `CURRENT_PROJECT_VERSION` before each upload
- [ ] Archive with the `Tali` scheme using a generic iOS device destination
- [ ] Validate the archive in Organizer with no privacy, entitlement, or extension-version warnings
- [ ] Confirm the archive contains `PrivacyInfo.xcprivacy`, the Messages extension, App Group, and Sign in with Apple entitlements
- [ ] Reconcile App Privacy answers with `docs/app-store-submission.md`
- [ ] Verify the privacy and support URLs are public and accurate
- [ ] Upload to TestFlight and complete internal testing on a physical iPhone

## SMS and carrier

- [ ] A2P campaign status is Verified
- [ ] Tali's number is in the `Tali SMS` Messaging Service sender pool
- [ ] Advanced Opt-Out is enabled and matches the registered messages
- [ ] Incoming webhook is `https://tali-sms.katswint.workers.dev/twilio/incoming` using HTTP POST
- [ ] Text `START`, `HELP`, a configured habit, `HABITS`, `UNDO`, and `STOP`
- [ ] Confirm Twilio logs contain no 11200, 30034, or signature failures
- [ ] Confirm `/twilio/status` records delivery categories without message contents or phone numbers
- [ ] Confirm the app syncs the SMS entry exactly once
