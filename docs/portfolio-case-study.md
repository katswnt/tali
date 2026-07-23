# Tali product and engineering case study

## The problem

Habit trackers usually make the user open an app, find an item, and tap through a logging flow. That interaction is disproportionately expensive for an action that should take seconds.

They also tend to assume that tracking implies a desired direction: build a longer streak, do something more often, or abstain for longer. That framing becomes actively unhelpful for activities whose ideal frequency is personal, contextual, or undecided.

Tali explores both problems at once: send a message to record what happened, then inspect a factual history without being told what the history should mean.

## Product thesis

The fastest habit log is a message the user already knows how to send.

Tali treats the native app as the place to configure and understand data, while the iPhone app, Messages, SMS, Siri, and Shortcuts are capture surfaces. The product remains useful locally without an account; identity exists to connect optional SMS and synchronization, not to gate the core experience.

The first release was deliberately a single-owner beta. After validating the interaction, the backend was expanded to Sign in with Apple sessions, one-time phone pairing, and user-scoped D1 data. Public onboarding remains closed until the carrier registration and remaining production safeguards match that multi-user architecture.

## Experience

- Type `yoga` to record the current time.
- Type `yoga yesterday at 7pm` to backdate an entry.
- Type `weed sunday 2pm` without Tali treating the activity as a goal or abstinence target.
- Add a note with `yoga -- hips felt better`.
- Ask `since yoga`, `history yoga`, or `habits`.
- Use `undo` without destructively deleting the underlying event.
- Review a four-month binary activity chart and inspect a date for its exact count.
- Hide elapsed time globally or for one habit.
- Edit names and aliases or archive and restore a habit without losing history.
- Export entries to CSV or the complete habit and entry archive to JSON.

## Architecture

```text
Messages extension ─┐
iPhone app ─────────┼─> SwiftData/App Group ─┐
Siri + Shortcuts ───┘                        │
                                            ├─> bidirectional snapshot sync
Sign in with Apple -> device session ───────┤
                                            │
SMS -> Twilio -> Cloudflare Worker -> D1 ───┘
```

The native app and Messages extension share a SwiftData store through an App Group. The Cloudflare Worker validates Twilio signatures, resolves the sender to a paired user, executes deterministic commands, stores append-only events in D1, and exposes an authenticated sync endpoint.

Each user receives a random device session after the Worker verifies an Apple identity token and nonce. Only the session hash is stored server-side. A short-lived, one-time code connects an SMS phone number to that user, and every habit or event query includes the authenticated user ID.

## Important decisions

### Observation without judgment

Many trackers assume that more activity is better: streaks reward repetition, missed-day states imply failure, and reminders recommend a cadence. That model breaks down for activities whose desired frequency is personal, contextual, or intentionally undecided.

Tali has no goals, streaks, missed-day states, praise, warnings, or recommended frequency. The activity chart is binary rather than intensity-coded. Elapsed time is optional globally and per habit. New installs begin empty instead of suggesting which activities a person ought to track.

### Deterministic parsing instead of an LLM

Habit commands contain personal data and have a small, testable grammar. A deterministic parser is faster, private, inexpensive, and predictable for dates and aliases. The accepted cost is that Tali supports an explicit grammar rather than pretending to understand every phrase.

### Local-first behavior

The app, Messages extension, Siri, and Shortcuts remain useful without the SMS service. Network failure affects synchronization, not local capture or history. The cost is that SMS entries appear after foreground or manual synchronization instead of real-time push.

### Append-only event history

Undo marks an event as voided. This retains provenance, makes synchronization easier to reason about, and ensures exports can represent the actual history of corrections.

### Duplicate-safe identity reconciliation

Early builds seeded defaults before downloading server data, allowing the same habit to exist under different UUIDs. Current clients consolidate equal normalized names locally, while the Worker canonicalizes server rows and remaps their events. Both layers preserve aliases and timestamps, and regression tests cover the failure mode.

### Binary activity instead of progress intensity

A conventional contribution graph uses stronger color to celebrate higher volume. Tali uses one recorded state regardless of count so the visualization does not claim that more activity is better. Tapping a cell reveals the exact count when that fact is useful.

### Compliance as product behavior

Tali publishes SMS enrollment, privacy, and terms pages and implements the same opt-in, help, and opt-out families declared during A2P registration. Twilio Advanced Opt-Out remains authoritative so carrier suppression and product behavior cannot silently diverge.

## Reliability and testing

- Swift parser and engine tests cover date parsing, aliases, logging, undo, editing, archiving, export, migration, visibility preferences, and duplicate consolidation.
- Worker tests cover commands, timestamp validation, Twilio signatures, XML escaping, pairing-code parsing, public disclosures, and compliance copy.
- A local Worker/D1 integration test exercises sync, two-user isolation, deliberate duplicate creation, event remapping, webhook idempotency, SMS logging, and legacy-account migration.
- Signed simulator builds verify App Group behavior rather than treating an unsigned fallback store as equivalent.

## What changed because of real failures

- A SwiftData startup crash led to explicit versioned schema construction and a recoverable store-opening state.
- An early SMS path exposed how easily a webhook can acknowledge receipt while failing to deliver a reply; Twilio logs and status codes became part of the release checklist.
- Duplicate habits created by early sync behavior led to reconciliation on both the client and Worker instead of a one-off cleanup.
- A historical phrase such as `weed sunday 2pm` initially logged at the current time; date parsing gained regression coverage for most-recent weekdays.
- The original single-owner secret evolved into Sign in with Apple sessions and phone pairing before multi-user invitations.
- A2P rejection made the relationship between product copy, public disclosures, approved use case, and actual traffic an explicit launch gate.

## Current limits

The current synchronization model is intentionally pragmatic: UUID identity, `updatedAt` comparison, and normalized-name repair. It is appropriate for the personal alpha but still depends on client clocks and does not provide server revisions or field-level conflict resolution.

The multi-user backend still needs account deletion, remote-export verification, rate limits, device/session management, privacy-preserving monitoring, and a defined retention policy before public use. The carrier campaign must also be approved for the actual product flow.

## Next product questions

- Can Tali measure whether messaging materially reduces logging friction without collecting sensitive behavior data?
- Which users benefit from elapsed time, and when does the metric create an unwanted implication?
- Should optional reflection tools exist without weakening the neutral default?
- What is the smallest synchronization protocol that remains understandable as multi-device use grows?
- Which operational signals can diagnose failures without storing habit names or message contents?
