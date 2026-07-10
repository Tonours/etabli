import { classifyWorkflowRoute } from "../../workflow/runtime/workflow-router-core.mjs";
import { resolveDynamicKnowledgeContext } from "../../workflow/runtime/obvault-topic-resolver.mjs";
import { buildRouteContext, readHookInput, readPlanStatus, shouldInjectRouteContext } from "./workflow-router-lib.mjs";

const input = readHookInput();
const prompt = String(input.prompt || "");
let decision = null;
if (shouldInjectRouteContext(prompt)) {
  const planStatus = readPlanStatus(input.cwd || process.cwd());
  let route = classifyWorkflowRoute(prompt, { planStatus });
  if (!route.knowledgeContext) {
    route = classifyWorkflowRoute(prompt, {
      planStatus,
      dynamicKnowledgeContext: resolveDynamicKnowledgeContext(prompt),
    });
  }
  if (route.route !== "answer" || route.knowledgeContext) {
    decision = {
      hookSpecificOutput: {
        hookEventName: "UserPromptSubmit",
        additionalContext: buildRouteContext(route),
      },
    };
  }
}

if (decision) {
  process.stdout.write(`${JSON.stringify(decision)}\n`);
}
