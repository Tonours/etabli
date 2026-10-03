import assert from "node:assert/strict";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
const [phase] = process.argv.slice(2);
const root = process.env.ETABLI_RUN_DIR;
assert.ok(
  root && process.cwd() === process.env.ETABLI_SUBJECT_ROOT,
  "Use owned source/runtime",
);
if (phase === "launch")
  writeFileSync(
    join(root, "state.json"),
    JSON.stringify({ value: "initial" }) + "\n",
  );
else if (phase === "doctor") {
  assert.ok(existsSync(join(root, "state.json")));
  JSON.parse(readFileSync(join(root, "state.json")));
} else if (phase === "cleanup") assert.ok(existsSync(root));
else assert.fail("Unknown lifecycle phase");
console.log(JSON.stringify({ phase, ok: true }));
