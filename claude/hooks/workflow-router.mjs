import { readFileSync } from "node:fs";
import { userPromptSubmitDecision } from "./workflow-router-lib.mjs";

const input = JSON.parse(readFileSync(0, "utf8") || "{}");
const decision = userPromptSubmitDecision(input);

if (decision) {
  process.stdout.write(`${JSON.stringify(decision)}\n`);
}
