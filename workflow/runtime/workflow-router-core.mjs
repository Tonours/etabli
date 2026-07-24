// Canonical deterministic classifier. Host adapters must import from here.
export {
  buildAutonomousPlanChain,
  classifyKnowledgeContext,
  classifyWorkflowRoute,
  planReadyGuardDecision,
  isMutatingBashCommand,
  isPlanFile,
  normalizeToolName,
  readPlanStatus,
} from "../../claude/hooks/workflow-router-lib.mjs";
