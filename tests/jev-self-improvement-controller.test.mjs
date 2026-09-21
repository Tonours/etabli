import assert from "node:assert/strict";
import { existsSync, mkdtempSync, readFileSync, rmSync, symlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { controllerSourceFingerprint, runSelfImprovementController, validatePrivateOutputDirectory, validateProposalCapabilityReceipt } from "../scripts/lib/jev-self-improvement-controller.mjs";
import { createHash } from "node:crypto";

const traceText = readFileSync("tests/fixtures/harness-traces/pi/session-bound.jsonl", "utf8");
const ledgerText = readFileSync("tests/fixtures/harness-traces/pi/events.jsonl", "utf8");
const sha = (value) => createHash("sha256").update(value).digest("hex");
const diagnosis = (actionability, target = "no_change", pattern = "no_material_friction") => async ({ projectedState }) => {
  assert.deepEqual(Object.keys(projectedState).sort(), ["episode", "signals"]);
  assert.doesNotMatch(JSON.stringify(projectedState), /pi-run|session|events|[0-9a-f]{64}/);
  return { schema_version: 1, profile_id: "self-improvement-diagnosis", authority: "diagnostic", status: "diagnosed", diagnosis: { pattern, target, actionability }, provenance: { provider: "fixture", model: "jev-1.13.0" } };
};

function receipt() {
  const value = {
    schema_version: 1,
    capability: "propose_reviewed",
    status: "enabled",
    controller_sha256: controllerSourceFingerprint(),
    synthetic_suite_sha256: "a".repeat(64),
    live_trace_sha256: ["b".repeat(64), "c".repeat(64), "d".repeat(64)],
    cross_model_verification: { model: "xai/grok-4.6", verdict: "accepted", receipt_sha256: "e".repeat(64) },
  };
  value.receipt_sha256 = sha(JSON.stringify(value, Object.keys(value).sort()));
  return value;
}

test("no_op and investigate terminate without a traditional LLM call", async () => {
  const noOp = await runSelfImprovementController({ traceText, ledgerText, run: "pi-run", diagnose: diagnosis("no_op") });
  assert.equal(noOp.outcome, "no_op");
  assert.equal(noOp.traditional_llm.calls, 0);
  assert.equal(noOp.proposal, null);
  const investigate = await runSelfImprovementController({ traceText, ledgerText, run: "pi-run", diagnose: diagnosis("investigate", "needs_investigation", "mixed_or_ambiguous") });
  assert.equal(investigate.outcome, "investigate");
  assert.equal(investigate.traditional_llm.calls, 0);
});

test("diagnose_shadow suppresses candidates and provider failure abstains", async () => {
  const candidate = await runSelfImprovementController({ traceText, ledgerText, run: "pi-run", diagnose: diagnosis("candidate", "validation_strategy", "verification_gap") });
  assert.equal(candidate.outcome, "investigate");
  assert.equal(candidate.reason, "proposal_capability_not_enabled");
  assert.equal(candidate.proposal, null);
  const failure = await runSelfImprovementController({ traceText, ledgerText, run: "pi-run", diagnose: async () => { throw new Error("private provider failure"); } });
  assert.equal(failure.outcome, "investigate");
  assert.equal(failure.reason, "provider_error");
});

test("valid reviewed capability emits only a non-executable bounded packet", async () => {
  const value = receipt();
  value.receipt_sha256 = sha(JSON.stringify({ ...value, receipt_sha256: undefined }, (_key, item) => item));
  // Rebuild with the controller canonical order used by the receipt contract.
  delete value.receipt_sha256;
  const canonical = (input) => input && typeof input === "object" && !Array.isArray(input)
    ? `{${Object.keys(input).sort().map((key) => `${JSON.stringify(key)}:${canonical(input[key])}`).join(",")}}`
    : Array.isArray(input) ? `[${input.map(canonical).join(",")}]` : JSON.stringify(input);
  value.receipt_sha256 = sha(canonical(value));
  validateProposalCapabilityReceipt(value);
  const packet = await runSelfImprovementController({ traceText, ledgerText, run: "pi-run", capabilityReceipt: value, diagnose: diagnosis("candidate", "validation_strategy", "verification_gap") });
  assert.equal(packet.outcome, "candidate");
  assert.equal(packet.proposal.executable, false);
  assert.equal(packet.proposal.requested_route, "plan-implement");
  assert.equal(packet.traditional_llm.calls, 0);
  assert.deepEqual(packet.proposal.editable_surfaces, ["tests/", "workflow/runtime/agentic-infra-checks.tsv"]);
  const duplicate = await runSelfImprovementController({ traceText, ledgerText, run: "pi-run", capabilityReceipt: value, history: [packet.proposal.candidate_fingerprint], diagnose: diagnosis("candidate", "validation_strategy", "verification_gap") });
  assert.equal(duplicate.outcome, "investigate");
  assert.equal(duplicate.reason, "duplicate_candidate");
});

test("secret-like, incomplete, route-mismatch and stale capability evidence fail closed", async () => {
  await assert.rejects(() => runSelfImprovementController({ traceText: `${traceText}\napi_key=private-value`, ledgerText, run: "pi-run", diagnose: diagnosis("no_op") }), /secret_like_input_rejected/);
  await assert.rejects(() => runSelfImprovementController({ traceText, ledgerText, run: "other-run", diagnose: diagnosis("no_op") }), /native_correlation_required|complete_terminal_observation_required/);
  const stale = receipt();
  stale.controller_sha256 = "f".repeat(64);
  assert.throws(() => validateProposalCapabilityReceipt(stale), /proposal_capability_stale/);
});

test("private output validation rejects symlink roots and existing targets", () => {
  const root = mkdtempSync(join(tmpdir(), "jev-controller-output-"));
  const outside = mkdtempSync(join(tmpdir(), "jev-controller-outside-"));
  try {
    symlinkSync(outside, join(root, ".workflow"));
    assert.throws(() => validatePrivateOutputDirectory(join(root, ".workflow/jev-self-improvement/private/run"), root), /output_root_symlink_rejected|ELOOP/);
    assert.equal(existsSync(join(outside, "jev-self-improvement")), false);
  } finally {
    rmSync(root, { recursive: true, force: true });
    rmSync(outside, { recursive: true, force: true });
  }
});
