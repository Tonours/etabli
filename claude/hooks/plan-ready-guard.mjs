import {
  planCommitGuardDecision,
  planMutationGuardDecision,
  readHookInput,
} from "./workflow-router-lib.mjs";

const input = readHookInput();
// READY mutation gate + check-freeze on PLAN.md writes (shared core).
const decision = planMutationGuardDecision(input) || planCommitGuardDecision(input);

if (decision) {
  process.stdout.write(`${JSON.stringify(decision)}\n`);
}
