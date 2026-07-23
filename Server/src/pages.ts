const baseURL = "https://tali-sms.katswint.workers.dev";

export function smsProgramPage(): Response {
  return htmlPage(
    "Tali SMS",
    "Text your habits. Tali keeps the timeline.",
    "/sms",
    "How Tali SMS enrollment, habit logging, opt-out, and transactional messages work.",
    `
      <section class="space-y-4">
        <h2 class="text-balance text-2xl font-semibold">How enrollment works</h2>
        <p class="text-pretty text-stone-700">
          Tali is a pre-launch personal habit tracker operated by Kathryn Swint. The current SMS
          program is limited to its developer and sends transactional replies only after the user
          initiates a conversation.
        </p>
        <ol class="list-decimal space-y-3 pl-6 text-pretty text-stone-700">
          <li>Text <strong>START</strong> to +1 (445) 545-2123 to opt in.</li>
          <li>Text a configured habit name or command to use Tali.</li>
          <li>Reply <strong>STOP</strong> to unsubscribe or <strong>HELP</strong> for assistance.</li>
        </ol>
      </section>
      <section class="mt-10 border-t border-stone-200 pt-8">
        <h2 class="text-balance text-2xl font-semibold">Messaging disclosures</h2>
        <p class="mt-4 text-pretty text-stone-700">
          Message frequency varies based on your use of Tali. Message and data rates may apply.
          Consent to SMS is optional and is not a condition of purchase. Tali does not send
          marketing or promotional messages.
        </p>
        <p>
          For account, privacy, or delivery help, visit
          <a href="${baseURL}/support">Tali Support</a>.
        </p>
      </section>
    `,
  );
}

export function supportPage(): Response {
  return htmlPage(
    "Tali Support",
    "Help with the app, texting, privacy, and your data.",
    "/support",
    "Get help with Tali, report a problem, manage connected data, or contact its developer.",
    `
      ${section("Get help", `
        Tali is an independent, pre-launch project operated by Kathryn Swint. For support,
        feedback, or a privacy request, contact Kathryn through
        <a href="https://www.linkedin.com/in/kathrynswint/">LinkedIn</a>. Include “Tali” in your
        message, but do not send private habit names, notes, pairing codes, or account tokens.
      `)}
      ${section("Manage your data", `
        Local data can be exported from Tali's menu. Connected account data can be exported or
        deleted from Texting settings. Deleting the app does not automatically delete connected
        server data.
      `)}
      ${section("Text-message help", `
        Reply HELP for messaging assistance or STOP to unsubscribe. Message and data rates may
        apply. If a reply does not arrive, confirm that the number is enrolled and check Tali's
        <a href="${baseURL}/sms">SMS program information</a>.
      `)}
      ${section("Useful links", `
        Read Tali's <a href="${baseURL}/privacy">Privacy Policy</a> and
        <a href="${baseURL}/terms">SMS Terms</a>, or return to
        <a href="https://katswint.com">Kathryn's portfolio</a>.
      `)}
    `,
  );
}

export function privacyPage(): Response {
  return htmlPage(
    "Tali Privacy Policy",
    "Effective July 22, 2026",
    "/privacy",
    "How Tali handles local habit records, account data, text messages, retention, export, and deletion.",
    `
      ${section("Local app data", `
        Tali can be used without an account. Habit names, aliases, timestamps, notes, archive state,
        and display preferences created in that mode remain on the device and in Tali's shared app
        container. Tali does not use this information for advertising or behavior profiling.
      `)}
      ${section("Information Tali processes", `
        When a user connects texting, Tali processes a Sign in with Apple account identifier, a
        device/session identifier and user-visible device name, the mobile number enrolled in the
        SMS program, message contents such as habit commands and optional notes, timestamps,
        synchronized habit records, and limited technical logs needed to operate and secure the
        service. Tali does not request the user's name or email address from Apple.
      `)}
      ${section("How information is used", `
        This information is used only to authenticate the enrolled user, record requested habit
        activity, return transactional replies, synchronize the Tali app, prevent abuse, and
        troubleshoot service problems.
      `)}
      ${section("Retention and deletion", `
        Habit records remain until the user deletes the account. SMS delivery receipts and message
        contents are removed after 30 days, expired pairing-code history after one day, and old
        revoked or expired sessions after 30 days. Users can export or delete their server data
        from Tali's Texting settings.
      `)}
      ${section("Mobile information and sharing", `
        Mobile information, including phone numbers and SMS consent records, is not sold, rented,
        or shared with third parties or affiliates for their marketing or promotional purposes.
        Twilio and Cloudflare process limited information as service providers solely to deliver
        and host Tali's functionality.
      `)}
      ${section("Messaging choices", `
        Message frequency varies based on use. Message and data rates may apply. Reply STOP at any
        time to unsubscribe and HELP for assistance. You can request access to or deletion of your
        Tali data through Tali Support.
      `)}
      ${section("Contact", `
        Questions about this policy or Tali's data practices can be submitted through
        <a href="${baseURL}/support">Tali Support</a>.
      `)}
    `,
  );
}

export function termsPage(): Response {
  return htmlPage(
    "Tali SMS Terms",
    "Effective July 22, 2026",
    "/terms",
    "Terms for Tali's optional transactional SMS habit-logging service.",
    `
      ${section("Program description", `
        Tali is a pre-launch personal habit-tracking program operated by Kathryn Swint. Enrolled
        users initiate messages by texting habit names or commands, and Tali returns transactional
        confirmations, habit lists, history, or elapsed-time summaries.
      `)}
      ${section("Consent and frequency", `
        By texting START, you consent to receive recurring automated transactional replies from
        Tali. Message frequency varies according to your use. Message and data rates may apply.
        Consent is optional and is not a condition of purchase.
      `)}
      ${section("Stopping messages and getting help", `
        Reply STOP to unsubscribe. After opting out, no further messages will be sent unless you
        opt in again. Reply HELP for assistance or visit
        <a href="${baseURL}/support">Tali Support</a>.
      `)}
      ${section("Availability", `
        Tali is provided as a pre-launch personal project and may change or be unavailable. Mobile
        carriers are not liable for delayed or undelivered messages.
      `)}
      ${section("Privacy", `
        Tali's handling of mobile and habit information is described in the
        <a href="${baseURL}/privacy">Tali SMS Privacy Policy</a>.
      `)}
    `,
  );
}

function section(title: string, body: string): string {
  return `
    <section class="border-b border-stone-200 py-7 first:pt-0 last:border-0 last:pb-0">
      <h2 class="text-balance text-xl font-semibold">${title}</h2>
      <p class="mt-3 text-pretty leading-7 text-stone-700">${body}</p>
    </section>
  `;
}

function htmlPage(
  title: string,
  subtitle: string,
  path: string,
  description: string,
  content: string,
): Response {
  const canonicalURL = `${baseURL}${path}`;
  const html = `<!doctype html>
  <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <meta name="description" content="${description}">
      <meta name="theme-color" content="#047857">
      <meta name="color-scheme" content="light dark">
      <meta name="application-name" content="Tali">
      <meta name="robots" content="index,follow">
      <meta property="og:type" content="website">
      <meta property="og:site_name" content="Tali">
      <meta property="og:title" content="${title}">
      <meta property="og:description" content="${description}">
      <meta property="og:url" content="${canonicalURL}">
      <meta name="twitter:card" content="summary">
      <meta name="twitter:title" content="${title}">
      <meta name="twitter:description" content="${description}">
      <link rel="canonical" href="${canonicalURL}">
      <title>${title}</title>
      <style>
        :root {
          color-scheme: light dark;
          font-family: ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
          font-synthesis: none;
          --background: #fafaf9;
          --surface: #ffffff;
          --text: #0c0a09;
          --secondary: #57534e;
          --border: #e7e5e4;
          --accent: #047857;
        }
        * { box-sizing: border-box; }
        body {
          min-height: 100dvh;
          margin: 0;
          background: var(--background);
          color: var(--text);
          -webkit-font-smoothing: antialiased;
        }
        body > header {
          border-bottom: 1px solid var(--border);
          background: var(--surface);
        }
        body > header > div {
          display: flex;
          width: min(100% - 3rem, 48rem);
          margin-inline: auto;
          align-items: center;
          justify-content: space-between;
          padding-block: 1.25rem;
        }
        nav ul {
          display: flex;
          gap: 1.25rem;
          margin: 0;
          padding: 0;
          list-style: none;
          font-size: 0.875rem;
        }
        a {
          color: var(--accent);
          font-weight: 600;
          text-decoration-thickness: 0.08em;
          text-underline-offset: 0.2em;
        }
        body > header a { text-decoration: none; }
        main {
          width: min(100% - 3rem, 48rem);
          margin-inline: auto;
          padding-block: 3rem 4rem;
        }
        main > header { margin-bottom: 2.5rem; }
        main > header > p:first-child {
          margin: 0 0 0.75rem;
          color: var(--accent);
          font-size: 0.875rem;
          font-weight: 600;
        }
        h1 {
          max-width: 18ch;
          margin: 0;
          font-size: clamp(2.25rem, 7vw, 3rem);
          line-height: 1.05;
          letter-spacing: -0.035em;
        }
        main > header > p:last-child {
          margin: 1rem 0 0;
          color: var(--secondary);
          font-size: 1.125rem;
          line-height: 1.6;
        }
        article section { padding-block: 1.75rem; }
        article section:first-child { padding-top: 0; }
        article section + section { border-top: 1px solid var(--border); }
        article h2 {
          margin: 0;
          font-size: 1.4rem;
          line-height: 1.25;
          letter-spacing: -0.015em;
        }
        article p, article li {
          color: var(--secondary);
          line-height: 1.75;
        }
        article p { margin: 0.75rem 0 0; }
        article ol { margin: 1rem 0 0; padding-left: 1.5rem; }
        article li + li { margin-top: 0.65rem; }
        strong { color: var(--text); }
        @media (prefers-color-scheme: dark) {
          :root {
            --background: #0c0a09;
            --surface: #1c1917;
            --text: #fafaf9;
            --secondary: #d6d3d1;
            --border: #44403c;
            --accent: #34d399;
          }
        }
      </style>
    </head>
    <body class="min-h-dvh bg-stone-50 text-stone-950 antialiased">
      <header class="border-b border-stone-200 bg-white">
        <div class="mx-auto flex max-w-3xl items-center justify-between px-6 py-5">
          <a class="text-lg font-semibold text-emerald-700" href="${baseURL}/sms">Tali</a>
          <nav aria-label="Legal">
            <ul class="flex gap-5 text-sm text-stone-600">
              <li><a class="hover:text-stone-950" href="${baseURL}/privacy">Privacy</a></li>
              <li><a class="hover:text-stone-950" href="${baseURL}/terms">Terms</a></li>
              <li><a class="hover:text-stone-950" href="${baseURL}/support">Support</a></li>
            </ul>
          </nav>
        </div>
      </header>
      <main class="mx-auto max-w-3xl px-6 py-12 sm:py-16">
        <header class="mb-10">
          <p class="mb-3 text-sm font-medium text-emerald-700">Tali SMS</p>
          <h1 class="text-balance text-4xl font-semibold sm:text-5xl">${title}</h1>
          <p class="mt-4 text-pretty text-lg text-stone-600">${subtitle}</p>
        </header>
        <article>${content}</article>
      </main>
    </body>
  </html>`;

  return new Response(html, {
    status: 200,
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "public, max-age=300",
      "x-content-type-options": "nosniff",
      "referrer-policy": "no-referrer",
      "x-frame-options": "DENY",
      "content-security-policy": "default-src 'none'; style-src 'unsafe-inline'; img-src 'self' data:; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
      "permissions-policy": "camera=(), microphone=(), geolocation=(), payment=()",
    },
  });
}
