# Security and sync

This document describes Tali’s current trust boundaries, synchronization behavior, and accepted personal-alpha constraints. It is not a claim that the service is ready for unrestricted public traffic.

## Data boundaries

### Native device

- Habits and entries are stored in SwiftData.
- The app and Messages extension use the same App Group container.
- The app remains usable without an account or server.
- Device session tokens are stored in Keychain.
- CSV and JSON exports never include connection credentials.

### Cloudflare Worker and D1

- D1 stores Apple subject identifiers, paired phone numbers, habits, entries, session hashes, one-time pairing-code hashes, and Twilio message receipts.
- Habit and event operations include a resolved user ID.
- Raw session tokens and raw pairing codes are not stored in D1.
- Server configuration secrets remain in Wrangler secrets or ignored local `.dev.vars`.

### Twilio

- Twilio receives SMS phone numbers and message contents as the transport provider.
- The Worker verifies `X-Twilio-Signature` before processing a webhook.
- Twilio Advanced Opt-Out is authoritative for carrier-level START, HELP, and STOP handling.
- Tali's 30-day D1 retention does not delete Twilio's provider copy. Message-body redaction and
  provider retention settings are separate launch configuration.

## Authentication

1. The app creates a cryptographic nonce and requests Sign in with Apple.
2. The Worker verifies the JWT signature against Apple’s public keys.
3. It validates the issuer, audience, expiration, issued-at time, subject, and hashed nonce.
4. The Worker returns a random 256-bit access token and refresh token.
5. The app stores both in Keychain.
6. D1 stores only SHA-256 hashes and expirations.

Access tokens last 15 minutes. Refresh sessions last 90 days and rotate on every use. Hashes of
spent refresh tokens remain only until their session expiry so reuse can be detected across more
than one rotation. Reusing any superseded refresh token is treated as a possible credential replay
and revokes every session for that user. The app lists active devices, supports individual
revocation, and offers “sign out everywhere.” Account deletion removes every session and spent
credential hash with the account.

## Phone pairing

An authenticated session can request one active eight-character code. The code:

- uses an ambiguity-reduced 32-character alphabet;
- is generated with `crypto.getRandomValues`;
- is stored only as a SHA-256 hash;
- expires after ten minutes;
- is marked used after a successful pair;
- cannot move a phone number already associated with another user.

The SMS itself proves control of the sending number. Authentication attempts are rate-limited by a
hash of Cloudflare's connection IP, code creation by generated user ID, and SMS pairing attempts by
a hash of the sending number.

## Webhook integrity and idempotency

The Worker reconstructs Twilio’s signed request payload and verifies its HMAC before reading or mutating user data. Unsigned requests are rejected unless an explicit development flag is enabled.

Each inbound `MessageSid` is recorded with its response. A repeated delivery returns the original response, while D1’s transactional batch prevents the corresponding event mutation from being applied twice.

## Synchronization model

The native app sends a snapshot containing habits and events. Both use stable UUIDs, creation
timestamps, and update timestamps. Version 2 wraps that snapshot in a server-issued base revision
and a stable client mutation UUID.

For each authenticated user, the Worker:

1. Rejects a stale base revision with `409`, the current revision, and the canonical server
   snapshot.
2. Lets the app merge that snapshot locally using the normal newer-update rule.
3. Accepts one automatic retry against the new revision.
4. Records the mutation UUID so a network retry cannot apply the same logical mutation twice.
5. Returns the new revision and complete canonical snapshot.

Every SMS mutation also increments the same revision. This means a device that was offline while
an SMS arrived receives an explicit conflict response rather than silently assuming its prior
snapshot was current. Version 1 remains available temporarily so an already-installed client can
sync during the rollout; new clients try version 2 first.

Within an accepted snapshot, the Worker:

1. Loads the authenticated user’s existing habits.
2. Repairs historical duplicates with equal normalized names.
3. Maps incoming habit UUIDs to canonical UUIDs when necessary.
4. Applies a newer habit or event when its `updatedAt` is later.
5. Remaps events before deleting duplicate habit rows.
6. Returns the complete canonical snapshot for that user.

The app applies the same newer-update rule and performs one final local duplicate consolidation.

### Why this model

Snapshot sync remains small, inspectable, and sufficient for the current data volume. UUIDs
preserve identity across capture surfaces, voided events make undo synchronize like any other
update, and server revisions make stale concurrent work visible without making client clocks the
arbiter of whether a snapshot was based on current state.

### Accepted constraints

- Last-write-wins relies on reasonably accurate client clocks.
- Concurrent edits do not merge individual fields.
- The protocol transfers full snapshots rather than deltas.
- Synchronization occurs on app activity or explicit refresh rather than background push.
- Revision reservation and snapshot reconciliation are separate D1 operations. Last-write-wins
  keeps entity application idempotent, but a future high-concurrency protocol should move the
  complete mutation behind a transactional server boundary.

Account deletion removes events, SMS receipts, habits, phone pairings, pairing-code history, sessions, and the user row in one D1 batch. The app intentionally keeps its local-only store so it remains useful without an account.

Authenticated exports include every server-side user record while excluding session-token hashes and pairing-code hashes. The app’s complete JSON archive combines that verified server export with the local SwiftData export.

Before broader multi-device use, Tali should evaluate cursor-based deltas, field-aware conflict
UX, and a documented maximum snapshot size against measured payloads and conflict frequency.

## Logging and observability

Tali intentionally has no behavioral analytics in the personal alpha. Production operations emit structured signals for:

- authentication failures by category;
- invalid webhook signatures;
- sync request size and latency;
- D1 failures;
- pairing attempts and throttling;
- Twilio delivery status;
- client-visible sync errors.

Those events use generated identifiers and error categories, not habit names, notes, phone numbers, identity tokens, session tokens, or raw SMS bodies. TwiML replies include a signed delivery-status callback so delivery failures can be correlated by generated Twilio Message SID.

Authentication attempts are limited by a hash of Cloudflare’s connection IP, pairing-code creation by generated user ID, and SMS pairing attempts by a hash of the sending number. Raw identifiers are never stored in the rate-limit table.

Authenticated sync and account exports also have per-user abuse limits. JSON authentication and
deletion bodies are capped at 16 KiB before parsing; sync bodies are capped at 2 MB with explicit
entity-count and field-length limits.

The scheduled retention job deletes SMS receipts and message contents after 30 days, pairing-code
history after one day, old revoked or expired sessions after 30 days, and spent refresh-token
hashes at session expiry. Habit records remain until the user deletes the account.

## Public-launch gates

- A2P campaign approval for the actual onboarding and message flow
- Twilio message-body redaction and retention settings verified against the public privacy policy
- Independent signature/JWT test fixtures and security review
- Physical-device and carrier-path testing
- A documented backup and restore exercise for production D1 data
- An account-recovery decision before supporting non-Apple clients
- Legacy `SYNC_TOKEN` retired after the existing owner data is claimed by a verified Apple session
