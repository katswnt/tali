import assert from "node:assert/strict";
import { once } from "node:events";
import { spawn, spawnSync } from "node:child_process";
import { setTimeout as delay } from "node:timers/promises";

const npx = process.platform === "win32" ? "npx.cmd" : "npx";
const port = process.env.TALI_INTEGRATION_PORT ?? "8791";
const baseURL = `http://127.0.0.1:${port}`;
const workerOutput = [];

const migration = spawnSync(
  npx,
  ["wrangler", "d1", "migrations", "apply", "tali", "--local"],
  { stdio: "inherit" },
);
if (migration.status !== 0) {
  throw new Error(`Local D1 migration failed with status ${migration.status ?? "unknown"}.`);
}

const worker = spawn(
  npx,
  [
    "wrangler",
    "dev",
    "--local",
    "--port",
    port,
    "--test-scheduled",
    "--log-level",
    "warn",
    "--var",
    "SYNC_TOKEN:local-test-token",
    "--var",
    "OWNER_PHONE:+15555550123",
    "--var",
    "OWNER_TIME_ZONE:America/Los_Angeles",
    "--var",
    "TWILIO_AUTH_TOKEN:integration-auth-token",
    "--var",
    "ALLOW_UNSIGNED_TWILIO:true",
  ],
  {
    env: process.env,
    stdio: ["ignore", "pipe", "pipe"],
  },
);

for (const stream of [worker.stdout, worker.stderr]) {
  stream.setEncoding("utf8");
  stream.on("data", (chunk) => {
    workerOutput.push(chunk);
    if (workerOutput.join("").length > 20_000) workerOutput.shift();
  });
}

try {
  await waitForHealth();

  const integration = spawnSync(
    process.execPath,
    ["test/integration.mjs"],
    {
      env: { ...process.env, TALI_BASE_URL: baseURL },
      stdio: "inherit",
    },
  );
  if (integration.status !== 0) {
    throw new Error(`Integration test failed with status ${integration.status ?? "unknown"}.`);
  }

  const scheduledURL = new URL("/__scheduled", baseURL);
  scheduledURL.searchParams.set("cron", "17 8 * * *");
  const scheduled = await fetch(scheduledURL);
  assert.equal(scheduled.ok, true, `Scheduled retention returned ${scheduled.status}.`);

  console.log("Managed Worker, D1, SMS, multi-user, and retention integration checks passed.");
} catch (error) {
  const output = workerOutput.join("").trim();
  if (output) console.error(`\nWorker output:\n${output}`);
  throw error;
} finally {
  worker.kill("SIGTERM");
  await Promise.race([
    once(worker, "exit"),
    delay(5_000).then(() => worker.kill("SIGKILL")),
  ]);
}

async function waitForHealth() {
  let lastError;
  for (let attempt = 0; attempt < 60; attempt += 1) {
    if (worker.exitCode !== null) {
      throw new Error(`Local Worker exited before becoming ready (${worker.exitCode}).`);
    }
    try {
      const response = await fetch(`${baseURL}/health`);
      if (response.ok) return;
      lastError = new Error(`Health check returned ${response.status}.`);
    } catch (error) {
      lastError = error;
    }
    await delay(250);
  }
  throw new Error(`Local Worker did not become ready: ${lastError?.message ?? "unknown error"}`);
}
