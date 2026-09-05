// Normalize native receipts; task success is graded separately from model completion.
import { createHash } from "node:crypto";

const CLASSES = ["assistant", "child", "model_tool", "compaction", "retry"];
const isCount = (value) => Number.isSafeInteger(value) && value >= 0;
const isMoney = (value) => typeof value === "number" && Number.isFinite(value) && value >= 0;

export function normalizeEvents(runner, events, { exitCode = 0, coverage } = {}) {
  if (!["claude", "codex", "pi"].includes(runner)) throw new Error(`Unsupported runner: ${runner}`);
  const errors = [];
  const receipts = [];
  const models = new Set();
  const tools = new Map();
  let finalText = "";
  const triggered = new Set();
  const seen = new Set();
  let terminal = false;
  let failed = exitCode !== 0;
  let eventCount = 0;
  let codexTurn = null;
  let codexTurnCount = 0;
  let codexFatalError = false;
  const piIdentity = (message) => message.responseId ? `pi:provider:${message.responseId}`
    : message.id ? `pi:${message.id}`
    : `pi:anonymous:${createHash("sha256").update(JSON.stringify(message)).digest("hex")}`;

  function addReceipt(raw, format, source, key) {
    if (key && seen.has(key)) {
      errors.push(`Duplicate receipt identity: ${key}`);
      return;
    }
    if (key) seen.add(key);
    if (!raw || typeof raw !== "object") {
      errors.push(`Missing usage at ${source}`);
      return;
    }
    const input = raw[format === "pi" ? "input" : "input_tokens"];
    const output = raw[format === "pi" ? "output" : "output_tokens"];
    const cacheRead = raw[format === "pi" ? "cacheRead" : format === "claude" ? "cache_read_input_tokens" : "cached_input_tokens"];
    const cacheWrite = raw[format === "pi" ? "cacheWrite" : format === "claude" ? "cache_creation_input_tokens" : "cache_write_input_tokens"];
    // Codex cached counts are subsets of its total input. They are optional breakdowns.
    const required = format === "codex" ? [input, output] : [input, output, cacheRead, cacheWrite];
    if (!required.every(isCount) || [cacheRead, cacheWrite].some((n) => n !== undefined && !isCount(n))) {
      errors.push(`Incomplete/invalid token counts at ${source}`);
      return;
    }
    const totalInput = format === "codex" ? input : input + cacheRead + cacheWrite;
    const total = totalInput + output;
    if (total === 0) errors.push(`Zero-only usage is not a provider receipt at ${source}`);
    if (format === "codex" && ((cacheRead ?? 0) > input || (cacheWrite ?? 0) > input)) {
      errors.push(`Cached subset exceeds input at ${source}`);
    }
    if (format === "pi" && (!isCount(raw.totalTokens) || raw.totalTokens !== total)) {
      errors.push(`Pi total disagrees with disjoint token counts at ${source}`);
    }
    const reasoning = format === "pi" ? raw.reasoning
      : format === "codex" ? raw.reasoning_output_tokens
      : raw.output_tokens_details?.thinking_tokens;
    if (reasoning !== undefined && (!isCount(reasoning) || reasoning > output)) {
      errors.push(`Reasoning subset exceeds output at ${source}`);
    }
    receipts.push({ source, input_tokens: totalInput, output_tokens: output,
      total_tokens: total, cached_input_tokens: cacheRead ?? null,
      cache_write_input_tokens: cacheWrite ?? null, reasoning_output_tokens: reasoning ?? null,
      // Pi initializes prices to zero for custom models without pricing metadata.
      cost_usd: format === "pi" && isMoney(raw.cost?.total) && raw.cost.total > 0 ? raw.cost.total : null });
  }

  function call(id, name, args, extra = {}) {
    if (!id) { errors.push("Tool call has no native identity"); return; }
    tools.set(id, { ...(tools.get(id) ?? {}), id, name, arguments: args, ...extra });
  }
  function result(id, value, status) {
    if (!id) { errors.push("Tool result has no native identity"); return; }
    tools.set(id, { ...(tools.get(id) ?? { id }), result: value, status });
  }

  for (const [index, event] of events.entries()) {
    eventCount++;
    if (!event || typeof event !== "object" || typeof event.type !== "string") {
      errors.push(`Invalid native event at line ${index + 1}`);
      continue;
    }
    const source = `${runner}:line:${index + 1}:${event.type}`;
    if (/retry/.test(event.type)) triggered.add("retry");
    if (/compaction|branch_summary/.test(event.type)) triggered.add("compaction");
    if (event.parent_tool_use_id || event.subagent_stats?.spawned > 0) triggered.add("child");
    if (runner === "claude") {
      if (event.type === "system" && event.subtype === "init" && event.model) models.add(event.model);
      if (event.type === "assistant") {
        for (const block of event.message?.content ?? []) {
          if (block.type === "tool_use") call(block.id, block.name, block.input, { turn_id: event.message.id });
        }
      }
      if (event.type === "user") {
        for (const block of event.message?.content ?? []) {
          if (block.type === "tool_result") result(block.tool_use_id, block.content, block.is_error ? "error" : "success");
        }
      }
      if (event.type === "result") {
        if (terminal) errors.push("Multiple Claude cumulative results in one cell");
        terminal = true;
        triggered.add("assistant");
        failed ||= event.is_error === true || event.subtype !== "success";
        addReceipt(event.usage, "claude", source, "claude:result");
        for (const name of Object.keys(event.modelUsage ?? {})) models.add(name);
        if (receipts.length && isMoney(event.total_cost_usd)) receipts.at(-1).cost_usd = event.total_cost_usd;
        if (typeof event.result === "string") finalText = event.result;
      }
    } else if (runner === "codex") {
      if (event.type === "turn.started") {
        if (codexTurn !== null) errors.push("Codex started a turn before closing its previous turn");
        codexTurn = ++codexTurnCount;
        terminal = false;
      }
      if (event.type === "turn.completed") {
        if (codexTurn === null && !event.turn_id) errors.push("Anonymous Codex completion has no open turn");
        terminal = true;
        // Native reconnect errors can precede a successful terminal turn.
        // Earlier failed usage remains in receipts/errors and cannot disappear.
        failed = exitCode !== 0 || codexFatalError;
        triggered.add("assistant");
        addReceipt(event.usage, "codex", source, `codex:${event.turn_id ?? `ordinal-${codexTurn}`}`);
        codexTurn = null;
      }
      if (event.type === "turn.failed") {
        terminal = true;
        // The native CLI can omit charged usage on failure; omission is not zero.
        addReceipt(event.usage, "codex", source, `codex:${event.turn_id ?? `ordinal-${codexTurn}`}`);
        codexTurn = null;
      }
      if (["turn.failed", "error"].includes(event.type)) failed = true;
      if (event.type === "error") {
        if (/^Reconnecting\.\.\. [1-9]\d*\/[1-9]\d*(?: \(.+\))?$/.test(event.message ?? "")) triggered.add("retry");
        else codexFatalError = true;
      }
      const item = event.item;
      if (event.type === "item.completed" && item?.type === "agent_message") finalText = item.text;
      if (item?.type === "collab_tool_call") triggered.add("child");
      if (["item.started", "item.completed"].includes(event.type) && item &&
          ["command_execution", "mcp_tool_call", "collab_tool_call", "web_search", "file_change"].includes(item.type)) {
        call(item.id, item.tool ?? item.type, item.arguments ?? { command: item.command, changes: item.changes, query: item.query },
          { result: item.aggregated_output ?? item.result, status: item.status, turn_id: event.turn_id });
      }
    } else {
      // Other Pi event types contain copies of these messages, not additional calls.
      if (event.type === "message_end") {
        const message = event.message;
        if (message?.role === "assistant") {
          terminal = false;
          triggered.add("assistant");
          if (message.provider && message.model) models.add(`${message.provider}/${message.model}`);
          if (["stop", "error", "aborted", "length"].includes(message.stopReason)) {
            terminal = true;
            failed = exitCode !== 0 || message.stopReason !== "stop";
          }
          addReceipt(message.usage, "pi", source, piIdentity(message));
          if (message.stopReason === "stop") finalText = (message.content ?? [])
            .filter((block) => block.type === "text").map((block) => block.text).join("\n");
          for (const block of message.content ?? []) {
            if (block.type === "toolCall") call(block.id, block.name, block.arguments, { turn_id: message.id });
          }
        }
        if (message?.role === "toolResult") {
          result(message.toolCallId, message.content, message.isError ? "error" : "success");
          if (message.usage) {
            triggered.add("model_tool");
            addReceipt(message.usage, "pi", source, piIdentity(message));
          }
        }
      }
      if (event.type === "compaction_end") addReceipt(event.result?.usage, "pi", source, event.id ? `pi:${event.id}` : undefined);
    }
  }
  if (!terminal) errors.push("No native terminal event");
  if (!receipts.length) errors.push("No native provider usage receipts");
  if (runner === "codex") {
    // The observed native CLI emits usage but no effective provider/model.
    // Keep receipt diagnostics; arbitrary metadata cannot certify the cell.
    errors.push("Codex effective provider/model provenance is not captured by this adapter");
  }
  if (!models.size) errors.push("Effective model provenance missing from provider evidence");
  for (const name of CLASSES) {
    const entry = coverage?.[name];
    if (!entry || !["complete", "not_triggered"].includes(entry.status) || !entry.evidence) {
      errors.push(`Call-class coverage unproven: ${name}`);
    } else if (triggered.has(name) && entry.status === "not_triggered") {
      errors.push(`Coverage contradicts observed ${name} invocation`);
    }
  }
  const sum = (key) => receipts.every((receipt) => receipt[key] !== null)
    ? receipts.reduce((total, receipt) => total + receipt[key], 0) : null;
  const keys = ["input_tokens", "output_tokens", "total_tokens", "cached_input_tokens", "cache_write_input_tokens", "reasoning_output_tokens", "cost_usd"];
  const complete = errors.length === 0;
  return { schema_version: 1, runner, event_count: eventCount, transport_success: terminal && !failed,
    measured: complete, measurement_errors: errors, models: [...models], coverage: coverage ?? null,
    usage: Object.fromEntries(keys.map((key) => [key, complete ? sum(key) : null])),
    receipts, final_text: typeof finalText === "string" ? finalText : "", tools: [...tools.values()] };
}

export function summarizeRuns(rows) {
  const groups = new Map();
  const ids = new Set();
  for (const row of rows) {
    if (!row.id || ids.has(row.id)) throw new Error(`Missing/duplicate run identity: ${row.id}`);
    ids.add(row.id);
    if (!["claude", "codex", "pi"].includes(row.runner) || !["baseline", "candidate"].includes(row.arm)) {
      throw new Error(`Invalid population arm for ${row.id}`);
    }
    if (row.normalized && row.normalized.runner !== row.runner) {
      throw new Error(`Normalized runner disagrees with population for ${row.id}`);
    }
    if (row.grade?.success === true && row.grade?.critical_failure === true) {
      throw new Error(`Contradictory success and critical failure for ${row.id}`);
    }
    const key = `${row.runner}/${row.arm}`;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(row);
  }
  return [...groups].map(([group, cells]) => {
    const successes = cells.filter((cell) => cell.grade?.success === true &&
      cell.grade?.critical_failure === false && cell.normalized?.transport_success === true &&
      (cell.delivery === undefined || cell.delivery?.effective_success === true)).length;
    const complete = cells.every((cell) => cell.normalized?.measured === true &&
      isCount(cell.normalized.usage?.total_tokens) && typeof cell.grade?.success === "boolean" &&
      typeof cell.grade?.critical_failure === "boolean" &&
      typeof cell.normalized.transport_success === "boolean" &&
      (cell.delivery === undefined || typeof cell.delivery?.effective_success === "boolean"));
    const total = complete ? cells.reduce((sum, cell) => sum + cell.normalized.usage.total_tokens, 0) : null;
    return { group, attempts: cells.length, successes, measured: complete,
      total_tokens: total, tokens_per_success: complete && successes ? total / successes : null,
      critical_failures: cells.filter((cell) => cell.grade?.critical_failure === true).length,
      status: complete ? "measured_population_only" : "inconclusive" };
  });
}
