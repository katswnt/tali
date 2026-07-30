import http from "k6/http";
import { check } from "k6";

const baseURL = (__ENV.TALI_BASE_URL || "").replace(/\/$/, "");
const bearerToken = __ENV.TALI_BEARER_TOKEN || "";

if (!baseURL) {
  throw new Error("Set TALI_BASE_URL to the staging Worker URL.");
}

export const options = {
  scenarios: {
    steady_read_traffic: {
      executor: "constant-vus",
      vus: Number(__ENV.TALI_VUS || 10),
      duration: __ENV.TALI_DURATION || "60s",
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<500", "p(99)<1000"],
    checks: ["rate>0.99"],
  },
};

export default function () {
  const health = http.get(`${baseURL}/health`, { tags: { route: "health" } });
  check(health, {
    "health returns 200": (response) => response.status === 200,
  });

  if (bearerToken) {
    const account = http.get(`${baseURL}/v1/account`, {
      headers: { Authorization: `Bearer ${bearerToken}` },
      tags: { route: "account" },
    });
    check(account, {
      "authorized account returns 200": (response) => response.status === 200,
    });
  }
}
