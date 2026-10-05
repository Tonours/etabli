import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { setTimeout as delay } from "node:timers/promises";
const file = join(process.env.ETABLI_RUN_DIR, "url.json"),
  deadline = Date.now() + 15000;
let ok = false;
while (Date.now() < deadline) {
  try {
    if (existsSync(file)) {
      const { url } = JSON.parse(readFileSync(file));
      const response = await fetch(url + "/state", {
        signal: AbortSignal.timeout(1000),
      });
      ok = response.ok;
      if (ok) break;
    }
  } catch {}
  await delay(50);
}
assert.ok(ok, "Owned web application unavailable");
console.log(JSON.stringify({ ready: true }));
