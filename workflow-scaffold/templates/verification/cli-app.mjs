import assert from "node:assert/strict";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
const path = join(process.env.ETABLI_RUN_DIR, "state.json");
const [command, value] = process.argv.slice(2);
if (command === "write") {
  writeFileSync(path, JSON.stringify({ value }) + "\n");
  console.log("saved");
} else if (command === "read") process.stdout.write(readFileSync(path));
else if (command === "wrong-result")
  console.log(JSON.stringify({ value: "wrong-result" }));
else assert.fail("Unknown CLI application command");
