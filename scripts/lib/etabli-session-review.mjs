import { execFileSync } from "node:child_process";
import { lstatSync } from "node:fs";
import { join } from "node:path";
import { createReviewEvidencePack, invalidatedEvidence } from "./review-evidence-pack.mjs";
import { sha256 } from "./review-run-receipt.mjs";

export const MAX_JSON_BYTES = 1_048_576;
const PATCH_PREVIEW_BYTES = 96 * 1024;

function boundedPreview(result) {
  const bytes = Buffer.from(result.patch, "utf8");
  const candidate = (length) => {
    const patch = new TextDecoder("utf-8").decode(bytes.subarray(0, length), { stream: true });
    const shown = Buffer.byteLength(patch);
    return { ...result, patch, patch_preview_bytes: shown, patch_preview_truncated: shown < bytes.length };
  };
  let selected = candidate(0);
  const metadataBytes = Buffer.byteLength(JSON.stringify(selected));
  if (metadataBytes > MAX_JSON_BYTES) {
    const sizes = Object.fromEntries(["proofs", "files", "excerpts", "plan"].map((key) => [key, Buffer.byteLength(JSON.stringify(key === "files" ? result.identity.files : result[key]))]));
    const largest = Object.keys(sizes).sort((a, b) => sizes[b] - sizes[a])[0];
    const action = largest === "proofs" ? "inspect this run's journal directly for its full proofs" : largest === "files" ? "choose a closer Git base or inspect Git directly" : largest === "plan" ? "inspect the current plan directly or narrow its execution contract" : "reduce explicit excerpts or inspect their files directly";
    throw new Error(`Review metadata: ${metadataBytes} bytes exceeds 1 MiB; proofs=${sizes.proofs} bytes, files=${sizes.files} bytes, excerpts=${sizes.excerpts} bytes, plan=${sizes.plan} bytes; ${largest} dominates: ${action} (metadata is not clipped).`);
  }
  let low = 0, high = Math.min(bytes.length, PATCH_PREVIEW_BYTES);
  while (low <= high) {
    const middle = Math.floor((low + high) / 2), preview = candidate(middle);
    if (Buffer.byteLength(JSON.stringify(preview)) <= MAX_JSON_BYTES) { selected = preview; low = middle + 1; }
    else high = middle - 1;
  }
  return selected;
}

export function reviewDossier(root, workflow, { base = "HEAD", excerpts = [], previous } = {}) {
  const head = () => execFileSync("git", ["rev-parse", "HEAD"], { cwd: root, encoding: "utf8" }).trim();
  const before = head();
  let pack;
  try { pack = createReviewEvidencePack({ root, base, excerpts }); }
  catch (error) {
    if (error.code === "ENOBUFS") throw new Error("Git diff exceeds the canonical 32 MiB capture buffer (exact bytes unknown); choose a closer Git base or inspect git diff directly.");
    if (error.message.startsWith("Command failed: git rev-parse --verify")) throw new Error(`Base ref unresolvable: ${base}; restore the ref or make a new capture with an existing base.`);
    throw error;
  }
  if (head() !== before) throw new Error("HEAD changed during capture; recapture evidence");
  const files = pack.files.map(({ content, ...file }) => ({ ...file,
    ...(file.status === "deleted" && lstatSync(join(root, file.path), { throwIfNoEntry: false }) ? { status: "unavailable", reason: "regular_text_snapshot_required" } : {}),
    ...(content === undefined ? {} : { content_bytes: Buffer.byteLength(content) }) }));
  const complete = pack.complete && files.every((file) => file.status !== "unavailable");
  const proofsHash = sha256(JSON.stringify(workflow.proofs));
  const identity = { base_sha: pack.base_sha, head_sha: before, snapshot_sha256: pack.snapshot_sha256,
    root, run: workflow.selection.run, ledger_sha256: workflow.selection.ledger_sha256, proofs_sha256: proofsHash,
    files, plan:{state:pack.plan.state,contract_sha256:pack.plan.contract_sha256}, excerpts: pack.excerpts.map(({ text, ...excerpt }) => excerpt) };
  const stableDeletions = new Set(identity.files.filter((file) => file.status === "deleted" && file.sha256 === null &&
    previous?.files.some((old) => old.path === file.path && old.status === "deleted" && old.sha256 === null)).map((file) => file.path));
  const changed = previous ? invalidatedEvidence(previous, identity).filter((path) => !stableDeletions.has(path)) : [];
  const reasons = [];
  if (previous) {
    for (const field of ["root", "run", "base_sha", "head_sha", "snapshot_sha256", "ledger_sha256", "proofs_sha256"]) {
      if (previous[field] !== identity[field]) reasons.push(`${field} changed`);
    }
    if (!complete) reasons.push("current capture incomplete");
  }
  return boundedPreview({ identity, complete, authority: pack.authority,
    state: !complete ? "incomplete" : previous && (changed.length || reasons.length) ? "invalidated" : previous ? "unchanged-at-check" : "captured",
    invalidated_files: changed, invalidation_reasons: reasons,
    patch: pack.patch, patch_sha256: sha256(pack.patch), patch_bytes: Buffer.byteLength(pack.patch),
    excerpts: pack.excerpts, plan:pack.plan, proofs: workflow.proofs,
    captured_at: new Date().toISOString(), freshness: "verified only at capture time; refresh after external edits",
  });
}
