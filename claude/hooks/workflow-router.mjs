import { classifyWorkflowRoute } from "../../workflow/runtime/workflow-router-core.mjs";
import { buildRouteContext, readHookInput, readPlanStatus, shouldInjectRouteContext } from "./workflow-router-lib.mjs";

const input = readHookInput();
const prompt = String(input.prompt || "");
let decision = null;
if (shouldInjectRouteContext(prompt)) {
  const route = classifyWorkflowRoute(prompt, { planStatus: readPlanStatus(input.cwd || process.cwd()) });
  if (route.route !== "answer") {
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
