import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { obj, str } from "@earendil-works/pi-schema";
import { configure, defineExtension, defineTool, type Extension, type ModelRef } from "@earendil-works/pi-durable";
import { CodingTools, createReadTool } from "@earendil-works/pi-durable/tools";
import { phaseModel, EtabliPlanDoc } from "./plan-doc.ts";
import { active, RunsDoc } from "./runs-doc.ts";

export type SubagentRole = "scout" | "worker";

export async function subagentModel(checkout: string, role: SubagentRole): Promise<ModelRef> {
  if (role === "worker") return phaseModel(checkout, "implementer");
  const routes = JSON.parse(await readFile(join(checkout, "workflow/runtime/model-routing.json"), "utf8")) as {
    models: Record<string, { provider?: string; model?: string; family?: string }>;
    durable: { native_routes: Record<string, { provider: string }> };
  };
  const scout = routes.models.glm_flash;
  if (!scout?.model || scout.provider !== "zai" || scout.family !== "zai" || !Object.values(routes.durable.native_routes).some((route) => route.provider === scout.provider)) throw new Error("Native scout model route is unavailable");
  return { provider: scout.provider, modelId: scout.model };
}

export function createSubagentsExtension(checkout: string, guard: Extension, model: (role: SubagentRole) => Promise<ModelRef> = (role) => subagentModel(checkout, role)) {
  return defineExtension({ name: "etabli-subagents", tools: (["scout", "worker"] as const).map((role) => defineTool({
    name: role,
    description: role === "scout" ? "Delegate a bounded read-only investigation to the canonical cheap native model; return its answer." : "Delegate a bounded implementation task to the canonical native implementer. Requires an active run and READY when a plan is enabled; returns its answer.",
    parameters: obj({ task: str({ minLength: 1, maxLength: 32_000 }) }), replay: "safe",
    async execute(args, api, context) {
      const route = await model(role);
      const id = await api.commit(async (tx) => {
        const run = (await tx.doc(RunsDoc)).runs.find((row) => row.conversationId === api.conversationId);
        if (!run || !active(run)) throw new Error("Subagent requires an active root run");
        const plan = await tx.doc(EtabliPlanDoc, run.conversationId);
        if (role === "worker" && plan.enabled && plan.status !== "READY") throw new Error("Worker requires parent plan READY");
        const existing = (await tx.scanConversations({ ownerTaskId: api.taskId }, 1)).items[0];
        if (existing) return existing.id;
        const child = await tx.createConversation({ ownership: { kind: "task", taskId: api.taskId } });
        const tools = role === "scout" ? [createReadTool()] : [...(CodingTools.tools ?? [])];
        await configure(tx, child.id, { cwd: run.worktree, model: route, extensions: [CodingTools, guard], tools, modelTools: tools, maxTurns: 32, compaction: { enabled: false } });
        return child.id;
      }, context);
      await api.details({ conversationId: id }, context);
      const child = await api.conversation(id, context);
      if (!child) throw new Error("Subagent conversation is missing");
      const result = await (await child.submit({ type: "input", content: args.task, requestId: `subagent:${api.taskId}` }, context)).wait(context);
      if (result.status !== "done" || result.answer === undefined) throw new Error(`Subagent did not finish: ${result.status}`);
      const answerId = result.answer;
      const entry = await api.commit((tx) => tx.entry(answerId), context);
      const answer = (entry?.model ?? []).flatMap((message) => message.role === "assistant" ? message.content.flatMap((part) => part.type === "text" ? [part.text] : []) : []).join("\n");
      if (!answer) throw new Error("Subagent returned no answer");
      return { output: [{ type: "text", text: answer.slice(0, 32_000) }] };
    },
  })) });
}
