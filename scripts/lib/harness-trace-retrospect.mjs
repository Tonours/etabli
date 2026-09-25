import { closeSync, constants, fstatSync, openSync, readFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { resolve } from "node:path";
import { WORKFLOW_EVENTS } from "./workflow-events.mjs";
import { createPiRunBinding, isPiRunBinding, PI_RUN_BINDING_TYPE } from "./pi-run-binding.mjs";

export const TRACE_OBSERVATION_SCHEMA_VERSION = 1;
export const TRACE_ADAPTER_VERSION = "prototype-offline-1";
export const TRACE_CAPABILITY = "prototype_offline";
const MAX_BYTES = 4 * 1024 * 1024;
const MAX_ROWS = 20_000;
const MAX_TOKEN_COUNT = 1_000_000_000;
const TERMINALS = new Set(["completed", "blocked", "ship_completed"]);
const CAPABILITIES = new Set([TRACE_CAPABILITY, "diagnose_shadow", "propose_reviewed", "promote_automatic"]);
const ADAPTERS = new Set(["pi", "claude"]);
const ROUTES = new Set(["answer", "plan-loop", "implement", "plan-implement", "review", "verify", "adversary", "research-plan", "ops-stop", "ci-fix", "goal"]);
const LEDGER_EVENTS = new Set(WORKFLOW_EVENTS);
const PLAN_STATUSES = new Set(["DRAFT", "CHALLENGED", "READY"]);
const ADVERSARY_MODES = new Set(["plan", "code_diff"]);
const REVIEW_STATUSES = new Set(["GO", "GO WITH NOTES", "BLOCK"]);
const QUALITY_STATUSES = new Set(["pass", "unavailable"]);
const DECISION_LEDGER_EVENTS = new Set(["route_decided", "plan_created", "adversary_completed", "review_completed", "quality_completed", "validation_run", "validation_failed", "completed", "blocked"]);

export class TraceRetrospectError extends Error {
  constructor(code) {
    super(code);
    this.code = code;
  }
}

function fail(code) {
  throw new TraceRetrospectError(code);
}

export function validateTraceRequest({ adapter, run, capability = TRACE_CAPABILITY }) {
  if (!CAPABILITIES.has(capability)) fail("invalid_capability");
  if (capability !== TRACE_CAPABILITY) fail("capability_not_available");
  if (!ADAPTERS.has(adapter)) fail("invalid_adapter");
  if (typeof run !== "string" || !/^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$/.test(run)) fail("invalid_run");
}

function sameFile(left, right) {
  return left.dev === right.dev && left.ino === right.ino && left.size === right.size && left.mtimeMs === right.mtimeMs;
}

export function readBoundedRegularFile(path, options = {}) {
  const maxBytes = options.maxBytes ?? MAX_BYTES;
  let descriptor;
  try {
    descriptor = openSync(resolve(path), constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
    const before = fstatSync(descriptor);
    if (!before.isFile()) fail("input_not_regular");
    if (before.size > maxBytes) fail("input_too_large");
    const text = readFileSync(descriptor, "utf8");
    options.afterRead?.();
    const after = fstatSync(descriptor);
    if (!after.isFile() || !sameFile(before, after) || Buffer.byteLength(text, "utf8") !== before.size) fail("input_changed");
    return text;
  } catch (error) {
    if (error instanceof TraceRetrospectError) throw error;
    if (error?.code === "ELOOP") fail("input_symlink_rejected");
    fail("input_unreadable");
  } finally {
    if (descriptor !== undefined) closeSync(descriptor);
  }
}

function jsonLines(text) {
  const lines = text.split("\n").filter((line) => line.trim() !== "");
  if (lines.length === 0) return { rows: [], malformed: true, capped: false };
  if (lines.length > MAX_ROWS) return { rows: [], malformed: false, capped: true };
  const rows = [];
  for (const line of lines) {
    try {
      const value = JSON.parse(line);
      if (!value || typeof value !== "object" || Array.isArray(value)) return { rows: [], malformed: true, capped: false };
      rows.push(value);
    } catch {
      return { rows: [], malformed: true, capped: false };
    }
  }
  return { rows, malformed: false, capped: false };
}

function timestamp(value) {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z$/.test(value)) return null;
  const parsed = Date.parse(value);
  if (!Number.isFinite(parsed)) return null;
  const canonical = value.includes(".") ? value.replace(/\.(\d{1,3})Z$/, (_, fraction) => `.${fraction.padEnd(3, "0")}Z`) : value.replace(/Z$/, ".000Z");
  return new Date(parsed).toISOString() === canonical ? parsed : null;
}

function canonicalJson(value) {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  if (value && typeof value === "object") return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonicalJson(value[key])}`).join(",")}}`;
  return JSON.stringify(value);
}

function exactKeys(value, keys) {
  return Object.keys(value).sort().join(",") === [...keys].sort().join(",");
}

const ROUTE_DECISION_OPTIONAL_KEYS = new Set(["contract_path", "contract_sha256", "provenance"]);
const CONTRACT_PROVENANCES = new Set(["deployed-pi", "deployed-agents", "repo"]);

// Mirror of provenance_complete in scripts/lib/workflow-event-detail.jq:
// change one, change the other. Absent object is fine (pre-T4 history);
// a present object must be complete.
function validModelProvenance(p) {
  if (p === undefined) return true;
  if (!p || typeof p !== "object" || Array.isArray(p)) return false;
  const nonEmpty = (v) => typeof v === "string" && Boolean(v);
  const req = p.requested, eff = p.effective;
  if (!req || typeof req !== "object" || !nonEmpty(req.family) || !nonEmpty(req.model) || !nonEmpty(req.provider)) return false;
  if (req.route !== undefined && !nonEmpty(req.route)) return false;
  if (!eff || typeof eff !== "object" || !nonEmpty(eff.family) || !nonEmpty(eff.model) || !nonEmpty(eff.provider)) return false;
  return Boolean(nonEmpty(p.runner) && nonEmpty(p.run_id));
}

// Mirror of the route_decided branch of strict_detail in
// scripts/lib/workflow-event-detail.jq: change one, change the other.
function validRouteDecidedDetail(detail) {
  if (typeof detail.route !== "string" || !detail.route || typeof detail.reason !== "string" || !detail.reason) return false;
  for (const key of Object.keys(detail)) {
    if (key !== "route" && key !== "reason" && !ROUTE_DECISION_OPTIONAL_KEYS.has(key)) return false;
  }
  if (detail.contract_path !== undefined && (typeof detail.contract_path !== "string" || !detail.contract_path)) return false;
  if (detail.contract_sha256 !== undefined && (typeof detail.contract_sha256 !== "string" || !detail.contract_sha256)) return false;
  if (detail.provenance !== undefined && !CONTRACT_PROVENANCES.has(detail.provenance)) return false;
  return true;
}

export function unavailableTraceObservation(adapter, reasonCodes, terminal = null) {
  return output({
    adapter,
    completeness: "unavailable",
    reasonCodes,
    terminal,
    signals: null,
    usage: null,
    decision: null,
  });
}

function output({ adapter, completeness, reasonCodes, terminal, signals, usage, decision, binding = "explicit_unverified" }) {
  const jevState = decision && terminal ? buildSelfImprovementState({ decision, terminal, verifier: Boolean(signals?.verifier), complete: completeness === "complete", runs: 1 }) : null;
  return {
    schema_version: TRACE_OBSERVATION_SCHEMA_VERSION,
    capability: TRACE_CAPABILITY,
    adapter,
    adapter_version: TRACE_ADAPTER_VERSION,
    binding,
    observation_id: randomUUID(),
    completeness,
    reason_codes: [...new Set(reasonCodes)].sort(),
    lifecycle: terminal ? { terminal: true, outcome: terminal } : { terminal: false, outcome: null },
    signals,
    usage,
    decision,
    jev_state: jevState,
  };
}

function ledgerFacts(rows, run) {
  if (!rows.length || rows.some((row) => row.run !== run)) return { error: "ledger_run_mismatch" };
  if (rows.some((row) => Object.keys(row).sort().join(",") !== "detail,event,run,schema_version,ts" || row.schema_version !== 2 || !LEDGER_EVENTS.has(row.event) || !DECISION_LEDGER_EVENTS.has(row.event) || !row.detail || typeof row.detail !== "object" || Array.isArray(row.detail))) return { error: "ledger_shape_unknown" };
  // AC2 sanctions concurrent exact-duplicate route_decided lines as valid and
  // harmless (indistinguishable from a double-append once written, so a
  // conflict verdict would be a false positive by construction). Collapse
  // them before the conflict check; first occurrence keeps attribution.
  // Duplicates of any other event still conflict.
  const seenRoute = new Set();
  rows = rows.filter((row) => {
    if (row.event !== "route_decided") return true;
    const canonical = canonicalJson(row);
    if (seenRoute.has(canonical)) return false;
    seenRoute.add(canonical);
    return true;
  });
  const canonicalRows = rows.map(canonicalJson);
  if (new Set(canonicalRows).size !== canonicalRows.length) return { error: "ledger_event_conflict" };
  const routeRows = rows.filter((row) => row.event === "route_decided");
  // First-route attribution is positional among route rows, not ledger rows:
  // the router appends route_decided to an already-active (seeded) ledger,
  // so the first route row need not be the ledger's first line.
  if (routeRows.length < 1 || !ROUTES.has(routeRows[0]?.detail?.route) || typeof routeRows[0]?.detail?.reason !== "string" || !routeRows[0].detail.reason) return { error: "ledger_route_conflict" };
  for (const row of rows) {
    const detail = row.detail;
    if (row.event === "route_decided" && !validRouteDecidedDetail(detail)) return { error: "ledger_shape_unknown" };
    if (row.event === "plan_created" && (!exactKeys(detail, ["path", "status"]) || typeof detail.path !== "string" || !detail.path || !PLAN_STATUSES.has(detail.status))) return { error: "ledger_shape_unknown" };
    if (row.event === "validation_run" && (!exactKeys(detail, ["command", "exit"]) || typeof detail.command !== "string" || !detail.command || !Number.isInteger(detail.exit) || detail.exit < 0)) return { error: "ledger_shape_unknown" };
    if (row.event === "validation_failed" && (!exactKeys(detail, ["command", "exit", "failure"]) || typeof detail.command !== "string" || !detail.command || !Number.isInteger(detail.exit) || detail.exit <= 0 || typeof detail.failure !== "string" || !detail.failure)) return { error: "ledger_shape_unknown" };
    if (row.event === "review_completed") {
      const validEvidence = (typeof detail.evidence === "string" && Boolean(detail.evidence))
        || (Array.isArray(detail.evidence) && detail.evidence.length > 0 && detail.evidence.every((item) => typeof item === "string" && item));
      if (!exactKeys(detail, ["status", "evidence"]) || !REVIEW_STATUSES.has(detail.status) || !validEvidence) return { error: "ledger_shape_unknown" };
    }
    // Mirror of the quality_completed branch of strict_detail in
    // scripts/lib/workflow-event-detail.jq: change one, change the other.
    if (row.event === "quality_completed") {
      const validEvidence = (typeof detail.evidence === "string" && Boolean(detail.evidence))
        || (Array.isArray(detail.evidence) && detail.evidence.length > 0 && detail.evidence.every((item) => typeof item === "string" && item));
      if (!exactKeys(detail, ["status", "evidence"]) || !QUALITY_STATUSES.has(detail.status) || !validEvidence) return { error: "ledger_shape_unknown" };
    }
    if (row.event === "adversary_completed" && (!(exactKeys(detail, ["mode", "verdict", "accepted_findings", "rejected_findings"]) || exactKeys(detail, ["mode", "verdict", "accepted_findings", "rejected_findings", "model_provenance"])) || !ADVERSARY_MODES.has(detail.mode) || typeof detail.verdict !== "string" || !detail.verdict || !Array.isArray(detail.accepted_findings) || !detail.accepted_findings.every((item) => typeof item === "string") || !Array.isArray(detail.rejected_findings) || !detail.rejected_findings.every((item) => typeof item === "string") || !validModelProvenance(detail.model_provenance))) return { error: "ledger_shape_unknown" };
    if (row.event === "completed" && (!exactKeys(detail, ["summary"]) || typeof detail.summary !== "string" || !detail.summary)) return { error: "ledger_shape_unknown" };
    if (row.event === "blocked" && (!exactKeys(detail, ["reason", "needed_input"]) || typeof detail.reason !== "string" || !detail.reason || typeof detail.needed_input !== "string" || !detail.needed_input)) return { error: "ledger_shape_unknown" };
  }
  const terminalRows = rows.filter((row) => TERMINALS.has(row.event));
  const last = rows.at(-1);
  if (terminalRows.length > 1) return { error: "ledger_event_conflict" };
  if (terminalRows.length !== 1 || last !== terminalRows[0]) return { error: "ledger_not_terminal" };
  const times = rows.map((row) => timestamp(row.ts));
  if (times.some((value) => value === null)) return { error: "ledger_time_invalid" };
  for (let index = 1; index < times.length; index += 1) if (times[index] < times[index - 1]) return { error: "ledger_time_conflict" };
  const validationFailures = rows.filter((row) => row.event === "validation_failed").length;
  const latestValidations = new Map();
  for (const row of rows) if (row.event === "validation_run" || row.event === "validation_failed") latestValidations.set(row.detail.command, row);
  const validationReady = latestValidations.size > 0 && [...latestValidations.values()].every((row) => row.event === "validation_run" && row.detail.exit === 0);
  const latestReview = rows.filter((row) => row.event === "review_completed").at(-1);
  const reviewReady = latestReview === undefined || latestReview.detail.status !== "BLOCK";
  const reviewRework = rows
    .filter((row) => row.event === "adversary_completed")
    .reduce((total, row) => total + (Array.isArray(row.detail?.accepted_findings) ? row.detail.accepted_findings.length : 0), 0);
  return {
    genesis: rows[0],
    route: routeRows[0].detail.route,
    planStatus: rows.filter((row) => row.event === "plan_created").at(-1)?.detail?.status ?? null,
    terminal: last.event,
    start: times[0],
    end: times.at(-1),
    validationFailures,
    verifier: validationReady && reviewReady,
    reviewRework,
    planRework: Math.max(0, rows.filter((row) => row.event === "plan_created").length - 1),
  };
}

function addUsage(total, usage) {
  if (!usage || typeof usage !== "object") return false;
  const input = usage.input ?? usage.input_tokens ?? usage.prompt_tokens;
  const outputTokens = usage.output ?? usage.output_tokens ?? usage.completion_tokens;
  if (!Number.isSafeInteger(input) || input < 0 || !Number.isSafeInteger(outputTokens) || outputTokens < 0) return false;
  const reportedTotal = usage.totalTokens ?? usage.total_tokens ?? input + outputTokens;
  if (!Number.isSafeInteger(reportedTotal) || reportedTotal < input + outputTokens || reportedTotal > MAX_TOKEN_COUNT) return false;
  if (total.input_tokens + input > MAX_TOKEN_COUNT || total.output_tokens + outputTokens > MAX_TOKEN_COUNT || total.total_tokens + reportedTotal > MAX_TOKEN_COUNT) return false;
  total.input_tokens += input;
  total.output_tokens += outputTokens;
  total.total_tokens += reportedTotal;
  return true;
}

function plainObject(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function validTextOrImage(item) {
  if (!plainObject(item)) return false;
  if (item.type === "text") return typeof item.text === "string";
  return item.type === "image" && typeof item.data === "string" && typeof item.mimeType === "string";
}

function validPiAssistantItem(item) {
  if (!plainObject(item)) return false;
  if (item.type === "text") return typeof item.text === "string";
  if (item.type === "thinking") return typeof item.thinking === "string" && (item.redacted === undefined || typeof item.redacted === "boolean");
  return item.type === "toolCall" && typeof item.id === "string" && Boolean(item.id) && typeof item.name === "string" && Boolean(item.name) && plainObject(item.arguments);
}

function validClaudeAssistantItem(item) {
  if (!plainObject(item)) return false;
  if (item.type === "text") return typeof item.text === "string";
  if (item.type === "thinking") return typeof item.thinking === "string";
  if (item.type === "redacted_thinking") return typeof item.data === "string";
  return item.type === "tool_use" && typeof item.id === "string" && Boolean(item.id) && typeof item.name === "string" && Boolean(item.name) && plainObject(item.input);
}

function validClaudeUserItem(item) {
  if (validTextOrImage(item)) return true;
  if (!plainObject(item) || item.type !== "tool_result" || typeof (item.tool_use_id ?? item.toolUseId) !== "string") return false;
  if (!(typeof item.content === "string" || Array.isArray(item.content))) return false;
  return !Array.isArray(item.content) || item.content.every((content) => {
    if (!plainObject(content)) return false;
    if (content.type === "text") return typeof content.text === "string";
    return content.type === "image" && plainObject(content.source) && typeof content.source.type === "string" && typeof content.source.media_type === "string" && typeof content.source.data === "string";
  });
}

function validRouterDecisionData(data) {
  if (!plainObject(data) || !exactKeys(data, ["receipt", "version"]) || typeof data.version !== "string" || !data.version) return false;
  const receipt = data.receipt;
  if (!plainObject(receipt) || !exactKeys(receipt, ["schema_version", "ts", "provider", "model", "policy_version", "state_fingerprint", "question_fingerprint", "deterministic_decision", "selected_decision", "selection_source", "selection_reason", "shadow_answer", "latency_ms", "usage", "outcome", "error_code"])) return false;
  if (receipt.schema_version !== 2 || timestamp(receipt.ts) === null) return false;
  for (const key of ["provider", "model", "policy_version", "deterministic_decision", "selected_decision", "selection_source", "outcome"]) {
    if (typeof receipt[key] !== "string" || !receipt[key]) return false;
  }
  for (const key of ["state_fingerprint", "question_fingerprint"]) if (typeof receipt[key] !== "string" || !/^[0-9a-f]{64}$/.test(receipt[key])) return false;
  if (receipt.selection_reason !== null && typeof receipt.selection_reason !== "string") return false;
  if (receipt.shadow_answer !== null && !plainObject(receipt.shadow_answer)) return false;
  if (!Number.isSafeInteger(receipt.latency_ms) || receipt.latency_ms < 0) return false;
  if (receipt.usage !== null && (!plainObject(receipt.usage) || !Number.isSafeInteger(receipt.usage.input_tokens) || receipt.usage.input_tokens < 0 || !Number.isSafeInteger(receipt.usage.output_tokens) || receipt.usage.output_tokens < 0)) return false;
  return receipt.error_code === null || typeof receipt.error_code === "string";
}

function validContent(content, validator) {
  return typeof content === "string" || (Array.isArray(content) && content.every(validator));
}

function validatePiLineage(rows) {
  const seen = new Set();
  const parents = new Set();
  for (const row of rows.slice(1)) {
    if (typeof row.id !== "string" || !row.id || seen.has(row.id)) return "trace_identity_unknown";
    if (row.parentId !== null && (typeof row.parentId !== "string" || !seen.has(row.parentId))) return "trace_branch_ambiguous";
    const parent = row.parentId ?? "__root__";
    if (parents.has(parent)) return "trace_branch_ambiguous";
    parents.add(parent);
    seen.add(row.id);
  }
  return null;
}

function parsePi(rows, run, genesis, windowStart, windowEnd) {
  if (rows[0]?.type !== "session" || rows[0]?.version !== 3 || typeof rows[0]?.id !== "string" || !rows[0].id) return { error: "trace_identity_unknown" };
  const expectedBinding = createPiRunBinding(rows[0].id, run, genesis);
  const lineageError = validatePiLineage(rows);
  if (lineageError) return { error: lineageError };
  for (let index = 1; index < rows.length; index += 1) {
    if (timestamp(rows[index].timestamp) < timestamp(rows[index - 1].timestamp)) return { error: "trace_time_conflict" };
  }
  const idPositions = new Map(rows.slice(1).map((row, offset) => [row.id, offset + 1]));
  const allCalls = new Map();
  const allResults = new Set();
  const windowCalls = new Map();
  const windowResults = new Set();
  const usage = { input_tokens: 0, output_tokens: 0, total_tokens: 0 };
  let usageSeen = false;
  let usageComplete = true;
  let toolErrors = 0;
  let compactions = 0;
  let partial = false;
  let unsupportedRows = 0;
  let assistantRows = 0;
  let observedToolCalls = 0;
  const bindings = [];
  const allBindingRows = [];
  const routeRows = [];
  const decisionRows = [];
  for (const [index, row] of rows.entries()) {
    if (index === 0) continue;
    const rowTime = timestamp(row.timestamp);
    const inWindow = rowTime >= windowStart && rowTime <= windowEnd;
    if (row.type === "message") {
      const message = row.message;
      if (!message || typeof message !== "object") return { error: "trace_primary_shape_missing" };
      if (message.role === "assistant") {
        if (inWindow) assistantRows += 1;
        if (!Array.isArray(message.content)) return { error: "trace_primary_shape_missing" };
        if (!validContent(message.content, validPiAssistantItem)) return { error: "trace_shape_unknown" };
        for (const item of message.content) {
          if (item.type !== "toolCall") continue;
          if (typeof item.id !== "string" || !item.id || typeof item.name !== "string" || !item.name || allCalls.has(item.id)) return { error: "trace_tool_conflict" };
          allCalls.set(item.id, item.name);
          if (inWindow) {
            windowCalls.set(item.id, item.name);
            observedToolCalls += 1;
          }
        }
        if (inWindow) {
          if (message.usage === undefined) usageComplete = false;
          else if (addUsage(usage, message.usage)) usageSeen = true;
          else usageComplete = false;
        }
      } else if (message.role === "toolResult") {
        if (typeof message.toolCallId !== "string" || typeof message.isError !== "boolean") return { error: "trace_tool_conflict" };
        if (!validContent(message.content, validTextOrImage)) return { error: "trace_shape_unknown" };
        if (!allCalls.has(message.toolCallId) || allResults.has(message.toolCallId) || message.toolName !== allCalls.get(message.toolCallId)) return { error: "trace_tool_conflict" };
        allResults.add(message.toolCallId);
        if (windowCalls.has(message.toolCallId)) {
          windowResults.add(message.toolCallId);
          if (message.isError) toolErrors += 1;
        }
      } else if (message.role === "user") {
        if (!validContent(message.content, validTextOrImage)) return { error: "trace_shape_unknown" };
      } else return { error: "trace_primary_shape_missing" };
    } else if (row.type === "compaction") {
      const retainedPosition = idPositions.get(row.firstKeptEntryId);
      const hasRetainedContext = typeof row.firstKeptEntryId === "string" && row.firstKeptEntryId && Number.isInteger(retainedPosition) && retainedPosition < index;
      if (typeof row.summary !== "string" || !Number.isSafeInteger(row.tokensBefore) || row.tokensBefore < 0 || !hasRetainedContext) return { error: "trace_shape_unknown" };
      if (inWindow) compactions += 1;
    } else if (row.type === "branch_summary") {
      return { error: "trace_branch_ambiguous" };
    } else if (row.type === "model_change" || row.type === "thinking_level_change") {
      const knownMetadata = row.type === "model_change"
        ? typeof row.provider === "string" && Boolean(row.provider) && typeof row.modelId === "string" && Boolean(row.modelId)
        : typeof row.thinkingLevel === "string" && Boolean(row.thinkingLevel);
      if (!knownMetadata) return { error: "trace_shape_unknown" };
    } else if (row.type === "label_change") {
      if (typeof row.label !== "string") return { error: "trace_shape_unknown" };
      if (inWindow) {
        partial = true;
        unsupportedRows += 1;
      }
    } else if (row.type === "custom" && row.customType === PI_RUN_BINDING_TYPE) {
      allBindingRows.push({ data: row.data, index });
      if (inWindow) bindings.push({ data: row.data, index });
    } else if (row.type === "custom" && row.customType === "etabli.workflow-router") {
      const route = row.data?.decision?.route;
      if (!ROUTES.has(route)) return { error: "trace_route_conflict" };
      routeRows.push({ index, route, inWindow });
    } else if (row.type === "custom" && row.customType === "etabli.workflow-router.decision") {
      if (!validRouterDecisionData(row.data)) return { error: "trace_shape_unknown" };
      decisionRows.push({ index, selected: row.data.receipt.selected_decision });
    } else {
      return { error: "trace_shape_unknown" };
    }
  }
  if (windowCalls.size !== windowResults.size) return { error: "trace_tool_incomplete" };
  for (const id of windowCalls.keys()) if (!windowResults.has(id)) return { error: "trace_tool_incomplete" };
  if (assistantRows === 0) return { error: "trace_primary_shape_missing" };
  if (bindings.length > 1) return { error: "trace_binding_conflict" };
  if (bindings.length === 1 && (!isPiRunBinding(bindings[0].data) || bindings[0].data.fingerprint !== expectedBinding.fingerprint)) return { error: "trace_binding_mismatch" };
  let traceRoute = null;
  if (bindings.length === 1) {
    const binding = bindings[0];
    const previousBinding = allBindingRows.filter((row) => row.index < binding.index).at(-1);
    const lowerBound = previousBinding?.index ?? -1;
    const authoritative = routeRows.filter((row) => row.index > lowerBound && row.index < binding.index).at(-1);
    if (!authoritative) return { error: "trace_route_mismatch" };
    traceRoute = authoritative.route;
    const receipt = decisionRows.filter((row) => row.index > authoritative.index && row.index < binding.index).at(-1);
    if (receipt && !routeMatchesSelectedDecision(traceRoute, receipt.selected)) return { error: "trace_route_conflict" };
  } else {
    const routes = [...new Set(routeRows.filter((row) => row.inWindow).map((row) => row.route))];
    if (routes.length > 1) return { error: "trace_route_conflict" };
    traceRoute = routes[0] ?? null;
  }
  return { binding: bindings.length === 1 ? "native_correlated" : "explicit_unverified", partial, unsupportedRows, traceRoute, toolCalls: observedToolCalls, toolErrors, compactions, retries: null, usage: usageSeen && usageComplete ? usage : null };
}

function claudeContent(row) {
  return row.message?.content ?? row.content;
}

function validateClaudeLineage(rows) {
  const seen = new Set();
  const parents = new Set();
  for (const row of rows) {
    if (typeof row.uuid !== "string" || !row.uuid || seen.has(row.uuid)) return "trace_identity_unknown";
    if (row.parentUuid !== null && (typeof row.parentUuid !== "string" || !seen.has(row.parentUuid))) return "trace_branch_ambiguous";
    const parent = row.parentUuid ?? "__root__";
    if (parents.has(parent)) return "trace_branch_ambiguous";
    parents.add(parent);
    seen.add(row.uuid);
  }
  return null;
}

function parseClaude(rows) {
  const sessionIds = new Set(rows.map((row) => row.sessionId));
  const nonPrimary = rows.some((row) => (row.isSidechain !== undefined && row.isSidechain !== false) || (row.isMeta !== undefined && row.isMeta !== false));
  if (sessionIds.size !== 1 || typeof rows[0]?.sessionId !== "string" || !rows[0].sessionId || nonPrimary) return { error: "trace_identity_unknown" };
  const lineageError = validateClaudeLineage(rows);
  if (lineageError) return { error: lineageError };
  for (let index = 1; index < rows.length; index += 1) {
    if (timestamp(rows[index].timestamp) < timestamp(rows[index - 1].timestamp)) return { error: "trace_time_conflict" };
  }
  const calls = new Map();
  const results = new Set();
  const usage = { input_tokens: 0, output_tokens: 0, total_tokens: 0 };
  let usageSeen = false;
  let usageComplete = true;
  let toolErrors = 0;
  let partial = false;
  let unsupportedRows = 0;
  let assistantRows = 0;
  let userRows = 0;
  for (const row of rows) {
    if (row.type === "assistant") {
      assistantRows += 1;
      if (!plainObject(row.message) || row.message.role !== "assistant") return { error: "trace_primary_shape_missing" };
      const content = claudeContent(row);
      if (!validContent(content, validClaudeAssistantItem)) return { error: "trace_shape_unknown" };
      for (const item of Array.isArray(content) ? content : []) {
        if (item?.type !== "tool_use") continue;
        if (typeof item.id !== "string" || !item.id || typeof item.name !== "string" || !item.name || calls.has(item.id)) return { error: "trace_tool_conflict" };
        calls.set(item.id, item.name);
      }
      const rowUsage = row.usage ?? row.message?.usage ?? row.message?.message?.usage;
      if (rowUsage === undefined) usageComplete = false;
      else if (addUsage(usage, rowUsage)) usageSeen = true;
      else usageComplete = false;
    } else if (row.type === "user") {
      userRows += 1;
      if (!plainObject(row.message) || row.message.role !== "user") return { error: "trace_primary_shape_missing" };
      const content = claudeContent(row);
      if (!validContent(content, validClaudeUserItem)) return { error: "trace_shape_unknown" };
      for (const item of Array.isArray(content) ? content : []) {
        if (item?.type !== "tool_result") continue;
        const id = item.tool_use_id ?? item.toolUseId;
        if (typeof id !== "string" || results.has(id)) return { error: "trace_tool_conflict" };
        if (!calls.has(id)) return { error: "trace_tool_conflict" };
        if (item.is_error !== undefined && typeof item.is_error !== "boolean") return { error: "trace_shape_unknown" };
        if (item.isError !== undefined && typeof item.isError !== "boolean") return { error: "trace_shape_unknown" };
        if (item.is_error !== undefined && item.isError !== undefined && item.is_error !== item.isError) return { error: "trace_tool_conflict" };
        results.add(id);
        if (item.is_error === true || item.isError === true) toolErrors += 1;
      }
    } else if (row.type === "system" && row.subtype === "init" && typeof row.model === "string" && row.model) {
      partial = true;
      unsupportedRows += 1;
    } else {
      return { error: "trace_shape_unknown" };
    }
  }
  if (calls.size !== results.size) return { error: "trace_tool_incomplete" };
  for (const id of calls.keys()) if (!results.has(id)) return { error: "trace_tool_incomplete" };
  if (assistantRows === 0 || userRows === 0) return { error: "trace_primary_shape_missing" };
  return { partial, unsupportedRows, toolCalls: calls.size, toolErrors, compactions: null, retries: null, usage: usageSeen && usageComplete ? usage : null };
}

function chooseDecision(completeness, signals) {
  if (completeness !== "complete") return { action: "no_op", category: "incomplete_evidence", target: "none", causal_status: "unknown" };
  if (signals.validation_failures > 0) return { action: "recommendation", category: "validation_failure", target: "testing", causal_status: "unknown" };
  if (signals.tool_errors > 0) return { action: "recommendation", category: "tool_failure", target: "tooling", causal_status: "unknown" };
  if (signals.review_rework > 0) return { action: "recommendation", category: "review_rework", target: "rule", causal_status: "unknown" };
  if (signals.plan_rework > 0) return { action: "recommendation", category: "plan_rework", target: "skill", causal_status: "unknown" };
  if ((signals.compactions ?? 0) > 0) return { action: "recommendation", category: "context_pressure", target: "context", causal_status: "unknown" };
  return { action: "no_op", category: "no_issue", target: "none", causal_status: "unknown" };
}

function routeMatchesSelectedDecision(route, selected) {
  return selected === route || (route === "answer" && selected === "direct-edit");
}

function routeMatchesLedger(traceRoute, ledgerRoute, planStatus) {
  return traceRoute === ledgerRoute || (ledgerRoute === "plan-implement" && traceRoute === "implement" && planStatus === "READY");
}

export function buildSelfImprovementState({ decision, terminal, verifier, complete, runs }) {
  const candidate = `action=${decision.action};category=${decision.category};target=${decision.target}`;
  const evidence = `runs=${runs};complete=${complete};terminal=${terminal};verifier=${verifier}`;
  return { candidate, evidence };
}

export function analyzeTraceEpisode({ adapter, traceText, ledgerText, run, capability = TRACE_CAPABILITY }) {
  validateTraceRequest({ adapter, run, capability });
  const trace = jsonLines(traceText);
  const ledger = jsonLines(ledgerText);
  if (trace.capped || ledger.capped) return unavailableTraceObservation(adapter, ["input_row_cap"]);
  if (trace.malformed || ledger.malformed) return unavailableTraceObservation(adapter, ["input_json_malformed"]);
  const facts = ledgerFacts(ledger.rows, run);
  if (facts.error) return unavailableTraceObservation(adapter, [facts.error]);
  const traceTimes = trace.rows.map((row) => timestamp(row.timestamp)).filter((value) => value !== null);
  const bindingTimes = adapter === "pi" ? trace.rows.filter((row) => row.type === "custom" && row.customType === PI_RUN_BINDING_TYPE).map((row) => timestamp(row.timestamp)) : [];
  const piHasBinding = bindingTimes.some((value) => value !== null && value >= facts.start && value <= facts.end);
  const outsideWindow = !piHasBinding && traceTimes.some((value) => value < facts.start || value > facts.end)
    || bindingTimes.some((value) => value === null);
  if (traceTimes.length !== trace.rows.length || outsideWindow) return unavailableTraceObservation(adapter, ["trace_window_mismatch"], facts.terminal);
  const parsed = adapter === "pi" ? parsePi(trace.rows, run, facts.genesis, facts.start, facts.end) : parseClaude(trace.rows);
  if (parsed.error) return unavailableTraceObservation(adapter, [parsed.error], facts.terminal);
  if (typeof parsed.traceRoute === "string" && !routeMatchesLedger(parsed.traceRoute, facts.route, facts.planStatus)) return unavailableTraceObservation(adapter, ["trace_route_mismatch"], facts.terminal);
  const completeness = parsed.partial ? "partial" : "complete";
  const signals = {
    tool_calls: parsed.toolCalls,
    tool_errors: parsed.toolErrors,
    validation_failures: facts.validationFailures,
    review_rework: facts.reviewRework,
    plan_rework: facts.planRework,
    compactions: parsed.compactions,
    retries: parsed.retries,
    unsupported_rows: parsed.unsupportedRows,
    verifier: facts.verifier,
  };
  const decision = chooseDecision(completeness, signals);
  return output({ adapter, binding: parsed.binding, completeness, reasonCodes: completeness === "partial" ? ["allowlisted_secondary_shape"] : [], terminal: facts.terminal, signals, usage: parsed.usage, decision });
}
