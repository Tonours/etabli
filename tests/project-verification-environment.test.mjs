import assert from "node:assert/strict";
import { test } from "node:test";
import { verificationEnvironment } from "../scripts/lib/project-verification-process.mjs";

test("verification environment forwards the runner tracking id", () => {
  const environment = verificationEnvironment({
    PATH: "/usr/bin",
    RUNNER_TRACKING_ID: "github_0f3c",
    ZAI_API_KEY: "secret",
    GITHUB_TOKEN: "token",
  });
  assert.deepEqual(environment, { PATH: "/usr/bin", RUNNER_TRACKING_ID: "github_0f3c" });
});

test("verification environment omits an absent runner tracking id", () => {
  assert.deepEqual(verificationEnvironment({ PATH: "/usr/bin" }), { PATH: "/usr/bin" });
});
