import { readHookInput, userPromptSubmitDecision } from "./workflow-router-lib.mjs";

const input = readHookInput();
const decision = userPromptSubmitDecision(input);

if (decision) {
  process.stdout.write(`${JSON.stringify(decision)}\n`);
}
