import { createHash } from "node:crypto";
import { normalizeEvents, piEventCoverage, observedPiChildDispatches } from "./harness-token-usage.mjs";

export const reviewRoles = ["parent", "logic", "spec", "quality", "adversary-plan", "adversary-code", "lead"];
export const sha256 = (text) => createHash("sha256").update(text).digest("hex");
const id = (value) => typeof value === "string" && /^[a-zA-Z0-9][a-zA-Z0-9_.:-]{0,127}$/.test(value);

export function reviewPassEvent(receipt) {
  return {outcome:"review_pass",success:receipt.terminal==="succeeded",success_kind:"run_terminal",
    measured:receipt.measured,role:receipt.role,pass_sha256:sha256(receipt.pass_id),
    parent_sha256:receipt.parent_id===null?null:sha256(receipt.parent_id),patch_sha256:receipt.patch_sha256,
    ...(receipt.measured ? {input_tokens:receipt.usage.input_tokens,output_tokens:receipt.usage.output_tokens,
      total_tokens:receipt.usage.total_tokens,tool_calls:receipt.tool_calls,elapsed_ms:receipt.elapsed_ms}
      : {reason:"incomplete_native_usage",known_tokens:receipt.receipts.reduce((sum,row)=>sum+row.total_tokens,0)})};
}

export function reviewRunReceipt({ passId, parentId = null, role, patchSha256, events, exitCode, elapsedMs, inputs = [], childScope = null }) {
  if (!id(passId) || (parentId !== null && !id(parentId)) || !reviewRoles.includes(role) ||
      !/^[a-f0-9]{64}$/.test(patchSha256) || !Number.isSafeInteger(exitCode) ||
      !Number.isFinite(elapsedMs) || elapsedMs < 0) throw new Error("Invalid review receipt identity; supply pass, parent, role and patch hash");
  const normalized = normalizeEvents("pi", events, { exitCode, coverage: piEventCoverage(events,{childScope}) });
  return { schema_version: 1, pass_id: passId, parent_id: parentId, role, patch_sha256: patchSha256,
    accounting: "exclusive", elapsed_ms: elapsedMs, terminal: normalized.transport_success && normalized.final_text.trim() ? "succeeded" : "failed",
    measured: normalized.measured, models: normalized.models, coverage: normalized.coverage,
    observed_child_dispatches: observedPiChildDispatches(events),
    measurement_errors: normalized.measurement_errors, usage: normalized.usage, receipts: normalized.receipts,
    tool_calls: normalized.tools.length, llm_calls: normalized.receipts.length,
    inputs: inputs.map(({ kind, text }) => ({ kind, sha256: sha256(text), bytes: Buffer.byteLength(text) })),
    prompt_inventory_scope: "supplied_inputs_only", effective_system_prompt: "unknown" };
}

// Expected passes come from dispatch, not from whatever receipts happen to exist.
export function aggregateReviewRuns(expected, records) {
  const errors = [], seen = new Set(), receiptIds = new Set();
  if (!expected.length || new Set(expected.map((pass) => pass.pass_id)).size !== expected.length) throw new Error("Expected review passes must be nonempty and unique");
  let knownTokens = 0;
  for (const record of records) {
    const pass = expected.find((item) => item.pass_id === record.pass_id);
    if (!pass || seen.has(record.pass_id)) { errors.push("unexpected_or_duplicate_pass"); continue; }
    seen.add(record.pass_id);
    if (["parent_id", "role", "patch_sha256"].some((key) => pass[key] !== record[key])) errors.push("pass_binding_mismatch");
    if (record.accounting !== "exclusive") errors.push("unsupported_parent_inclusive_accounting");
    const missingChildOnly = record.measurement_errors?.length > 0 && record.measurement_errors.every((error) => error === "Call-class coverage unproven: child");
    const childPasses = expected.filter((child) => child.parent_id === record.pass_id);
    // Stats are observations without native dispatch IDs. Only the scheduler's
    // explicit inventory may bind them; silence and a measured parent cannot.
    const inventoryComplete = record.child_inventory?.status === "complete" &&
      typeof record.child_inventory.evidence === "string" && record.child_inventory.evidence.trim().length > 0;
    const statsBindings = record.child_inventory?.stats_bindings ?? {};
    const boundStats = new Set();
    const dispatchesBound = Array.isArray(record.observed_child_dispatches) && record.observed_child_dispatches.every(dispatch => {
      if (dispatch.dispatch_id) return childPasses.some(child=>child.dispatch_id===dispatch.dispatch_id);
      const childId = dispatch.stats_key && statsBindings[dispatch.stats_key];
      if (!inventoryComplete || !childId || boundStats.has(childId) || !childPasses.some(child=>child.pass_id===childId)) return false;
      boundStats.add(childId);
      return true;
    });
    if(!dispatchesBound)errors.push("unbound_child_dispatch");
    const childrenReconciled = missingChildOnly && inventoryComplete && dispatchesBound && childPasses.every((child) => records.some((r) => r.pass_id === child.pass_id));
    if ((!record.measured && !childrenReconciled) || record.terminal !== "succeeded" || !record.receipts?.length || !record.models?.length) errors.push("incomplete_pass");
    const passTokens=(record.receipts??[]).reduce((sum,row)=>sum+(row.total_tokens??NaN),0);
    if(!Number.isSafeInteger(passTokens)||passTokens<=0||(!childrenReconciled && passTokens!==record.usage?.total_tokens))errors.push("pass_usage_mismatch");
    for (const receipt of record.receipts ?? []) {
      // Pi response IDs are provider identities; anonymous/ordinal identities are run-local.
      const key = receipt.identity?.startsWith("pi:provider:") ? receipt.identity : `${record.pass_id}:${receipt.identity}`;
      if (!receipt.identity || receiptIds.has(key)) { errors.push("missing_or_duplicate_provider_receipt"); continue; }
      receiptIds.add(key);
      if (!Number.isSafeInteger(receipt.total_tokens) || receipt.total_tokens <= 0) errors.push("invalid_usage");
      else knownTokens += receipt.total_tokens;
    }
  }
  const missing = expected.filter((pass) => !seen.has(pass.pass_id)).map((pass) => pass.pass_id);
  if (missing.length) errors.push("missing_pass_receipt");
  return { schema_version: 1, measured: errors.length === 0, total_tokens: errors.length ? null : knownTokens,
    known_tokens: knownTokens, missing, errors: [...new Set(errors)], passes: records.length };
}
