import { constants, openSync, closeSync, writeSync, readFileSync } from "node:fs";
import { performance } from "node:perf_hooks";
import { sha256 } from "./review-run-receipt.mjs";
import { observedPromptSources } from "./review-prompt-sources.mjs";

export function promptInventory(event, {origins = [], role = null} = {}) {
  const payload = event.type === "before_agent_start" ? { system: event.systemPrompt, input: event.prompt } : event.payload;
  if (!payload || typeof payload !== "object") return null;
  const allowed = ["system", "instructions", "messages", "input", "tools"];
  const blocks = allowed.filter((key) => payload[key] !== undefined).map((kind) => {
    const text = JSON.stringify(payload[kind]);
    return { kind, bytes: Buffer.byteLength(text), sha256: sha256(text), items: Array.isArray(payload[kind]) ? payload[kind].length : 1 };
  });
  const sources = observedPromptSources(Object.fromEntries(allowed.filter(key=>payload[key]!==undefined).map(key=>[key,payload[key]])), origins);
  return { schema_version: 1, stage: event.type, role, blocks, sources,
    provider: event.model?.provider ?? null, model: event.model?.id ?? payload.model ?? null,
    reasoning_effort: payload.reasoning_effort ?? payload.reasoning?.effort ?? null,
    source_coverage: sources.length && sources.every(source=>source.observed) ? "declared_sources_observed" : "unknown",
    implicit_obligations: "not_inferred", token_estimate: null, content: "not_recorded" };
}

export function parsePromptInventory(text) {
  const rows=[];
  let complete=true;
  for (const line of text.split("\n").filter(Boolean)) {
    try {
      const row=JSON.parse(line);
      if (!row || typeof row!=="object" || Array.isArray(row)) throw new Error("invalid inventory row");
      rows.push(row);
    } catch { complete=false; }
  }
  return {rows,complete};
}

export default function observePrompt(pi) {
  const target = process.env.ETABLI_REVIEW_PROMPT_INVENTORY;
  if (!target) return;
  const origins = process.env.ETABLI_REVIEW_PROMPT_SOURCES
    ? JSON.parse(readFileSync(process.env.ETABLI_REVIEW_PROMPT_SOURCES,"utf8")) : [];
  let callIndex = 0;
  const append = (inventory) => {
    const fd = openSync(target, constants.O_WRONLY | constants.O_APPEND | constants.O_NOFOLLOW);
    try { writeSync(fd, JSON.stringify(inventory)+"\n"); } finally { closeSync(fd); }
  };
  const record = (event, context) => {
    const inventory = promptInventory(event, {origins, role:process.env.ETABLI_REVIEW_ROLE});
    if (!inventory) return;
    inventory.provider = context?.model?.provider ?? inventory.provider;
    inventory.model = context?.model?.id ?? inventory.model;
    if (event.type === "before_provider_request") callIndex++;
    inventory.call_index = callIndex;
    inventory.observed_at_ms = performance.now();
    append(inventory);
    // Returning undefined preserves the exact payload and prompt.
  };
  pi.on("before_agent_start", record);
  pi.on("before_provider_request", record);
  pi.on("message_end", (event) => {
    if(event.message?.role === "assistant") append({schema_version:1,stage:"assistant_message_end",
      call_index:callIndex,observed_at_ms:performance.now()});
  });
}
