# Tali product and engineering case study

## The problem

Habit trackers usually make the user open an app, find an item, and tap through a logging flow. That interaction is disproportionately expensive for an action that should take seconds. Tali tests a lower-friction behavior: text the name of something you did, then let the product maintain the timestamp, elapsed time, history, and activity chart.

## Product thesis

The fastest habit log is a message the user already knows how to send. Tali therefore treats its native app as the place to configure and understand habits, while Messages, SMS, Siri, and Shortcuts are capture surfaces.

The first release is intentionally a single-owner beta. That constraint made it possible to validate the interaction before investing in accounts, phone verification, and multi-tenant data isolation.

## Experience

- Text `yoga` to record the current time.
- Text `yoga yesterday at 7pm` to backdate an entry.
- Add a note with `yoga -- hips felt better`.
- Ask `since yoga`, `history yoga`, or `habits`.
- Use `undo` without destructively deleting the underlying event.
- Review a four-month calendar-style entry-count chart in the app.
- Edit names and aliases or archive and restore a habit without losing history.
- Export entries to CSV or the complete habit and entry archive to JSON.

## Architecture

```text
Messages extension ─┐
iPhone app ─────────┼─> SwiftData/App Group ─┐
Siri + Shortcuts ───┘                        ├─> bidirectional snapshot sync
                                            │
SMS -> Twilio -> Cloudflare Worker -> D1 ───┘
```

The native app and Messages extension share a SwiftData store through an App Group. The Cloudflare Worker validates Twilio signatures, restricts inbound messages to the enrolled phone number, executes deterministic commands, stores append-only events in D1, and exposes a bearer-protected sync endpoint.

## Important decisions

### Observation without judgment

Many trackers assume that more activity is better: streaks reward repetition, missed-day states imply failure, and reminders recommend a cadence. That model breaks down for activities whose desired frequency is personal, contextual, or intentionally undecided. Tali records user-defined events without assigning directionality. It has no goals, streaks, missed-day states, praise, warnings, or recommended frequency. The interface uses neutral entry and timeline language, quantitative chart labels, and informational rather than success iconography. New installs begin empty instead of suggesting which activities a person ought to track.

### Deterministic parsing instead of an LLM

Habit commands contain personal data and have a small, testable grammar. A deterministic parser is faster, private, inexpensive, and produces predictable behavior for dates and aliases.

### Append-only event history

Undo marks an event as voided. This retains provenance, makes sync conflicts easier to reason about, and avoids destructive history changes.

### Local-first behavior

The app and Messages extension remain useful without the SMS service. Network failure affects synchronization, not local capture or history.

### Duplicate-safe identity reconciliation

Early builds seeded defaults before downloading server data, allowing the same habit to exist under two UUIDs. Current clients consolidate equal normalized names locally, while the Worker canonicalizes server rows and remaps their events. Both layers preserve aliases and timestamps, and regression tests cover the failure mode.

### Compliance as product behavior

Tali publishes its SMS enrollment, privacy, and terms pages and implements the exact `START`, `HELP`, and `STOP` families declared in its A2P campaign. Carrier-level Advanced Opt-Out remains the source of truth.

## Reliability and testing

- Swift parser and engine tests cover date parsing, aliases, logging, undo, editing, archiving, and duplicate consolidation.
- Worker tests cover commands, Twilio signatures, public compliance pages, and opt-in/help/opt-out copy.
- A local Worker/D1 integration test exercises sync, deliberate duplicate creation, event remapping, webhook idempotency, SMS logging, and round-trip retrieval.
- Signed simulator builds verify App Group access rather than relying on unsigned builds that cannot open the shared SwiftData store.

## What I would build next

The validated single-owner interaction can become a multi-user product by adding Sign in with Apple, per-user D1 ownership, phone-number verification, revocable device sessions, and observability around webhook and sync failures. Product work would then focus on onboarding, user-selected habit presentation, widgets, and measured retention rather than expanding the command grammar prematurely.
