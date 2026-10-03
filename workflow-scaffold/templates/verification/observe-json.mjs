#!/usr/bin/env node
import assert from "node:assert/strict";
import { readFileSync, realpathSync } from "node:fs";
import { join, sep } from "node:path";
const [file, ...extra] = process.argv.slice(2);
assert.ok(
  file &&
    !extra.length &&
    !file.split(/[\\/]/).includes("..") &&
    !file.startsWith("/"),
  "Use a relative JSON filename under ETABLI_RUN_DIR",
);
const root = realpathSync(process.env.ETABLI_RUN_DIR);
const path = realpathSync(join(root, file));
assert.ok(
  path.startsWith(root + sep),
  "Observation must belong to owned runtime",
);
const bytes = readFileSync(path);
JSON.parse(bytes);
process.stdout.write(bytes);
