import { readFileSync } from "node:fs";
import { planReadyGuardDecision } from "./workflow-router-lib.mjs";

const input = JSON.parse(readFileSync(0, "utf8") || "{}");
const decision = planReadyGuardDecision(input);

if (decision) {
  process.stdout.write(`${JSON.stringify(decision)}\n`);
}
