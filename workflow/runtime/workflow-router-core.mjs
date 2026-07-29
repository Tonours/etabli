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
  proposedPlanTextFromToolInput,
  isMutatingBashCommand,
  isPlanFile,
  normalizeToolName,
  readPlanStatus,
} from "../../claude/hooks/workflow-router-lib.mjs";
