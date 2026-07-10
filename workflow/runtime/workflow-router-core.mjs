// Canonical deterministic classifier. Host adapters must import from here.
export {
  buildAutonomousPlanChain,
  classifyKnowledgeContext,
  classifyWorkflowRoute,
} from "../../claude/hooks/workflow-router-lib.mjs";
