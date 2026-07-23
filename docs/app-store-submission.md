# App Store submission packet

This document is the source of truth for Tali's first App Store Connect record. It describes the
current product and data behavior; update it whenever those behaviors change.

## Product metadata

- **Name:** Tali
- **Subtitle:** Track moments without judgment
- **Primary category:** Health & Fitness
- **Secondary category:** Lifestyle
- **Copyright:** 2026 Kathryn Swint
- **Privacy policy URL:** https://tali-sms.katswint.workers.dev/privacy
- **Support URL:** https://tali-sms.katswint.workers.dev/support
- **Marketing URL:** https://katswint.com
- **Keywords:** activity log,habit tracker,journal,timestamp,history,patterns,wellness,notes
- **Promotional text:** Record what happened and when—from the app, Messages, Siri, or Shortcuts—then see a factual timeline and activity chart.

Deploy and verify the dedicated support page before submission. It provides a visible contact path
without asking users to disclose private habit data.

## Description

Tali is an emotionally neutral activity log.

Record an activity in seconds, then see what happened and when. Tali shows timestamps, history, and
a four-month activity chart without streaks, praise, shame, goals, or reminders to do more.

Use your own words. Track yoga, medication, weed, physical therapy, calling a friend, or anything
else that matters to you. Tali does not label an activity as good or bad.

Features:

- Log from the iPhone app, Messages, Siri, or Shortcuts
- Backdate entries such as “yoga yesterday at 7pm”
- Add optional notes
- View a factual timeline and binary activity chart
- Hide elapsed time everywhere or for selected activities
- Archive activities without losing their history
- Export all local and connected account data
- Use the core app without creating an account

Optional SMS logging requires connecting a phone number. Carrier message and data rates may apply.
Tali does not sell data, show ads, or use activity history for behavior profiling.

## App Review notes

Tali's core logging, history, chart, archive, and export features work without an account.

Sign in with Apple is used only to connect the optional SMS service and keep different users' server
records separate. The reviewer does not need to sign in to evaluate the core app.

The Messages extension appears in the Messages app drawer as Tali. It writes to the same App Group
store as the main app.

Public SMS onboarding must remain closed until the registered A2P campaign is approved. If the
campaign is not approved when this build is submitted, explain that the optional SMS service is not
available to reviewers and do not advertise it as available in screenshots or promotional text.

## App Privacy answers

Select **Yes, we collect data from this app** because the optional connected service transmits data
off-device. Declare the following:

| Data type | Linked to user | Tracking | Purpose |
| --- | --- | --- | --- |
| Contact Info → Phone Number | Yes | No | App Functionality |
| User Content → Emails or Text Messages | Yes | No | App Functionality |
| User Content → Other User Content | Yes | No | App Functionality |
| Identifiers → User ID | Yes | No | App Functionality |
| Identifiers → Device ID | Yes | No | App Functionality |
Tali does not request Apple name or email scopes. It does not collect location, contacts, purchases,
health records, usage analytics, advertising data, or crash analytics. It does not track users
across apps or websites. These answers must stay aligned with `App/PrivacyInfo.xcprivacy` and the
deployed privacy policy.

## Export compliance

Tali uses Apple's networking, Sign in with Apple, Keychain, and CryptoKit hashing facilities. The
checked-in Info.plist declares `ITSAppUsesNonExemptEncryption` as false because the app does not
implement non-exempt encryption. Confirm the answers in App Store Connect for the final binary;
Apple evaluates export compliance on the submitted app and availability.

## Age rating and content

Complete Apple's current age-rating questionnaire in App Store Connect. Tali supplies no
age-gated, medical, drug, or other mature content; users choose their own private activity names.
Do not classify private user-entered words as developer-provided content without reviewing the
question's exact wording.

## Screenshots

Use the isolated `-tali-demo` store so no personal records appear. Capture:

1. Dashboard with the most recent entry, binary activity chart, and several neutral activities.
2. Habit detail with the activity chart and timestamp history.
3. Fast logging with a backdated phrase and optional note.
4. The elapsed-time visibility controls.
5. Export and privacy/account controls.

Provide current required iPhone sizes in App Store Connect. Do not stretch a screenshot or place it
inside a device frame that obscures the actual interface.

The checked-in set is 1206 × 2622, an accepted 6.3-inch iPhone screenshot size. App Store Connect
may also require a separate 6.9-inch slot; capture that size from an appropriate simulator rather
than resizing this set.

## Accessibility claims

Only select an App Store accessibility feature after validating the release build against Apple's
current criteria. Current evidence supports:

- **Larger Text:** the core journeys pass at the largest accessibility Dynamic Type size.
- **Dark Interface:** the dashboard, detail, logging, settings, export, and empty states have been
  visually checked in Dark Mode.
- **Differentiate Without Color Alone:** activity cells expose dates and logged/not-logged state to
  accessibility APIs, and a selected cell has a text caption.

Do not claim VoiceOver support until focus order and control labels pass on a physical device or in
Accessibility Inspector. Recheck sufficient contrast with a contrast-measurement tool before
claiming it, even though the increased-contrast visual pass is clean.

## Final manual checks

- Verify the privacy and support URLs are public and accurate.
- Reconcile this privacy table with the final production server logs and providers.
- Confirm the App Group, Sign in with Apple, Messages extension, and privacy manifest are present in
  an Archive, not only a Debug build.
- Run the physical-device and TestFlight sections in `docs/release-checklist.md`.
- Provide a working review path for every feature described as available.
