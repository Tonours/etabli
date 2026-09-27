import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
const root = join(import.meta.dir, "../../..");
process.env.OBVAULT_ROOT = "/nonexistent-obvault-for-bench";
const mod = await import(join(root, "pi/extensions/workflow-router.ts"));
const handlers = new Map<string, Function[]>();
const pi = {
  on(n: string, h: Function) { handlers.set(n, [...(handlers.get(n) ?? []), h]); },
  getActiveTools() { return ["Agent"]; },
  appendEntry() {}, registerEntryRenderer() {}, getThinkingLevel() { return undefined; }, setThinkingLevel() {},
};
mod.default(pi);
const dir = join(root, "tests/router-evals");
const prompts: string[] = [];
for (const f of readdirSync(dir).filter((f) => f.endsWith(".json")).sort()) {
  for (const c of JSON.parse(readFileSync(join(dir, f), "utf8"))) if (typeof c.prompt === "string") prompts.push(c.prompt);
}
const BASE = "BASE-SYSTEM-PROMPT";
let sysMutations = 0, prefixBreaks = 0, messages = 0, messageChars = 0;
let prev = BASE;
for (const prompt of prompts) {
  const r = (handlers.get("before_agent_start") ?? []).map((h) => h({ prompt, systemPrompt: BASE, cwd: "/tmp" }, {}))[0] as any;
  const sys = r?.systemPrompt ?? BASE;
  if (sys !== BASE) sysMutations++;
  if (sys !== prev) prefixBreaks++;
  prev = sys;
  if (r?.message) { messages++; const c = r.message.content; messageChars += typeof c === "string" ? c.length : JSON.stringify(c).length; }
}
console.log(`pi_router_turns=${prompts.length}`);
console.log(`pi_router_system_prompt_mutations=${sysMutations}`);
console.log(`pi_router_cache_prefix_breaks=${prefixBreaks}`);
console.log(`pi_router_context_messages=${messages}`);
console.log(`pi_router_context_message_chars=${messageChars}`);
