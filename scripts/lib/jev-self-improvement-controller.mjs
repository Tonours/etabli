#!/usr/bin/env node

import { createHash } from "node:crypto";
import { existsSync, lstatSync, mkdirSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import { dirname, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { analyzeTraceEpisode, readBoundedRegularFile } from "./harness-trace-retrospect.mjs";
import { prepareSelfImprovementDiagnosisState } from "../../pi/extensions/lib/self-improvement-diagnosis.mjs";
import { evaluateSelfImprovementDiagnosis, loadSemanticProfilePolicy } from "../../pi/extensions/lib/semantic-profiles.mjs";

const SHA256 = /^[a-f0-9]{64}$/;
const SECRET_LIKE = /(?:-----BEGIN [A-Z ]+ PRIVATE KEY-----|\b(?:api[_-]?key|access[_-]?token|client[_-]?secret|password)\s*[:=]|\bsk-[A-Za-z0-9_-]{12,})/i;
const TARGET_SURFACES = Object.freeze({
  no_change: [],
  tool_contract: ["scripts/", "pi/extensions/lib/"],
  validation_strategy: ["tests/", "workflow/runtime/agentic-infra-checks.tsv"],
  review_contract: ["workflow/review-rubric.md"],
  planning_contract: ["workflow/skills/plan-loop.md", "PLAN_TEMPLATE.md"],
  context_design: ["workflow/skills/", "pi/extensions/lib/"],
  needs_investigation: [],
});
const FRICTION_COUNTERS = ["tool_errors", "validation_failures", "review_rework", "plan_rework", "compactions", "retries"];

function fail(reason) {
  const error = new Error(reason);
  error.code = reason;
  throw error;
}

function sha(value) { return createHash("sha256").update(value).digest("hex"); }
function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value && typeof value === "object") return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonical(value[key])}`).join(",")}}`;
  return JSON.stringify(value);
}

export function controllerSourceFingerprint() {
  return sha(readFileSync(fileURLToPath(import.meta.url)));
}

export function validateProposalCapabilityReceipt(receipt, controllerFingerprint = controllerSourceFingerprint()) {
  if (receipt?.schema_version !== 1 || receipt.capability !== "propose_reviewed" || receipt.status !== "enabled") fail("proposal_capability_invalid");
  if (receipt.controller_sha256 !== controllerFingerprint || !SHA256.test(receipt.synthetic_suite_sha256 ?? "")) fail("proposal_capability_stale");
  if (!Array.isArray(receipt.live_trace_sha256) || receipt.live_trace_sha256.length !== 3 || new Set(receipt.live_trace_sha256).size !== 3 || receipt.live_trace_sha256.some((value) => !SHA256.test(value))) fail("proposal_capability_live_evidence_invalid");
  if (receipt.cross_model_verification?.verdict !== "accepted" || !receipt.cross_model_verification.model || !SHA256.test(receipt.cross_model_verification.receipt_sha256 ?? "")) fail("proposal_capability_review_invalid");
  const payload = { ...receipt };
  delete payload.receipt_sha256;
  if (!SHA256.test(receipt.receipt_sha256 ?? "") || receipt.receipt_sha256 !== sha(canonical(payload))) fail("proposal_capability_fingerprint_invalid");
  return receipt;
}

function frictionFree(observation) {
  return observation.lifecycle.outcome === "completed" && observation.signals.verifier === true && FRICTION_COUNTERS.every((field) => (observation.signals[field] ?? 0) === 0);
}

function historySet(history) {
  if (history === undefined || history === null) return new Set();
  if (!Array.isArray(history) || history.some((value) => !SHA256.test(value))) fail("candidate_history_invalid");
  return new Set(history);
}

function terminalPacket({ capability, observation, gated, diagnosis, duplicate, traceFingerprint, ledgerFingerprint }) {
  const diagnosed = diagnosis?.status === "diagnosed" ? diagnosis.diagnosis : null;
  let outcome = "investigate";
  let reason = diagnosis?.reason ?? "jev_abstained";
  let proposal = null;
  if (gated) {
    outcome = "no_op";
    reason = "no_friction_signals";
  } else if (diagnosed?.actionability === "no_op") {
    outcome = "no_op";
    reason = "jev_no_material_friction";
  } else if (diagnosed?.actionability === "investigate") {
    outcome = "investigate";
    reason = "jev_requires_investigation";
  } else if (diagnosed?.actionability === "candidate") {
    const candidateFingerprint = sha(canonical({ pattern: diagnosed.pattern, target: diagnosed.target, trace: traceFingerprint, ledger: ledgerFingerprint }));
    if (duplicate) reason = "duplicate_candidate";
    else if (capability !== "propose_reviewed") reason = "proposal_capability_not_enabled";
    else {
      outcome = "candidate";
      reason = "bounded_reviewed_follow_up";
      proposal = {
        schema_version: 1,
        executable: false,
        requested_route: "plan-implement",
        candidate_fingerprint: candidateFingerprint,
        pattern: diagnosed.pattern,
        target: diagnosed.target,
        editable_surfaces: TARGET_SURFACES[diagnosed.target],
        requirements: ["user-invoked", "root PLAN.md", "Status: READY", "independent review", "deterministic validation"],
      };
    }
  }
  return {
    schema_version: 1,
    controller: "jev-self-improvement-v1",
    capability,
    authority: "diagnostic_and_non_executable_proposal_only",
    terminal: true,
    outcome,
    reason,
    observation: {
      binding: observation.binding,
      completeness: observation.completeness,
      terminal: observation.lifecycle.outcome,
      verifier: observation.signals.verifier,
      counters: {
        tool_calls: observation.signals.tool_calls,
        tool_errors: observation.signals.tool_errors,
        validation_failures: observation.signals.validation_failures,
        review_rework: observation.signals.review_rework,
        plan_rework: observation.signals.plan_rework,
        compactions: observation.signals.compactions,
        retries: observation.signals.retries,
      },
    },
    diagnosis: diagnosed,
    jev: { calls: gated ? 0 : 1, retries: 0, status: gated ? "skipped" : diagnosis?.status ?? "abstain", provider: diagnosis?.provenance?.provider ?? null, model: diagnosis?.provenance?.model ?? null },
    traditional_llm: { calls: 0 },
    proposal,
    private_bindings: { trace_sha256: traceFingerprint, ledger_sha256: ledgerFingerprint },
  };
}

export async function runSelfImprovementController({ traceText, ledgerText, run, capabilityReceipt = null, history = null, diagnose }) {
  if (typeof traceText !== "string" || typeof ledgerText !== "string" || SECRET_LIKE.test(traceText) || SECRET_LIKE.test(ledgerText)) fail("secret_like_input_rejected");
  const observation = analyzeTraceEpisode({ adapter: "pi", traceText, ledgerText, run });
  if (observation.binding !== "native_correlated") fail("native_correlation_required");
  if (observation.completeness !== "complete" || observation.reason_codes.length !== 0 || observation.lifecycle.terminal !== true) fail("complete_terminal_observation_required");
  const projectedState = prepareSelfImprovementDiagnosisState(observation);
  const serializedProjection = canonical(projectedState);
  for (const privateValue of [run, observation.observation_id, sha(traceText), sha(ledgerText)]) if (serializedProjection.includes(privateValue)) fail("private_projection_leak");
  const controllerFingerprint = controllerSourceFingerprint();
  const capability = capabilityReceipt ? (validateProposalCapabilityReceipt(capabilityReceipt, controllerFingerprint), "propose_reviewed") : "diagnose_shadow";
  const gated = frictionFree(observation);
  let diagnosis = null;
  if (!gated) {
    try {
      diagnosis = await diagnose({ observation, projectedState });
    } catch {
      diagnosis = { schema_version: 1, profile_id: "self-improvement-diagnosis", authority: "diagnostic", status: "abstain", diagnosis: null, provenance: null, reason: "provider_error" };
    }
  }
  const traceFingerprint = sha(traceText);
  const ledgerFingerprint = sha(ledgerText);
  const candidateFingerprint = diagnosis?.status === "diagnosed" && diagnosis.diagnosis?.actionability === "candidate"
    ? sha(canonical({ pattern: diagnosis.diagnosis.pattern, target: diagnosis.diagnosis.target, trace: traceFingerprint, ledger: ledgerFingerprint }))
    : null;
  const duplicate = candidateFingerprint ? historySet(history).has(candidateFingerprint) : false;
  return terminalPacket({ capability, observation, gated, diagnosis, duplicate, traceFingerprint, ledgerFingerprint });
}

function readJsonRegular(path, maxBytes = 256 * 1024) {
  return JSON.parse(readBoundedRegularFile(path, { maxBytes }));
}

export function validatePrivateOutputDirectory(outputPath, root = ".") {
  const rootPath = resolve(root);
  const canonicalRoot = realpathSync(rootPath);
  let privateRoot = rootPath;
  for (const segment of [".workflow", "jev-self-improvement", "private"]) {
    privateRoot = resolve(privateRoot, segment);
    if (!existsSync(privateRoot)) mkdirSync(privateRoot);
    const stat = lstatSync(privateRoot);
    const expected = resolve(canonicalRoot, relative(rootPath, privateRoot));
    if (stat.isSymbolicLink() || !stat.isDirectory() || realpathSync(privateRoot) !== expected) fail("output_root_symlink_rejected");
  }
  const output = resolve(outputPath);
  const rel = relative(privateRoot, output);
  if (!rel || rel === ".." || rel.startsWith(`..${sep}`) || dirname(output) !== privateRoot || existsSync(output)) fail("output_path_invalid");
  return output;
}

function argument(argv, name) {
  const index = argv.indexOf(name);
  return index >= 0 ? argv[index + 1] : null;
}

export async function runSelfImprovementControllerCli(argv = process.argv.slice(2), env = process.env) {
  if (!argv.includes("--live")) fail("explicit_live_required");
  const tracePath = argument(argv, "--trace");
  const ledgerPath = argument(argv, "--ledger");
  const run = argument(argv, "--run");
  const outputPath = argument(argv, "--output");
  if (!tracePath || !ledgerPath || !run || !outputPath) fail("required_option_missing");
  if (!env.TYPESAFE_API_KEY) fail("typesafe_credential_missing");
  const traceText = readBoundedRegularFile(tracePath);
  const ledgerText = readBoundedRegularFile(ledgerPath);
  const capabilityPath = argument(argv, "--capability-receipt");
  const historyPath = argument(argv, "--history");
  const policy = { ...loadSemanticProfilePolicy(), max_retries: 0 };
  const packet = await runSelfImprovementController({
    traceText,
    ledgerText,
    run,
    capabilityReceipt: capabilityPath ? readJsonRegular(capabilityPath) : null,
    history: historyPath ? readJsonRegular(historyPath) : null,
    diagnose: ({ observation }) => evaluateSelfImprovementDiagnosis({ observation, policy, allowProviderEgress: true, persistReceipt: false }),
  });
  const output = validatePrivateOutputDirectory(outputPath);
  mkdirSync(output);
  writeFileSync(resolve(output, "packet.json"), `${JSON.stringify(packet, null, 2)}\n`, { mode: 0o600 });
  return packet;
}
