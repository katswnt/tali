# Staging readiness

Last read-only audit: **July 23, 2026**

This document records what exists remotely without exposing secret values. It is not evidence that
the current branch has been deployed.

## Current state

| Check | State | Evidence |
| --- | --- | --- |
| Staging D1 database | Exists | `tali-staging` resolves through the checked-in staging binding |
| Staging migrations | Not applied | Wrangler listed `0001` through `0007` as pending at audit time; `0008` was added afterward and is also unapplied |
| Staging Worker | Does not exist | Wrangler reports `tali-sms-staging` not found |
| Staging secrets | Cannot exist yet | Cloudflare accepts environment secrets only after the Worker exists |
| Production secret names | Complete | `OWNER_PHONE`, `SYNC_TOKEN`, and `TWILIO_AUTH_TOKEN` are configured; values were not read |
| Production migrations | Partially applied | `0004` through `0007` are pending |
| A2P campaign | External gate | Carrier registration is rejected/pending resubmission; public SMS onboarding stays closed |

Production is not a substitute for staging. Do not run migration, load, deletion, retention, or
recovery tests against production.

## Safe staging bootstrap

Run these only when a staging deployment is explicitly approved:

1. Review the branch diff and confirm the staging D1 ID in `Server/wrangler.jsonc`.
2. Run `./scripts/deploy-worker.sh staging`. The script tests the Worker, applies all eight
   migrations to `tali-staging`, and creates `tali-sms-staging`.
3. Immediately add staging-specific `TWILIO_AUTH_TOKEN`, `OWNER_PHONE`, and `SYNC_TOKEN` secrets.
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

Before production deployment:

- back up D1 to encrypted, access-limited storage;
- inspect migrations `0004`–`0007` and confirm the current Worker remains compatible during the
  forward migration;
- complete staging auth, tenant-isolation, export, deletion, retention, and rollback exercises;
- confirm the deployed `/support`, `/privacy`, `/terms`, and `/sms` pages match App Store metadata;
- keep public SMS onboarding closed until Twilio/carrier approval matches the real message flow;
- require the explicit `TALI_CONFIRM_PRODUCTION=deploy-production` guard in the runbook.

No production migration or deploy was performed during this audit.
