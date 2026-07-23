const baseURL = "https://tali-sms.katswint.workers.dev";

export function smsProgramPage(): Response {
  return htmlPage(
    "Tali SMS",
    "Text your habits. Tali keeps the timeline.",
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
      </section>
    `,
  );
}

export function privacyPage(): Response {
  return htmlPage(
    "Tali SMS Privacy Policy",
    "Effective July 22, 2026",
    `
      ${section("Information Tali processes", `
        Tali processes the mobile number enrolled in the SMS program, message contents such as
        habit commands and optional notes, timestamps, synchronized habit records, and limited
        technical logs needed to operate and secure the service.
      `)}
      ${section("How information is used", `
        This information is used only to authenticate the enrolled user, record requested habit
        activity, return transactional replies, synchronize the Tali app, prevent abuse, and
        troubleshoot service problems.
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
        Tali data through the contact information at katswint.com.
      `)}
      ${section("Contact", `
        Questions about this policy or Tali's data practices can be submitted through
        <a class="font-medium text-emerald-700 underline underline-offset-4" href="https://katswint.com">katswint.com</a>.
      `)}
    `,
  );
}

export function termsPage(): Response {
  return htmlPage(
    "Tali SMS Terms",
    "Effective July 22, 2026",
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
        <a class="font-medium text-emerald-700 underline underline-offset-4" href="https://katswint.com">katswint.com</a>.
      `)}
      ${section("Availability", `
        Tali is provided as a pre-launch personal project and may change or be unavailable. Mobile
        carriers are not liable for delayed or undelivered messages.
      `)}
      ${section("Privacy", `
        Tali's handling of mobile and habit information is described in the
        <a class="font-medium text-emerald-700 underline underline-offset-4" href="${baseURL}/privacy">Tali SMS Privacy Policy</a>.
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

function htmlPage(title: string, subtitle: string, content: string): Response {
  const html = `<!doctype html>
  <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <meta name="description" content="${title}">
      <title>${title}</title>
      <script src="https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4"></script>
    </head>
    <body class="min-h-dvh bg-stone-50 text-stone-950 antialiased">
      <header class="border-b border-stone-200 bg-white">
        <div class="mx-auto flex max-w-3xl items-center justify-between px-6 py-5">
          <a class="text-lg font-semibold text-emerald-700" href="${baseURL}/sms">Tali</a>
          <nav aria-label="Legal">
            <ul class="flex gap-5 text-sm text-stone-600">
              <li><a class="hover:text-stone-950" href="${baseURL}/privacy">Privacy</a></li>
              <li><a class="hover:text-stone-950" href="${baseURL}/terms">Terms</a></li>
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
    },
  });
}
