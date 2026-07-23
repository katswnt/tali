# Tali operations runbook

## Environment boundaries

- Local development uses Wrangler's local D1 state.
- Staging deploys as `tali-sms-staging` and binds only to `tali-staging`.
- Production is the default `tali-sms` Worker and binds only to `tali`.
- Secrets are configured separately for each environment. Wrangler environment variables and secrets are not assumed to inherit.

Never use the production database to test migrations, load, retention, account deletion, or recovery.

## Required secrets

Set these for both environments, using environment-specific values where appropriate:

```sh
cd Server
npx wrangler secret put TWILIO_AUTH_TOKEN --env staging
npx wrangler secret put OWNER_PHONE --env staging
npx wrangler secret put SYNC_TOKEN --env staging
```

Production omits `--env staging`. Do not put secret values in `.dev.vars.example`, shell history, issue comments, screenshots, or logs.

## Deploy

Deploy staging first:

```sh
./scripts/deploy-worker.sh staging
```

After smoke, integration, and load checks pass, back up production and deploy with an explicit confirmation:

```sh
./scripts/backup-worker-db.sh production
TALI_CONFIRM_PRODUCTION=deploy-production ./scripts/deploy-worker.sh production
```

The deploy script runs type checks and Worker tests before applying migrations, applies migrations before code, and refuses an implicit production target.

## Smoke and load checks

Run the health-only load smoke against staging:

```sh
TALI_BASE_URL=https://tali-sms-staging.<account>.workers.dev npm --prefix Server run load:smoke
```

Add `TALI_BEARER_TOKEN` to exercise the authenticated account read. The pass criteria are:

- fewer than 1% failed HTTP requests;
- p95 below 500 ms and p99 below 1 second;
- more than 99% checks passing.

These are portfolio-stage service objectives, not a claim of production capacity. Record the date, Worker version, VUs, duration, and results in the release issue.

## Backup and recovery drill

Wrangler D1 exports are written under ignored `Server/backups/`. Store production exports in encrypted storage with restricted access; they contain private user data.

Quarterly recovery drill:

1. Export production with `./scripts/backup-worker-db.sh production`.
2. Create a disposable D1 database named `tali-recovery-drill-YYYYMMDD`.
3. Import the export into that disposable database.
4. Bind a temporary Worker to the disposable database.
5. Verify `/health`, account isolation, habit/event counts, and export integrity.
6. Record recovery time and mismatches.
7. Delete the temporary Worker and database after the result is recorded.

For an incident, use D1 Time Travel only after capturing a current export and identifying the exact bookmark with `wrangler d1 time-travel info`. A restore is destructive; require a second person to verify the target database and timestamp when Tali has a team.

## Incident triage

1. Confirm whether impact is local, staging, or production.
2. Check Worker request/error logs using privacy-safe request IDs; never log tokens, phone numbers, SMS bodies, or exported data.
3. If authentication is involved, revoke affected sessions. Refresh-token reuse automatically revokes every session for that account.
4. If Twilio is involved, compare Twilio Message SID/status with Tali's redacted operational event.
5. If data integrity is involved, pause deploys, export the database, and reproduce against a disposable copy.
6. Document detection, user impact, timeline, root cause, repair, and prevention.

## Rollback

- Code-only regression: redeploy the last known-good Worker version.
- Forward-compatible schema regression: roll back code, then ship a forward migration; do not edit an applied migration.
- Data regression: follow the recovery procedure. Never restore production merely to make an application error disappear.
