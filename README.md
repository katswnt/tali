# Tali

[![CI](https://github.com/katswnt/tali/actions/workflows/ci.yml/badge.svg)](https://github.com/katswnt/tali/actions/workflows/ci.yml)

**An emotionally neutral activity log you can update by sending a message.**

Tali records what happened and when. It does not decide whether an activity is good or bad, turn repetition into a streak, or recommend what the user should do next.

The working personal alpha includes a native iPhone app, Messages extension, Siri and Shortcuts
actions, and an optional SMS service built with Twilio, Cloudflare Workers, and D1. It is a portfolio
project and active product experiment, not an App Store release. Public SMS onboarding remains
closed while the A2P campaign is corrected and approved.

## Status at a glance

This table separates repository evidence from work that still requires a real platform or user.

| Area | What is verified | What is not yet proven |
| --- | --- | --- |
| Product model | Neutrality rules appear in copy, settings, elapsed-time visibility, binary visualization, and tests | Whether the model helps a broader group beyond the founder problem |
| Native core | Parser, domain engine, migration, export, reconciliation, and deterministic UI smoke tests; reproducible app and extension build | Full physical-iPhone, VoiceOver, Siri, Messages, and TestFlight matrix |
| Multi-user backend | Managed Worker/D1 integration exercises two-user isolation, account lifecycle, rotating sessions, rate limits, retention, SMS, and revisioned sync | Independent security review, completed staging soak, backup/restore drill, and production load behavior |
| SMS | Signed webhook, idempotency, compliance copy, and carrier status paths are implemented and tested locally | Approved A2P campaign and a clean production carrier round trip |
| Distribution | App Store metadata, privacy manifest, demo store, and release checklist exist | Archive validation, TestFlight feedback, and App Store review |

The strongest claim in this repository is not “this has shipped at scale.” It is that one product
thesis has been translated into consistent interaction rules, data semantics, security boundaries,
and reproducible tests. The remaining launch work is listed rather than implied away.

## Product tour

<p align="center">
  <img src="docs/images/tali-dashboard.png" width="360" alt="Tali dashboard showing the most recent entry, binary activity heatmap, and habit list">
  <img src="docs/images/tali-habit-detail.png" width="360" alt="Tali habit detail showing optional elapsed time, a binary activity heatmap, and timestamp history">
</p>

These screens use the repository’s isolated, in-memory demo data. They do not contain personal history or contact the SMS service.

## Why Tali exists

Most habit trackers make two assumptions:

1. Logging should happen inside the tracker.
2. More repetition is progress.

The first adds friction to an action that should take seconds. The second breaks down for activities whose desired frequency is personal, contextual, or intentionally undecided.

Tali tests a different model: capture through interfaces the user already knows, then provide a factual record without prescribing a goal.

```text
yoga
yoga yesterday at 7pm
weed sunday 2pm
physical therapy -- shoulder felt better
```

The same deterministic grammar works in the app, Messages, and SMS. Tali stores the timestamp, keeps the history, and updates a binary GitHub-style activity chart.

## Product principles

- **Observe without judging.** Show timestamps, elapsed time, history, counts, and notes without praise, shame, warnings, or recommended frequency.
- **Let the user define the data.** New installs start empty; Tali does not suggest which activities a person should track.
- **Make potentially loaded metrics optional.** Elapsed time can be hidden globally or for one habit.
- **Do not encode “more is better.”** Activity cells indicate whether an entry exists; exact counts appear only when a date is inspected.
- **Preserve the user’s language.** Tali does not classify or euphemize habit names.
- **Keep correction factual.** Undo voids an entry without pretending it never existed.

The complete copy and behavior test is documented in [Tali product principles](docs/product-principles.md).

## Experience

- Log from the iPhone app, Messages extension, Siri, Shortcuts, or SMS.
- Backdate an entry with phrases such as `yesterday at 7pm` or `sunday 2pm`.
- Attach an optional note after `--`.
- Ask `since yoga`, `history yoga`, `habits`, or `undo`.
- Define aliases such as `pt` for `Physical therapy`.
- Inspect four months of binary activity and tap any date for its exact count.
- Hide elapsed time globally or for an individual habit.
- Archive and restore habits without losing history.
- Save Tali as a contact through Apple’s prefilled confirmation sheet; Tali never silently edits contacts.
- Export active, archived, and voided data as CSV or JSON.

## Architecture

```text
Messages extension ─┐
iPhone app ─────────┼─> SwiftData in an App Group ─┐
Siri + Shortcuts ───┘                              │
                                                  ├─> revision + UUID reconciliation
Sign in with Apple ─> rotating device session ───┤
SMS -> Twilio -> signed Worker webhook -> D1 ─────┘
```

The native surfaces share a static `HabitCore` framework and one SwiftData schema. Local capture works without an account or network connection.

The optional SMS path verifies Twilio signatures, resolves the sender to an authenticated user,
scopes every database operation to that user, and records each Twilio `MessageSid` once. Sign in
with Apple access and rotating refresh tokens are stored in Keychain on-device; D1 stores only
their hashes. Server revisions expose stale snapshots, and mutation UUIDs make sync retries
idempotent.

See [Security and sync](docs/security-and-sync.md) for the trust boundaries, conflict model, accepted alpha constraints, and production gates.

## Decisions, costs, and change conditions

A tradeoff is only useful if it includes the condition that would make it obsolete.

| Decision | Why now | Accepted cost | Trigger to revisit |
| --- | --- | --- | --- |
| Deterministic parser | Private, fast, predictable, and testable for a small command domain | Explicit grammar rather than arbitrary language | Opt-in research shows common intent cannot fit the grammar |
| Local-first, account optional | Identity or network failure never blocks capture | SMS changes require foreground or manual sync | Multi-device expectations outweigh account-free use |
| Append-only events and archive | Correction and sync retain provenance; actions are reversible | Queries need explicit active/voided semantics | Users demonstrate a need for per-record permanent erasure |
| Binary heatmap | Shows occurrence without rewarding volume | Repeated entries require date inspection | A validated analytical question needs count comparison |
| Revisioned snapshot sync | Small enough to inspect; stale state and retries are explicit | Full transfer, timestamp field resolution, no field merge | Conflict reports or measured size/latency budgets are reached |
| Sign in with Apple and phone pairing | Minimal identity collection with no passwords | Apple coupling and refresh-session lifecycle complexity | Non-Apple clients or recovery failures are validated needs |
| Confirmed contact creation | Prefilled native sheet is familiar and avoids broad Contacts access | One intentional user tap; no silent sender branding | Research shows the step is confusing or an opt-in vCard is preferable |
| No behavioral analytics | Sensitive history does not justify passive collection in a personal alpha | No passive funnel or retention evidence | External testing begins with a written, opt-in data budget |
| Native platform controls | Familiar behavior and accessibility come largely for free | Quieter visual identity | Testing identifies a comprehension problem custom UI solves |

The full [decision register](docs/decision-register.md) documents alternatives, costs, and explicit
revisit triggers for product, platform, data, backend, and development-process choices.

## Evidence map

| Capability | Repository evidence |
| --- | --- |
| Product judgment | [Product principles](docs/product-principles.md), elapsed-time controls, binary heatmap, empty-state behavior, and the [case study](docs/portfolio-case-study.md) |
| Domain modeling | [`HabitModels`](Shared/HabitModels.swift), append-only event behavior in [`HabitEngine`](Shared/HabitEngine.swift), and Swift tests |
| Native iOS breadth | SwiftUI app, App Group Messages extension, App Intents, Keychain, SwiftData migration, privacy manifest, and generated Xcode project |
| Backend and security | User-scoped D1 migrations, cryptographic Apple JWT verification, rotating hashed sessions with replay-family revocation, one-time pairing, signed webhooks, retention, [trust-boundary documentation](docs/security-and-sync.md), and a candid [security self-review](docs/security-review.md) |
| Distributed-data reasoning | Server revisions, mutation idempotency, UUID reconciliation, normalized-name duplicate repair, idempotent Twilio receipts, managed integration tests, and documented last-write-wins limits |
| Quality discipline | CI, 65 domain and Worker tests, three deterministic UI journeys, a managed Worker/D1 integration, isolated demo data, and a one-command release check |
| Operational judgment | Separate staging database/Worker, explicit production confirmation, backup and recovery runbook, rollback policy, privacy-safe observability, and load thresholds |
| Product learning | A consent-first five-person [research protocol](docs/research-plan.md) and [field kit](docs/research-kit.md) with falsifiable comprehension, neutrality, trust, and export gates |
| Learning from failure | SwiftData startup recovery, weekday-parser regression, duplicate reconciliation, A2P launch gating, and webhook delivery checks in the [case study](docs/portfolio-case-study.md) |

## Reliability and tests

- **20 Swift tests** cover parsing, aliases, backdating, logging, undo, archive/restore, export, time-since visibility, schema migration, and duplicate consolidation.
- **45 Worker tests** cover the shared SMS grammar, bounded payload envelopes, Apple-token cryptography and claims, time zones, compliance pages and copy, Twilio signatures, XML escaping, pairing-code parsing, rotating-session replay, hashed rate limits, retention, and privacy-safe logging.
- **Three UI smoke journeys** cover first launch and logging, backdated detail/history, and elapsed-time visibility using an isolated in-memory launch mode.
- A managed local Worker/D1 integration test exercises revision conflicts and retry idempotency, rotating sessions, round-trip sync, two-user isolation, deliberate duplicate creation, event remapping, webhook idempotency, SMS logging, and legacy-account migration.
- The Xcode scheme gathers coverage for the shared framework.

```bash
swift test --scratch-path .build-spm

cd Server
npm ci
npm run test:release
```

Physical-device, App Group, Messages, Siri, Apple’s real authorization sheet, contact confirmation,
and carrier behavior remain explicit release-checklist items because simulator and unit tests
cannot prove those integrations.

The repository-level release check regenerates the Xcode project, runs every Swift and Worker test,
boots an isolated local Worker/D1 integration environment, triggers retention, and builds the app
plus Messages extension:

```bash
./scripts/release-check.sh
```

## Known limitations and next decisions

These are weaknesses, not disguised roadmap features:

1. **There is no distribution proof yet.** The next milestone is a signed physical-device pass,
   TestFlight build, and approved carrier path—not another broad feature.
2. **The product thesis is founder-led.** Tali has a defined five-person, consent-first research
   protocol but no completed external cohort, diary study, or retention signal. Evidence must come
   before claims; sensitive behavioral analytics remain out of scope.
3. **Revisioned snapshot sync is intentionally modest.** Revisions expose stale work and mutation
   IDs make retries safe, but histories still transfer in full, entity fields use client
   timestamps, and revision reservation is not one transaction with reconciliation. Deltas and a
   transactional mutation boundary should be evaluated against measured conflicts and payloads.
4. **Operational controls exist; operational evidence does not yet.** Staging/production isolation,
   explicit production deploy confirmation, backups, rollback guidance, and load budgets are
   implemented. A recorded staging soak, load run, and production recovery drill remain required.
5. **Automated tests stop at important platform boundaries.** Domain, Worker, integration, and UI
   smoke coverage are strong; physical App Group behavior, VoiceOver, Siri, real Apple
   authorization, contact saving, carrier delivery, and independent security review remain manual
   gates.
6. **The platform and identity strategy are narrow.** The app requires iOS 18+, and connected
   accounts use Apple identity. That is appropriate to learn from the native alpha, not a claim of
   universal reach.

The next technical work should remove launch risk or gather product evidence. New surface area has
lower priority until those two questions are answered.

## Development approach and ownership

Tali was built through an AI-assisted, human-directed workflow. Coding agents accelerated
implementation, debugging, tests, and documentation. Kathryn remained accountable for the problem
framing, emotional-neutrality rules, acceptance criteria, architecture tradeoffs, hands-on platform
integration, review, and release decisions.

That distinction is important: a polished diff is not proof of understanding. Agent output was not
treated as evidence until behavior had an automated test, a reproducible check, or an explicit
manual gate. The repository deliberately preserves failures, constraints, and unshipped work so the
portfolio demonstrates judgment and verification rather than unaided typing speed.

Useful follow-up questions include:

- Which specific UI decisions came from the neutrality principle, and what was rejected?
- Why is a deterministic parser a product choice rather than only a technical shortcut?
- What is the source of truth, and how do duplicate identities and concurrent edits resolve?
- How is one SMS sender prevented from reading or changing another user's data?
- Which production failure changed the architecture most?
- How would sync, operations, and cost change at 100,000 active users?
- How would product-market evidence be gathered without casually collecting sensitive histories?
- Which work came from coding agents, and how was it reviewed and verified?
- What would be cut from the current scope before a public beta?

## Project structure

```text
Tali
├── App/                 SwiftUI app, heatmap, account connection, and App Intents
├── MessagesExtension/   Compact Messages logger and optional conversation receipt
├── Shared/              Models, persistence, parser, engine, sync, and export
├── Server/              Worker routes, D1 migrations, Twilio handling, auth, and tests
├── Tests/               Swift Testing coverage for the shared domain layer
├── docs/                Product principles, case study, tradeoffs, and release gates
└── project.yml          Reproducible XcodeGen project definition
```

`HabitCore` is a static framework linked by the app, extension, and test target. Keeping the models in one module gives SwiftData a consistent schema name in both native processes.

## Open and run

Requirements:

- Xcode with the iOS 18 or later SDK
- XcodeGen
- An Apple development team for App Groups and Sign in with Apple

```bash
brew install xcodegen
xcodegen generate
open Tali.xcodeproj
```

In Xcode:

1. Select the `Tali` and `TaliMessages` targets.
2. Choose your development team.
3. Replace the bundle IDs and `group.com.kathrynswint.Tali` App Group if you are using your own Apple account.
4. Run the `Tali` scheme on an iPhone or simulator.

The extension can launch in Simulator, but a physical iPhone is the meaningful end-to-end test for Messages and App Group provisioning.

### Seeded portfolio demo

Debug builds support a repeatable in-memory demo that never reads the normal store or synchronizes with the Worker:

```bash
xcrun simctl launch --terminate-running-process booted com.kathrynswint.Tali -tali-demo
```

The demo records a small mix of neutral and potentially loaded activities so the interface can be reviewed without publishing personal history. Closing and relaunching without `-tali-demo` returns to the normal store.

## Optional SMS service

The SMS adapter provides the `text “yoga” -> logged` interaction outside the native Messages extension.

It requires the operator’s own:

- Twilio account, SMS-capable number, Messaging Service, and approved A2P campaign
- Cloudflare account, Worker, and D1 database
- Apple App ID configured for Sign in with Apple

The checked-in Worker configuration contains Tali’s separate staging and production deployment
identifiers and must be replaced for a fork. Secrets remain environment-specific in Wrangler or
local `.dev.vars`; they are not committed. The deploy script refuses an implicit production target
and requires an explicit production confirmation.

See [Server/README.md](Server/README.md) for setup and
[the operations runbook](docs/operations-runbook.md) for staging, backup, load, rollback, and
recovery.

## Launch gates

The complete, intentionally manual launch checklist lives in
[docs/release-checklist.md](docs/release-checklist.md). Public claims should not change from
“personal alpha” until the physical-device, TestFlight, carrier, security-review, and production
recovery gates have evidence.

## License

This repository is public for portfolio review. No license for reuse or redistribution is currently granted; see [LICENSE](LICENSE).
