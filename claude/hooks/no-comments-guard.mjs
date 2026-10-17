#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { noCommentsGuardDecision } from "../../workflow/runtime/no-comments-guard.mjs";

let payload;
try {
  payload = JSON.parse(readFileSync(0, "utf8"));
} catch {
  process.exit(0);
}

const decision = noCommentsGuardDecision(payload);
if (decision) process.stdout.write(JSON.stringify(decision));
