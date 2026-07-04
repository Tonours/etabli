import { planReadyGuardDecision, readHookInput } from "./workflow-router-lib.mjs";

const input = readHookInput();
const decision = planReadyGuardDecision(input);

if (decision) {
  process.stdout.write(`${JSON.stringify(decision)}\n`);
}
