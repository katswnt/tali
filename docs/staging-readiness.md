# Staging readiness

Last read-only audit: **August 24, 2026**

This document records what exists remotely without exposing secret values.

## Current state

| Check | State | Evidence |
| --- | --- | --- |
| Staging D1 database | Exists | `tali-staging` resolves through the checked-in staging binding |
| Staging migrations | Current | Wrangler reports no pending migrations through `0009` |
| Staging Worker | Deployed | Version `afaded45-6e23-4801-824b-ff324a930ea9` is active |
| Staging secrets | Complete | `OWNER_PHONE`, `SYNC_TOKEN`, and `TWILIO_AUTH_TOKEN` are configured; values were not read |
| Production secret names | Complete | `OWNER_PHONE`, `SYNC_TOKEN`, and `TWILIO_AUTH_TOKEN` are configured; values were not read |
| Production migrations | Current | Wrangler reports no pending migrations through `0009` |
| Production Worker | Deployed | Version `1f0fb304-ffbb-4755-8ab7-703031f2f57e` is active |
| Production ownership audit | Clean | Habits, events, and SMS pairings with missing owners: `0` |
| Production SMS | Founder round trip verified | Pairing, HELP, logging, backdating, queries, typo suggestions, contact resharing, and app sync passed on a physical iPhone |
| A2P campaign | Cleared for current testing | Keep carrier configuration in the release checklist and recheck it before broad public onboarding |

Production is not a substitute for staging. Do not run migration, load, deletion, retention, or
recovery tests against production.

## Safe staging refresh

1. Review the branch diff and confirm the staging D1 ID in `Server/wrangler.jsonc`.
2. Run `./scripts/deploy-worker.sh staging`. The script tests the Worker, applies pending
   migrations to `tali-staging`, and deploys `tali-sms-staging`.
3. Preserve the staging-specific `TWILIO_AUTH_TOKEN`, `OWNER_PHONE`, and `SYNC_TOKEN` secrets.
   Never paste their values into this repo, shell arguments, screenshots, or issue comments.
4. Run:

   ```sh
   TALI_BASE_URL=https://tali-sms-staging.<account>.workers.dev \
     npm --prefix Server run test:smoke:staging
   ```

5. Run the health-only load smoke from `operations-runbook.md`.
6. Test authentication and SMS only with a dedicated staging Twilio sender or a deliberate signed
   test harness. Do not point the production phone number at staging.
7. Record the Worker version, test date, and results in the release issue.

The staging smoke script is GET-only and refuses any hostname that does not contain `staging`. It
checks health, all public pages, their canonical URLs, and security headers.

## Production gates after staging

Before a production deployment:

- back up D1 to encrypted, access-limited storage;
- inspect every pending migration and confirm the current Worker remains compatible during the
  forward migration;
- complete staging auth, tenant-isolation, export, deletion, retention, and rollback exercises;
- confirm the deployed `/support`, `/privacy`, `/terms`, and `/sms` pages match App Store metadata;
- recheck Twilio/carrier approval before broad public onboarding;
- require the explicit `TALI_CONFIRM_PRODUCTION=deploy-production` guard in the runbook.

The ownership audit was read-only. The tested Worker was then deployed to staging and production;
no database migration or secret change was required.
