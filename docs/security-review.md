# Security and production self-review

Review date: **July 23, 2026**  
Scope: native credential storage and transport, Worker authentication, multi-user authorization,
Twilio webhooks, D1 persistence, sync, export/deletion, observability, retention, dependencies, and
deployment controls.

This is a structured maintainer self-review, not an independent penetration test or a production
certification.

## Outcome

The branch has a credible personal-alpha security boundary and substantially better multi-user
controls than the original single-owner prototype. Automated tests cover Apple JWT claims, rotating
sessions, replay response, tenant isolation, signed webhooks, idempotent SMS mutations, payload
validation, account export/deletion, rate limits, retention, and revisioned sync.

Public onboarding remains closed. Carrier approval, provider retention configuration, staging,
physical-device validation, backup recovery, and independent review are release gates.

## Controls verified

| Area | Evidence |
| --- | --- |
| Apple authentication | RS256 signature plus issuer, audience, expiration, issued-at, subject, and hashed nonce checks |
| Apple key rotation | Unknown key IDs trigger a refresh; cached keys have a bounded stale-if-error window |
| Sessions | 256-bit access tokens, 384-bit refresh tokens, hashes only in D1, 15-minute access life, 90-day session life |
| Refresh replay | Every spent refresh-token hash remains until session expiry; any reuse revokes the user's session family |
| Native credentials | Session material is stored in Keychain and excluded from local/complete exports |
| Tenant isolation | Habit, event, session, phone, pairing, SMS receipt, sync-revision, export, and deletion queries resolve a user ID |
| Phone pairing | Cryptographic 40-bit one-time code, ten-minute expiry, hashed storage, rate limits, no cross-account reassignment |
| Twilio | Signature verification precedes processing; duplicate Message SIDs return one stored result and one mutation |
| Input limits | Auth/deletion JSON is capped at 16 KiB; sync is capped at 2 MB, 1,000 habits, and 50,000 events with bounded fields |
| Abuse controls | IP auth, user pairing/sync/export, and phone pairing attempts persist only hashed limit keys |
| User control | Local and server export, device-session listing/revocation, sign out everywhere, and server account deletion |
| Logging | Fixed route categories, opaque request/message/user IDs, status and failure categories; no habit names, notes, phone numbers, tokens, or SMS bodies |
| Public pages | No third-party JavaScript, restrictive CSP, no-referrer policy, frame denial, and explicit support/privacy paths |
| Dependencies | `npm audit` reports zero known vulnerabilities; the Worker has no production npm dependency |
| Secrets | `.dev.vars`, environment files, keys, backups, Wrangler state, and build output are ignored; tracked-file pattern scan found no credential material |
| Deploy safety | Separate D1 bindings, staging-first runbook, production confirmation guard, pre-deploy tests, forward-only migrations, backup procedure |

## Findings fixed in this review

### SR-001 — Refresh replay history was only one token deep

**Severity:** High  
**Risk:** Reuse of the immediately prior token revoked sessions, but a token replayed after two
rotations was rejected without revoking the credential family.

**Fix:** Migration `0008_refresh_reuse_history.sql` adds hashes of spent refresh tokens through
session expiry. Rotation records the old hash transactionally with the new token. The managed
integration suite rotates twice, reuses the original token, and confirms the newest access token is
revoked.

### SR-002 — Small authentication routes had no explicit body limit

**Severity:** Medium  
**Risk:** Rate limiting bounded request count but not memory consumed by each JSON parse.

**Fix:** Apple sign-in, refresh, and account-deletion JSON are capped at 16 KiB before parsing and
return `413` when oversized.

### SR-003 — Expensive authenticated reads/writes lacked application limits

**Severity:** Medium  
**Risk:** A valid session could repeatedly request full snapshots or exports and amplify D1 work.

**Fix:** Sync is limited to 120 requests per ten minutes per user; export is limited to ten per ten
minutes. Limit identifiers are hashed.

### SR-004 — Provider and first-party SMS retention were easy to conflate

**Severity:** High for disclosure; external configuration remains open  
**Risk:** Tali deletes its D1 copy after 30 days, but that does not delete Twilio's transport copy.

**Fix:** The privacy policy now distinguishes the two. Public launch requires
[Twilio message-body redaction](https://www.twilio.com/docs/messaging/guides/privacy-message-redaction)
and retention settings to be verified against the deployed policy.

### SR-005 — Legal pages loaded an undeclared third party

**Severity:** Medium  
**Risk:** A browser Tailwind CDN received page requests even though the policy named only Cloudflare
and Twilio.

**Fix:** The pages use local inline CSS and a restrictive Content Security Policy. No third-party
script or font request remains.

## Open risks and release gates

1. **Legacy bearer access:** `SYNC_TOKEN` still grants the legacy owner broad access. Retire it after
   an Apple session has claimed and verified the existing data; do not ship public onboarding with
   a permanent compatibility credential.
2. **Provider retention:** Enable and verify Twilio message-body redaction and the intended message
   record retention. Advanced Opt-Out must remain compatible with the selected phone-number
   handling.
3. **Remote state:** Staging is not deployed, staging migrations are unapplied, and production has
   pending migrations. Follow `staging-readiness.md`; never test destructive paths in production.
4. **Sync transaction boundary:** Revision reservation and snapshot reconciliation are separate D1
   operations. The protocol recovers with stale-cursor reconciliation, but broader concurrent use
   should move a mutation behind one transactional boundary.
5. **Backup recovery:** The runbook exists, but a timed export/restore drill has not been performed.
6. **Independent review:** JWT, Twilio canonicalization, account deletion, and cross-tenant tests
   should receive review by someone other than the author before unrestricted traffic.
7. **Device and distribution:** App Group behavior, Keychain persistence, Sign in with Apple,
   Messages, Siri/Shortcuts, archive entitlements, and accessibility still require a physical
   iPhone and TestFlight pass.
8. **Carrier path:** A2P approval and real START/HELP/STOP, inbound command, reply delivery, and
   status-callback tests remain external gates.

## Verification commands

```sh
./scripts/release-check.sh
cd Server
npm audit
npm run test:integration:managed
```

For remote work, use only the staging bootstrap and smoke sequence in
`docs/staging-readiness.md`. A passing self-review does not authorize a production migration or
deploy.
