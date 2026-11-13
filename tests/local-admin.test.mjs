import assert from "node:assert/strict";
import test from "node:test";

import {
  LOCAL_ADMIN_HEADER,
  canIssueLocalAdminToken,
  getLocalAdminToken,
  isAuthorizedLocalAdminRequest,
} from "../dist/http/local-admin.js";
import { requiresLocalAdmin } from "../dist/http/router.js";

function request({ address = "127.0.0.1", host = "127.0.0.1:16384", origin, fetchSite, token } = {}) {
  return {
    socket: { remoteAddress: address },
    headers: {
      host,
      ...(origin ? { origin } : {}),
      ...(fetchSite ? { "sec-fetch-site": fetchSite } : {}),
      ...(token ? { [LOCAL_ADMIN_HEADER]: token } : {}),
    },
  };
}

test("local admin token is issued only to same-origin loopback requests", () => {
  assert.equal(canIssueLocalAdminToken(request({ fetchSite: "same-origin" })), true);
  assert.equal(canIssueLocalAdminToken(request({ origin: "http://127.0.0.1:16384" })), true);
  assert.equal(canIssueLocalAdminToken(request({ origin: "https://attacker.example", fetchSite: "cross-site" })), false);
  assert.equal(canIssueLocalAdminToken(request({ host: "attacker.example:16384", origin: "http://attacker.example:16384", fetchSite: "same-origin" })), false);
  assert.equal(canIssueLocalAdminToken(request({ address: "192.168.1.20" })), false);
  assert.equal(canIssueLocalAdminToken(request({ address: "::1", host: "[::1]:16384", origin: "http://[::1]:16384" })), true);
});

test("router protects dashboard mutations without blocking relay APIs", () => {
  for (const pathname of ["/api/tool", "/api/tool-progress", "/api/windows", "/api/screenshot"]) {
    assert.equal(requiresLocalAdmin({ method: "POST" }, pathname), false, `${pathname} must remain available to relays`);
  }

  for (const pathname of [
    "/api/client-setup",
    "/api/dashboard-settings",
    "/api/decompiler-settings",
    "/api/decompiler-settings/connector",
    "/api/decompiler-settings/setup",
    "/api/semantic-settings",
    "/api/semantic-settings/test",
  ]) {
    assert.equal(requiresLocalAdmin({ method: "POST" }, pathname), true, `${pathname} must require dashboard authorization`);
  }

  assert.equal(requiresLocalAdmin({ method: "GET" }, "/api/scripts/source"), false);
  assert.equal(requiresLocalAdmin({ method: "PUT" }, "/api/scripts/source"), true);
  assert.equal(requiresLocalAdmin({ method: "GET" }, "/api/server-logs"), false);
  assert.equal(requiresLocalAdmin({ method: "DELETE" }, "/api/server-logs"), true);
  // Setup actions are machine-level mutations: only the local dashboard (same
  // loopback + in-process token) may POST them, even behind a reverse proxy.
  // GET stays public so hosted dashboards (Railway) can render the Connect modal.
  assert.equal(requiresLocalAdmin({ method: "GET" }, "/api/client-setup"), false);
  assert.equal(requiresLocalAdmin({ method: "POST" }, "/api/client-setup"), true);
  assert.equal(requiresLocalAdmin({ method: "PUT" }, "/api/client-setup"), false);
});

test("local admin API requests require the in-process token", () => {
  const token = getLocalAdminToken();
  assert.equal(isAuthorizedLocalAdminRequest(request({ fetchSite: "same-origin", token })), true);
  assert.equal(isAuthorizedLocalAdminRequest(request({ fetchSite: "same-origin", token: "wrong" })), false);
  assert.equal(isAuthorizedLocalAdminRequest(request({ fetchSite: "cross-site", token })), false);
});
