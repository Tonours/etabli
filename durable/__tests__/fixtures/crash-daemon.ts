import { writeFile } from "node:fs/promises";
import { randomUUID } from "node:crypto";
import { join } from "node:path";
import { createModels, type SimpleStreamOptions, type TranscriptContext } from "@earendil-works/pi-ai";
import { fauxProvider, fauxAssistantMessage, fauxToolCall } from "@earendil-works/pi-ai/providers/faux";
import { openCore, serve } from "../../src/daemon.ts";
import { OwnerPolicy } from "../../src/policy.ts";
import { Repositories } from "../../src/repositories.ts";
import { SharedCredentialStore } from "../../src/credentials.ts";

const [root, source] = process.argv.slice(2);
const state = join(root, "state");
const policy = new OwnerPolicy(["ForestAdmin"]);
const credentials = new SharedCredentialStore(join(root, "auth.json"));
if (!await credentials.read("fixture")) await credentials.modify("fixture", async () => ({ type: "api_key", key: `sk-test-${randomUUID()}` }));
const faux = fauxProvider({ provider: "fixture", models: [{ id: "fixture" }] });
faux.provider.auth.apiKey!.resolve = async ({ credential }) => ({ auth: { apiKey: credential?.key } });
const respond = async (input: TranscriptContext, options?: SimpleStreamOptions) => {
  await writeFile(join(root, "phase"), `generation:${process.pid}`);
  await new Promise<void>((resolve) => {
    const timer = setTimeout(resolve, 400);
    options?.signal?.addEventListener("abort", () => { clearTimeout(timer); resolve(); }, { once: true });
  });
  const calls = input.messages.filter((message) => message.role === "assistant").flatMap((message) => message.content.filter((block) => block.type === "toolCall"));
  if (calls.length >= 6) return fauxAssistantMessage("done");
  if (calls.length === 5) return fauxAssistantMessage(fauxToolCall("bash", { command: "printf 'finished\\n' > result.txt && bash check.sh && git add result.txt && git -c user.name=Fixture -c user.email=fixture@example.invalid commit -m 'test: finish durable fixture'" }, { id: "finish-fixture" }), { stopReason: "toolUse" });
  const index = calls.length;
  return fauxAssistantMessage(fauxToolCall("bash", { command: `printf '${index}\\n' >> unsafe-effects; printf 'tool:${process.pid}:%s' "$BASHPID" > '${join(root, "phase")}'; sleep 0.8; printf 'completed:${index}\\n'` }, { id: `unsafe-${index}` }), { stopReason: "toolUse" });
};
faux.setResponses(Array.from({ length: 100 }, () => respond));
const models = createModels({ credentials });
models.setProvider(faux.provider);
const core = await openCore({ state, policy, models, repositories: new Repositories(state, policy, () => source, async (repo) => repo), model: async () => ({ provider: "fixture", modelId: "fixture" }), restartLimit: 12, retry: { maxRetries: 12, baseDelayMs: 10 }, fatal: () => process.exit(1) });
await serve(core, state);
await writeFile(join(root, "ready"), String(process.pid));
setInterval(() => { void core.runs.tick().catch(() => process.exit(1)); }, 50);
