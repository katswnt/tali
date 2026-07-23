# Tali release checklist

## Automated

- [ ] `swift test --scratch-path .build-spm`
- [ ] `npm test -- --run` in `Server`
- [ ] `npm run check` in `Server`
- [ ] `npm run db:migrate:local` in `Server`
- [ ] Run `npm run dev` and then `npm run test:integration:local`
- [ ] Build the `Tali` scheme for the selected simulator with normal signing

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

## Physical iPhone

- [ ] Select the development team for both Tali targets
- [ ] Confirm the same App Group is enabled for the app and Messages extension
- [ ] Install and launch Tali from Xcode
- [ ] Open Tali from the Messages app drawer
- [ ] Log a habit and insert an optional receipt
- [ ] Verify the app and extension see the same entry
- [ ] Verify Siri and Shortcuts discover Tali's App Intents

## SMS and carrier

- [ ] A2P campaign status is Verified
- [ ] Tali's number is in the `Tali SMS` Messaging Service sender pool
- [ ] Advanced Opt-Out is enabled and matches the registered messages
- [ ] Incoming webhook is `https://tali-sms.katswint.workers.dev/twilio/incoming` using HTTP POST
- [ ] Text `START`, `HELP`, a configured habit, `HABITS`, `UNDO`, and `STOP`
- [ ] Confirm Twilio logs contain no 11200, 30034, or signature failures
- [ ] Confirm the app syncs the SMS entry exactly once
