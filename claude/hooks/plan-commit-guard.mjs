import { planCommitGuardDecision, readHookInput } from "./workflow-router-lib.mjs";

const input = readHookInput();
const decision = planCommitGuardDecision(input);
if (decision) {
  process.stdout.write(`${JSON.stringify(decision)}\n`);
}
