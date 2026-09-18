// Canonical deterministic classifier. Host adapters must import from here.
export {
  buildAutonomousPlanChain,
  classifyKnowledgeContext,
  classifyWorkflowRoute,
  planReadyGuardDecision,
  planCheckFreezeGuardDecision,
  planCheckFreezeBashGuardDecision,
  planNoProgressGuardDecision,
  planMutationGuardDecision,
  planCommitGuardDecision,
  proposedPlanTextFromToolInput,
  isMutatingBashCommand,
  isPlanFile,
  normalizeToolName,
  isMutationRelevantTool,
  readPlanStatus,
} from "../../claude/hooks/workflow-router-lib.mjs";
export { parsePlanStatus } from "../../scripts/lib/plan-check-freeze.mjs";
