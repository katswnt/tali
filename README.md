# Tali

Tali is a local-first habit log with native Messages, SMS, Shortcuts, and iPhone interfaces. Tell Tali what you did, ask how long it has been, or inspect a GitHub-style activity history in the companion app.

## What works

- Log from the app or Messages extension
- Type `yoga`, `I did yoga`, or `yoga yesterday at 7pm`
- Attach an optional note with `--`, as in `yoga -- hips felt better`
- Ask `since yoga`, `history yoga`, `habits`, or `undo`
- Resolve custom aliases such as `pt` for Physical therapy
- View time since the most recent entry, per-habit history, and a four-month activity heatmap
- Edit habit names and aliases, archive habits without losing history, and restore them later
- Add an optional interactive receipt to the current Messages conversation
- Invoke the shared logging action through Siri and Shortcuts with App Intents
- Share one SwiftData store between the app and extension through an App Group
- Text a Twilio number and sync SMS entries through a Cloudflare Worker and D1
- Reconcile same-name habits across fresh installs and devices without dropping entries
- Handle branded SMS opt-in, help, and opt-out keywords declared during A2P registration
- Export all habit and entry data as spreadsheet-ready CSV or a portable JSON archive
- Isolate each server account’s habits and entries with Sign in with Apple sessions
- Pair a texting phone number with a short-lived, one-time SMS code

## Project structure

```text
Tali
├── App/                 SwiftUI dashboard, forms, heatmap, and App Intent
├── MessagesExtension/   Messages controller and compact SwiftUI logger
├── Shared/              Models, persistence, parser, engine, and formatting
├── Server/              Twilio webhook, Cloudflare Worker, D1 schema, and tests
├── Tests/               Swift Testing coverage for parsing and event behavior
└── project.yml          Reproducible XcodeGen project definition
```

`HabitCore` is a static framework linked by the app, extension, and test target. Keeping the models in one module also gives SwiftData a consistent schema name in both processes.

## Open and run

1. Install XcodeGen if needed: `brew install xcodegen`.
2. From this directory, run `xcodegen generate`.
3. Open `Tali.xcodeproj` in Xcode.
4. Select the `Tali` target, choose your Apple development team, and let Xcode register the App Group and Sign in with Apple capability.
5. Confirm `group.com.kathrynswint.Tali` exists for both the app and `TaliMessages` extension targets.
6. Run on an iPhone. Open Messages, tap **+**, choose **More**, then enable or select Tali.

The extension can run in the simulator, but a physical iPhone is the meaningful end-to-end test for Messages and App Group provisioning.

Run the shared engine and parser tests independently of the simulator with `swift test --scratch-path .build-spm`.

## Text Tali over SMS

The optional SMS service provides the zero-friction `text “yoga” → logged` interaction. It uses a Twilio phone number, a Cloudflare Worker, and D1 storage. Each user signs in with Apple and pairs their phone with a one-time code before the Worker routes messages to their isolated account. The native app then merges app and SMS events by UUID and update timestamp.

The production A2P campaign is not yet verified. Multi-user invitations must remain closed until the registered campaign description, opt-in flow, public disclosures, and approved traffic match the multi-user product.

See [Server/README.md](Server/README.md) for local testing, deployment, Twilio webhook configuration, and app pairing.

## Design decisions

- Tali is observational, not motivational. It records what the user reports without goals, streaks, reminders, praise, warnings, or recommended frequency.
- Every habit is treated as user-defined data. Tali does not classify activities as healthy, unhealthy, productive, or harmful.
- New installs start empty instead of suggesting aspirational default habits.
- Events are append-only. Undo marks an event as voided instead of deleting it.
- Habits are archived instead of deleted so their events remain available and restorable.
- Sync uses UUIDs for normal updates and normalized habit names to repair duplicate identities created by earlier clients.
- Timestamps are stored as absolute `Date` values and grouped by the device calendar for the heatmap.
- The parser is deterministic and local. It never sends message content to an external service.
- Receipt insertion is explicit. Logging does not automatically add noise to a conversation.
- The interface uses one semantic accent color, Dynamic Type, native controls, and accessible labels.
- Exports include active and archived habits plus active and voided entries; private connection credentials are never included.

## Next milestones

1. Secure carrier approval and register the multi-user SMS onboarding flow before inviting users.
2. Add account deletion and remote-data export before App Store distribution.
3. Add user-selected habit symbols and colors.
4. Add interactive widgets and a richer `TimeSinceHabitIntent`.
5. Complete physical-device, VoiceOver, Dynamic Type, and TestFlight release testing.
