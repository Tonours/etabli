#!/usr/bin/env node
import { readFileSync } from "node:fs";

let payload;
try {
  payload = JSON.parse(readFileSync(0, "utf8"));
} catch {
  process.exit(0);
}

try {
  const { prBodyGuardDecision } = await import("../../workflow/runtime/pr-body-guard.mjs");
  const decision = prBodyGuardDecision(payload);
  if (decision) process.stdout.write(JSON.stringify(decision));
} catch (error) {
  process.stderr.write(`pr-body-guard: ${error?.message ?? error}; the command runs unchecked.\n`);
}
