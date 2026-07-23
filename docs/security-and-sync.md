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

## Authentication

1. The app creates a cryptographic nonce and requests Sign in with Apple.
2. The Worker verifies the JWT signature against Apple’s public keys.
3. It validates the issuer, audience, expiration, issued-at time, subject, and hashed nonce.
4. The Worker returns a random 256-bit device session.
5. The app stores the token in Keychain.
6. D1 stores only its SHA-256 hash and expiration.

Sessions currently last 180 days and can be revoked by signing out from that device. Public multi-user use should add a device/session list, revoke-all behavior, and explicit rotation policy.

## Phone pairing

An authenticated session can request one active eight-character code. The code:

- uses an ambiguity-reduced 32-character alphabet;
- is generated with `crypto.getRandomValues`;
- is stored only as a SHA-256 hash;
- expires after ten minutes;
- is marked used after a successful pair;
- cannot move a phone number already associated with another user.

The SMS itself proves control of the sending number. Authentication and pairing endpoints still need rate limits before public onboarding.

## Webhook integrity and idempotency

The Worker reconstructs Twilio’s signed request payload and verifies its HMAC before reading or mutating user data. Unsigned requests are rejected unless an explicit development flag is enabled.

Each inbound `MessageSid` is recorded with its response. A repeated delivery returns the original response, while D1’s transactional batch prevents the corresponding event mutation from being applied twice.

## Synchronization model

The native app sends a snapshot containing habits and events. Both use stable UUIDs, creation timestamps, and update timestamps.

The Worker:

1. Loads the authenticated user’s existing habits.
2. Repairs historical duplicates with equal normalized names.
3. Maps incoming habit UUIDs to canonical UUIDs when necessary.
4. Applies a newer habit or event when its `updatedAt` is later.
5. Remaps events before deleting duplicate habit rows.
6. Returns the complete canonical snapshot for that user.

The app applies the same newer-update rule and performs one final local duplicate consolidation.

### Why this model

Snapshot sync is small, inspectable, and sufficient for the current data volume. UUIDs preserve identity across capture surfaces, and voided events make undo synchronize like any other update.

### Accepted constraints

- Last-write-wins relies on reasonably accurate client clocks.
- Concurrent edits do not merge individual fields.
- The protocol transfers full snapshots rather than deltas.
- Synchronization occurs on app activity or explicit refresh rather than background push.

Account deletion removes events, SMS receipts, habits, phone pairings, pairing-code history, sessions, and the user row in one D1 batch. The app intentionally keeps its local-only store so it remains useful without an account.

Authenticated exports include every server-side user record while excluding session-token hashes and pairing-code hashes. The app’s complete JSON archive combines that verified server export with the local SwiftData export.

Before broader multi-device use, Tali should evaluate server-issued revisions or a logical clock, pagination or deltas, and a documented conflict UX.

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

The scheduled retention job deletes SMS receipts and message contents after 30 days, pairing-code history after one day, and old revoked or expired sessions after 30 days. Habit records remain until the user deletes the account.

## Public-launch gates

- A2P campaign approval for the actual onboarding and message flow
- Independent signature/JWT test fixtures and security review
- Physical-device and carrier-path testing
