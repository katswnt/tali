# Tali decision register

This register explains choices that materially shape the product or architecture. It is not a list
of claims that every decision is permanent. Each entry names the cost Tali accepts now and the
evidence or change that should trigger another decision.

## Product decisions

### D-001 — Emotional neutrality is the default

**Status:** Accepted

**Decision:** Tali records user-defined activity without goals, streaks, praise, shame, warnings, or
recommended frequency. This applies to every activity rather than only categories judged to be
sensitive.

**Why:** A tracker cannot infer whether more, less, or abstinence is desirable from a habit name.
The same activity can have different meanings for different people or at different times.

**Cost:** Tali gives up familiar engagement mechanics and cannot promise behavior change as its
primary outcome.

**Revisit when:** User research identifies an optional reflection or goal tool that people want.
Any such feature must be explicitly enabled per habit and leave the neutral default unchanged.

### D-002 — Elapsed time is optional globally and per habit

**Status:** Accepted

**Decision:** Users can hide “time since” everywhere or override that setting for one habit.

**Why:** A large elapsed-time number can imply abstinence or a target cadence even when the copy is
technically factual.

**Cost:** The dashboard has an additional preference model and two levels of configuration.

**Revisit when:** Usability testing shows the override hierarchy is confusing. The metric itself
should not become mandatory to simplify the settings.

### D-003 — Activity visualization is binary

**Status:** Accepted

**Decision:** A heatmap cell represents whether at least one entry exists, not a stronger reward
color for higher counts. Exact counts remain available when a date is inspected.

**Why:** Conventional contribution graphs visually equate volume with progress. Tali needs to show
patterns without claiming that more activity is better.

**Cost:** Repeated entries on one date are not visible at a glance.

**Revisit when:** Users need a comparison view for a concrete question. A future count view should
be an explicit analytical mode, not the default visual hierarchy.

### D-004 — New accounts begin empty

**Status:** Accepted

**Decision:** Tali does not seed suggested habits in a real user store.

**Why:** Suggestions encode assumptions about what a person ought to monitor. They can also expose
loaded examples before the user has established trust.

**Cost:** The empty state must teach the product without demonstrating a populated chart.

**Revisit when:** Onboarding research identifies examples that teach syntax without implying what
to track. Portfolio screenshots use an isolated in-memory demo rather than real onboarding data.

## Interaction and platform decisions

### D-005 — Deterministic parsing instead of an LLM

**Status:** Accepted for the current grammar

**Decision:** App, Messages, and SMS commands share a deterministic parser for logging, notes,
aliases, queries, and supported date phrases.

**Why:** Commands contain personal data but occupy a small domain. A local parser is fast,
inexpensive, private, testable, and predictable enough to explain when it cannot parse something.

**Cost:** Tali supports an explicit grammar rather than arbitrary natural language.

**Revisit when:** Command failures collected through privacy-preserving, opt-in research show that
the grammar cannot cover common intent. Compare any broader parser against the deterministic suite
for latency, privacy, cost, ambiguity, and failure recovery.

### D-006 — Native iOS first, with multiple capture surfaces

**Status:** Accepted for the alpha

**Decision:** The iPhone app is the place to inspect and configure data. The main app, Messages
extension, Siri, Shortcuts, and optional SMS service are capture surfaces over one domain model.

**Why:** The product thesis is about reducing capture friction in interfaces people already use.
Native frameworks also provide App Group storage, App Intents, Keychain, Dynamic Type, and
accessibility behavior without a cross-platform compatibility layer.

**Cost:** There is no Android or web client, and Apple provisioning is part of development.
Apple does not expose a general-purpose iMessage bot API, so texting outside the extension uses SMS.

**Revisit when:** Validated demand comes from people outside the Apple ecosystem or a read-only web
view solves a demonstrated access need.

### D-007 — Native controls over a highly branded component system

**Status:** Accepted

**Decision:** Tali uses restrained SwiftUI hierarchy and platform controls rather than custom
interaction primitives.

**Why:** Familiar behavior, Dynamic Type, VoiceOver, reduced-motion support, and implementation
speed matter more than decorative novelty for this product.

**Cost:** The interface may appear visually quieter than a heavily branded consumer app.

**Revisit when:** Usability testing identifies hierarchy or comprehension problems. Brand work
should not replace native semantics without an accessibility reason.

## Data and backend decisions

### D-008 — Local-first capture; accounts are optional

**Status:** Accepted

**Decision:** SwiftData in an App Group is the native source of truth. Logging, history, export,
Messages, Siri, and Shortcuts work without an account or network connection. Sign in exists to
connect server sync and SMS.

**Why:** Network or identity failure should not block the core action.

**Cost:** SMS changes arrive after foreground or manual synchronization rather than through
real-time push. Deleting the remote account intentionally leaves the local-only store intact.

**Revisit when:** Multi-device expectations exceed the value of an account-optional product, or
users misunderstand local-versus-server deletion. The deletion UI must resolve that comprehension
problem before changing data ownership.

### D-009 — Events are append-only; habits are archived

**Status:** Accepted

**Decision:** Undo marks an event voided, and removing a habit from the dashboard archives it.
Complete exports include active, archived, and voided records.

**Why:** Provenance makes correction, synchronization, and data portability easier to reason about.
Reversible product actions reduce accidental data loss.

**Cost:** Every ordinary query must consistently exclude voided or archived records where
appropriate. Permanent erasure belongs to the explicit account-deletion path.

**Revisit when:** Retention requirements or user research call for per-record permanent deletion.
That feature needs defined synchronization and export semantics rather than a local row deletion.

### D-010 — Snapshot sync with stable UUIDs and last-write-wins

**Status:** Accepted for personal alpha; intentionally temporary at larger scale

**Decision:** Client and server exchange complete snapshots. Stable UUIDs preserve identity,
normalized names repair historical duplicates, and the newer `updatedAt` wins.

**Why:** The model is small, inspectable, testable end to end, and sufficient for current data
volume.

**Cost:** It trusts reasonably accurate client clocks, does not merge fields, and transfers more
data as histories grow.

**Revisit when:** Tali supports sustained multi-device editing, snapshots approach a measured
latency or size budget, or conflict reports occur. Candidate replacements are server revisions,
logical clocks, cursor-based deltas, and an explicit conflict UI.

### D-011 — Sign in with Apple plus one-time phone pairing

**Status:** Accepted for the iOS alpha

**Decision:** The Worker verifies an Apple identity token and nonce, issues a random device session,
stores only its hash, and links an SMS number through a short-lived one-time code.

**Why:** It minimizes identity collection, avoids passwords, fits the native platform, and separates
account proof from phone-number control.

**Cost:** Connected accounts depend on Apple identity. Sessions expire after 180 days and currently
have individual revocation but no refresh-token rotation or one-tap revoke-all operation.

**Revisit when:** A non-Apple client is justified, recovery failures appear, or public use requires
shorter sessions and automatic rotation.

### D-012 — Twilio, Cloudflare Workers, and D1 for SMS

**Status:** Accepted for the alpha

**Decision:** Twilio transports SMS, a Cloudflare Worker verifies and handles webhooks, and D1 stores
user-scoped server records.

**Why:** This stack exposes the actual hard parts of the product—carrier compliance, signed
webhooks, idempotency, multi-tenant routing, and synchronization—without maintaining a server VM.

**Cost:** SMS has per-message cost, A2P registration, provider data exposure, and carrier delivery
constraints. D1 and Worker operations are provider-specific.

**Revisit when:** Measured traffic, cost, regional requirements, or reliability targets exceed the
stack. A migration decision should use observed load and failure data rather than theoretical scale.

### D-013 — No behavioral analytics in the personal alpha

**Status:** Accepted; validation method still needs evidence

**Decision:** Tali does not send habit names, notes, entry histories, or product-interaction
analytics to an analytics provider. Operational logs use generated identifiers and categories.

**Why:** The data can be sensitive, and an early personal product does not justify collecting it by
default.

**Cost:** Tali cannot answer retention or funnel questions from passive telemetry. The current
product thesis is based on a founder problem and implementation learning, not broad user validation.

**Revisit when:** External testing begins. Prefer consented interviews, opt-in feedback, and
aggregate event instrumentation with a written data budget before adding any SDK.

## Delivery decisions

### D-014 — AI-assisted, human-directed development

**Status:** Accepted and disclosed

**Decision:** Coding agents accelerated implementation, debugging, test creation, and documentation.
Kathryn remained accountable for the problem framing, product principles, acceptance criteria,
architecture tradeoffs, review, hands-on integration, and release decisions.

**Why:** The portfolio is intended to demonstrate product and engineering judgment, including the
ability to direct and verify modern development tools, rather than unaided typing speed.

**Cost:** A polished repository or large commit does not prove understanding by itself. Generated
code can create false confidence, inconsistent documentation, and broad features without depth.

**Control:** AI output is not treated as evidence. A behavior is described as verified only when it
has an automated test, a reproducible release check, or an explicit manual gate. Failures and
unshipped work remain documented.

**Revisit when:** Team contribution rules, employer policy, licensing, or model-data requirements
change. The author should be able to explain, modify, and debug every shipped boundary regardless
of who or what produced the first draft.

