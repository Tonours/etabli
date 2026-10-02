import { execFileSync } from "node:child_process";
import { realpathSync, statSync } from "node:fs";
import { join } from "node:path";
import { selectActiveLedger, inspectLedgerFile } from "./ledger-integrity.mjs";
import { buildHandoff } from "./session-handoff.mjs";
import { readEvidence } from "./review-evidence-pack.mjs";
import { sha256 } from "./review-run-receipt.mjs";

export const PAGE_SIZE = 8;

export function projectRoot(cwd) {
  const directory = realpathSync(cwd);
  if (!statSync(directory).isDirectory()) throw new TypeError("cwd must be an existing directory");
  try {
    return realpathSync(execFileSync("git", ["rev-parse", "--show-toplevel"], { cwd: directory, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim());
  } catch { return directory; }
}

export function selectRun(root, run) {
  if (!run) return selectActiveLedger(root);
  if (!/^[a-z0-9][a-z0-9_-]*$/.test(run)) throw new TypeError("Invalid workflow run slug");
  const path = join(root, ".workflow", run, "events.jsonl");
  const ledger = inspectLedgerFile(path, run);
  return { ledger: ledger.valid ? { ...ledger, path, run } : null, reason: ledger.valid ? null : ledger.reason, historical: true };
}

export function checkpointHistory(events, run) {
  const requests = new Map();
  return events.flatMap((event, index) => {
    const foreignRun = run && typeof event.run === "string" && event.run.trim().length > 0 && event.run !== run;
    if (event.event !== "human_checkpoint" || foreignRun) return [];
    const detail = event.detail || {};
    const decision = typeof detail.decision === "string" ? detail.decision.trim().toLowerCase() : "";
    const state = ["requested", "pending"].includes(decision) ? "requested"
      : ["granted", "approved", "allowed"].includes(decision) ? "granted"
        : ["denied", "rejected", "refused", "revoked"].includes(decision) ? "refused" : "unknown";
    const targeted = typeof detail.target === "string" && detail.target.length > 0;
    const key = JSON.stringify([detail.category, detail.target, detail.consent_class || "unknown"]);
    const permission = detail.consent_class === "permission_request";
    const matchingRequest = permission && targeted ? requests.get(key) : undefined;
    if (state === "requested" && permission && targeted) requests.set(key, index + 1);
    if ((state === "granted" || state === "refused") && permission && targeted) requests.delete(key);
    return [{ ...detail, sequence: index + 1, ts: event.ts, state,
      request_sequence: state === "requested" ? null : matchingRequest ?? null,
      orphan_decision: ["granted", "refused"].includes(state) && matchingRequest === undefined,
      authority: "historical journal record; never a current Claude permission" }];
  });
}

function recordedRoute(root, events) {
  const event = events.findLast((event) => event.event === "route_decided");
  if (!event) return { route: null, reason: "No route_decided event recorded", contract: null };
  const path = event.detail.contract_path || "workflow/spec.md";
  let contract;
  try {
    const evidence = readEvidence(root, path, { maxBytes: 16_777_216 });
    contract = { path, sha256: evidence.file_sha256, recorded_sha256: event.detail.contract_sha256 || null,
      changed: event.detail.contract_sha256 ? event.detail.contract_sha256 !== evidence.file_sha256 : null };
  } catch (error) { contract = { path, sha256: null, recorded_sha256: event.detail.contract_sha256 || null, changed: null, error: error.message }; }
  return { ...event.detail, ts: event.ts, source: "route_decided", contract };
}

export function workflowSnapshot(root, { run, page = 0 } = {}) {
  const selection = selectRun(root, run);
  const ledger = selection.ledger;
  const events = ledger?.events || [];
  const totalPages = Math.max(1, Math.ceil(events.length / PAGE_SIZE));
  const currentPage = Math.min(page, totalPages - 1);
  const source = ledger ? `.workflow/${ledger.run}/events.jsonl` : null;
  let ledgerHash = null;
  if (ledger) {
    const evidence = readEvidence(root, source, { maxBytes: 16_777_216 });
    const current = evidence.text.split("\n").filter((line) => line.trim()).map((line) => JSON.parse(line));
    if (sha256(JSON.stringify(current)) !== sha256(JSON.stringify(events))) throw new Error("Journal changed during projection; refresh on a stable snapshot");
    ledgerHash = evidence.file_sha256;
  }
  let resume = null, resumeError = null;
  if (ledger) {
    try { resume = buildHandoff({ repo: root, workflowDir: join(root, ".workflow"), run: ledger.run }); }
    catch (error) { resumeError = `Canonical handoff unavailable: ${error.message}`; }
  }
  return {
    selection: { run: ledger?.run || run || null, reason: selection.reason, valid: !!ledger,
      historical: selection.historical || false, terminal: ledger?.terminal ? events.at(-1)?.event : null,
      source, ledger_sha256: ledgerHash },
    resume, resume_error: resumeError,
    routing: recordedRoute(root, events),
    journal: { total: events.length, page: currentPage, pages: totalPages, page_size: PAGE_SIZE, source,
      items: events.slice(currentPage * PAGE_SIZE, (currentPage + 1) * PAGE_SIZE).map((event, index) => ({ ...event, sequence: currentPage * PAGE_SIZE + index + 1 })) },
    checkpoints: checkpointHistory(events, ledger?.run),
    proofs: events.flatMap((event, index) => ["validation_run", "validation_failed", "review_completed", "adversary_completed"].includes(event.event)
      ? [{ sequence: index + 1, ts: event.ts, event: event.event, detail: event.detail,
        revision: null, binding: "journal record without an attested revision binding" }] : []),
  };
}
