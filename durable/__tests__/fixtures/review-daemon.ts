import { writeFile, stat } from "node:fs/promises";
import { join } from "node:path";
import { createModels, type SimpleStreamOptions, type TranscriptContext } from "@earendil-works/pi-ai";
import { fauxProvider, fauxAssistantMessage, fauxToolCall } from "@earendil-works/pi-ai/providers/faux";
import { openCore, serve } from "../../src/daemon.ts";
import { OwnerPolicy } from "../../src/policy.ts";
import { Repositories } from "../../src/repositories.ts";

const [root, source] = process.argv.slice(2);
const state = join(root, "state");
const exists = (name: string) => stat(join(root, name)).then(() => true, () => false);
const implementer = fauxProvider({ provider: "zai", models: [{ id: "glm-5.3" }] });
const reviewer = fauxProvider({ provider: "openai-codex", models: [{ id: "gpt-6.1-sol" }, { id: "gpt-6-astra" }] });
const respond = async (input: TranscriptContext) => {
  if (await exists("released-review") && !await exists("after-restart")) {
    await writeFile(join(root, "after-restart"), String(process.pid));
    while (!await exists("resume-parent")) await new Promise((resolve) => setTimeout(resolve, 10));
  }
  const called = input.messages.some((message) => message.role === "assistant" && message.content.some((part) => part.type === "toolCall"));
  return fauxAssistantMessage(called ? fauxToolCall("review", { kind: "code" }) : fauxToolCall("bash", { command: "printf fixture > result.txt" }), { stopReason: "toolUse" });
};
implementer.setResponses(Array.from({ length: 20 }, () => respond));
reviewer.setResponses(Array.from({ length: 40 }, () => async (input: TranscriptContext, options?: SimpleStreamOptions) => {
  const axis = /Axis: (\w+)/.exec(JSON.stringify(input.messages))?.[1];
  if (axis === "spec" && !await exists("released-review")) {
    await writeFile(join(root, "review-pending"), String(process.pid));
    while (!await exists("released-review")) { options?.signal?.throwIfAborted(); await new Promise((resolve) => setTimeout(resolve, 10)); }
  }
  const tables = axis === "logic" ? "### Lens table\n| Lens | Checked (file:line) | Found |\n| precedence | result.txt:1 | no |\n### Deciding-code table\n| Changed behavior | Deciding code opened (file:line) | Sibling / resolver | Result |\n| result | result.txt:1 | none | pass |\n" : axis === "threat" ? ["Deciding inputs", "Entry-point inventory", "Reused guards", "Deferrals", "Rollout", "Attack tests"].map((heading) => `### ${heading}\nnone: fixture\n`).join("") : "";
  return fauxAssistantMessage(`Findings\nNo findings.\n${tables}Verdict: ${axis === "logic" || axis === "adversary" ? "BLOCK" : "GO"}\nSTATUS: complete`);
}));
const models = createModels();
models.setProvider(implementer.provider); models.setProvider(reviewer.provider);
const policy = new OwnerPolicy(["ForestAdmin"]);
const core = await openCore({ state, policy, models, workflow: true, model: async () => ({ provider: "zai", modelId: "glm-5.3" }), repositories: new Repositories(state, policy, () => source, async (repo) => repo), restartLimit: 12 });
await serve(core, state);
await writeFile(join(root, "ready"), String(process.pid));
let ticking = false;
setInterval(() => { if (ticking) return; ticking = true; void core.runs.tick().catch(() => process.exit(1)).finally(() => { ticking = false; }); }, 20);
