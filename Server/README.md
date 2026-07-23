# Tali SMS service

This Cloudflare Worker turns a Twilio phone number into a multi-user text interface for Tali. It validates Twilio webhooks, verifies Sign in with Apple identity tokens, issues hashed server sessions, pairs phone numbers with one-time codes, scopes every habit query to one user, replies with TwiML, and exposes a bearer-protected sync endpoint to the iPhone app.

## Routes

- `GET /health` — deployment health check
- `POST /v1/auth/apple` — verify an Apple identity token and issue a device session
- `GET /v1/account` — return masked phone-pairing status
- `GET /v1/account/export` — export every user-scoped server record without credential hashes
- `DELETE /v1/account` — permanently delete an authenticated account and its server data
- `GET /v1/sessions` — list active device sessions
- `DELETE /v1/sessions/:id` — revoke one device session
- `POST /v1/pairing/code` — create a short-lived one-time pairing code
- `DELETE /v1/session` — revoke the current device session
- `POST /twilio/incoming` — Twilio incoming-message webhook
- `POST /twilio/status` — signed, content-free delivery-status callback
- `POST /v1/sync` — bidirectional snapshot sync for the Tali app

The SMS parser accepts the same core commands as the native app:

- `yoga`
- `I did physical therapy`
- `yoga yesterday at 7pm`
- `yoga -- hips felt better`
- `since yoga`
- `history yoga`
- `habits`
- `undo`

The Worker also returns the branded compliance responses registered with carriers:

- `START`, `YES`, or `UNSTOP` — opt-in confirmation
- `HELP` or `INFO` — usage and opt-out help
- `STOP`, `STOPALL`, `CANCEL`, `END`, `QUIT`, or `UNSUBSCRIBE` — opt-out confirmation

Twilio's Messaging Service should keep Advanced Opt-Out enabled so carrier-level suppression remains authoritative. The Worker responses are a tested fallback and keep local/development behavior consistent.

Sync consolidates habits by normalized name when different installations upload different UUIDs for the same habit. Events are reassigned to the canonical habit before duplicates are removed. All reads and mutations include the authenticated user ID; phone routing resolves the same ID before parsing an SMS command.

Migration `0003_multi_user.sql` assigns all pre-existing data to a fixed legacy user. The original `SYNC_TOKEN` and `OWNER_PHONE` keep working during migration. When that owner signs in and pairs the existing phone, Tali atomically moves the new Apple session onto the legacy user so the old data remains intact. Rotate or retire `SYNC_TOKEN` after that transition is verified.

Migration `0005_rate_limits.sql` stores only hashed abuse-control identifiers. Authentication is limited by Cloudflare connection IP, pairing-code creation by generated user ID, and SMS pairing attempts by a hash of the sending number.

The daily scheduled handler removes expired rate-limit rows, pairing-code history older than one day, SMS receipts and message contents older than 30 days, and revoked or expired sessions after 30 days. Habit data remains until account deletion.

## Local development

```bash
cp .dev.vars.example .dev.vars
npm install
npm run db:migrate:local
npm run dev
```

Production operational logs are structured JSON and contain route categories, generated request and user IDs, status codes, duration, and failure categories. They intentionally exclude phone numbers, habit names, notes, raw message bodies, identity tokens, and session tokens.

In another terminal:

```bash
npm run test:integration:local
```

Keep `.dev.vars` local. It is ignored by Git.

## Deploy to Cloudflare

1. Create a Cloudflare account and authenticate Wrangler:

   ```bash
   npx wrangler login
   ```

2. Create a D1 database for your deployment:

   ```bash
   npx wrangler d1 create tali
   ```

   Replace the checked-in `database_id` in `wrangler.jsonc` with the ID Wrangler returns. The committed ID belongs to Tali’s deployment and is not reusable by a fork.

3. Deploy the Worker and apply its migrations:

   ```bash
    npm run deploy
    npm run db:migrate:remote
   ```

4. Generate a sync token and save the three production secrets:

   ```bash
   openssl rand -hex 32
   npx wrangler secret put SYNC_TOKEN
   npx wrangler secret put OWNER_PHONE
   npx wrangler secret put TWILIO_AUTH_TOKEN
   ```

   Use E.164 format for `OWNER_PHONE`, such as `+14155550123`. `TWILIO_AUTH_TOKEN` comes from the Twilio Console. Keep `ALLOW_UNSIGNED_TWILIO` set to `false` in production.

   `APPLE_CLIENT_ID` is a non-secret Worker variable and must match the native app bundle identifier (`com.kathrynswint.Tali`).

5. Copy the `https://…workers.dev` URL printed by Wrangler. Confirm that `<worker-url>/health` returns `{"ok":true,"service":"tali-sms"}`.

## Connect Twilio

1. In Twilio, acquire an SMS-capable phone number.
2. Open that number's Messaging configuration.
3. For **A message comes in**, select **Webhook**, enter `<worker-url>/twilio/incoming`, and choose **HTTP POST**.
4. Save the configuration.

Twilio signs inbound webhooks with `X-Twilio-Signature`; the Worker validates the signature with `TWILIO_AUTH_TOKEN` before changing data. See [Twilio's webhook security guide](https://www.twilio.com/docs/usage/webhooks/webhooks-security).

## Connect the iPhone app

1. Run the latest Tali build and tap the message icon.
2. Continue with Apple. The app stores the returned device session in Keychain.
3. Text `START` to provide SMS consent.
4. Create a pairing code in the app and send the prefilled `PAIR ABCD2345` text before it expires.
5. Check the connection in Tali. The first sync then uploads the habits already on the phone.
6. Text a habit name to the Twilio number. Open Tali or pull down on the dashboard to fetch the entry.

After setup, the Texting screen shows connection status, a masked paired number, the Tali phone number, and a manual **Sync now** action. The Worker URL is stored in the app group's preferences only when customized. Session tokens are stored in Keychain and never committed to the project. The original private-key connection remains under **Advanced** only for backward compatibility.

Do not invite additional SMS users while the current A2P campaign still describes a single-developer beta. Update or replace the campaign and its public opt-in disclosures first; the approved registration must match the real onboarding and message traffic.

For the authentication boundary, pairing threat model, synchronization algorithm, and accepted alpha constraints, see [Security and sync](../docs/security-and-sync.md).
