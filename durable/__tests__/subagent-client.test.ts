import { expect, test } from "bun:test";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { fauxProvider, fauxAssistantMessage, fauxToolCall } from "@earendil-works/pi-ai/providers/faux";
import { type ConversationView } from "@earendil-works/pi-durable";
import { serve, type ApiServer } from "../src/api.ts";
import { request, watchRun } from "../src/client.ts";
import { ChildOwnerDoc } from "../src/guards.ts";
import { fixture, until } from "./helpers.ts";

for (const operation of ["abort", "reopen"] as const) test(`S5 client watch and ${operation} retain native worker ownership`, async () => {
  const f = await fixture({ subagentModel: async () => ({ provider: "child", modelId: "child" }) });
  const child = fauxProvider({ provider: "child", models: [{ id: "child" }] });
  f.models.setProvider(child.provider);
  let entered = false;
  child.setResponses([async (_input, options) => {
    entered = true;
    await new Promise<void>((resolve) => { if (options?.signal?.aborted) resolve(); else options?.signal?.addEventListener("abort", () => resolve(), { once: true }); });
    return fauxAssistantMessage("interrupted child");
  }]);
  f.faux.setResponses([fauxAssistantMessage(fauxToolCall("worker", { task: "wait for owner" }), { stopReason: "toolUse" })]);
  let api: ApiServer | undefined = await serve(f.core, f.state);
  const controller = new AbortController();
  const views: ConversationView[] = [];
  let closed = false;
  try {
    const run = await request(f.state, { op: "run", repo: "Tonours/fixture", prompt: "S5 child lifecycle", requestId: `s5-child-${operation}` }) as { id: string; conversationId: import("@earendil-works/pi-durable").ConversationId };
    await watchRun(f.state, run.id, undefined, undefined, controller.signal, (value) => { views.push(value); }, () => { closed = true; });
    await f.core.runs.tick();
    await until(async () => entered && views.some((value) => JSON.stringify(value).includes("worker")));
    const original = (await f.core.harness.commit((tx) => tx.scanConversations({ ownerConversationId: run.conversationId }, 10), context)).items;
    expect(original).toHaveLength(1);
    expect(original[0]!.owner?.taskId).toBeDefined();
    if (operation === "abort") {
      const graph = await f.core.harness.watchTaskGraph(context);
      graph.start(async () => {});
      try {
        expect(await request(f.state, { op: "abort", id: run.id })).toEqual({ aborted: true });
        await until(async () => Object.keys(graph.value.tasks).length === 0);
        expect((await f.core.runs.show(run.id)).status).toBe("aborted");
      } finally { await graph.stop(); }
    } else {
      await api.shutdown(); api = undefined;
      await until(async () => closed);
      expect((await f.core.runs.show(run.id)).status).toBe("implementing");
      child.setResponses([fauxAssistantMessage("child resumed")]);
      f.faux.setResponses([fauxAssistantMessage("parent resumed")]);
      await f.reopen();
      await f.core.harness.waitForIdle(context);
      const recovered = (await f.core.harness.commit((tx) => tx.scanConversations({ ownerConversationId: run.conversationId }, 10), context)).items;
      expect(recovered.map((record) => record.id)).toEqual(original.map((record) => record.id));
      expect((await f.core.harness.snapshot(ChildOwnerDoc, recovered[0]!.id, context))?.parentId).toBe(run.conversationId);
      const transcript = (await (await f.core.harness.conversation(run.conversationId, context))!.entries({}, 100, undefined, context)).items;
      expect(JSON.stringify(transcript)).toContain("child resumed");
      const graph = await f.core.harness.watchTaskGraph(context);
      try { expect(Object.keys(graph.value.tasks)).toHaveLength(0); } finally { await graph.stop(); }
    }
  } finally {
    controller.abort();
    await api?.shutdown();
    await f.cleanup();
  }
});
