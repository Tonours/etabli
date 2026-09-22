import { closeSync, constants, fstatSync, openSync, readFileSync, realpathSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { isAbsolute, relative, resolve, sep } from "node:path";
import { sha256 } from "./review-run-receipt.mjs";

export function readEvidence(root, path, { start, end, maxBytes = 6500, allowAbsolute = false } = {}) {
  const project = realpathSync(root), absolute = resolve(project, path), real = realpathSync(absolute);
  const rel = relative(project, real);
  if ((!allowAbsolute || !isAbsolute(path)) && (rel === ".." || rel.startsWith(`..${sep}`) || isAbsolute(rel))) throw new Error("evidence escapes project root");
  const fd = openSync(absolute, constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
  try {
    const stat = fstatSync(fd);
    if (!stat.isFile() || stat.size > 16_777_216) throw new Error("evidence must be a regular file at most 16 MiB; supply a bounded snapshot for larger inputs");
    const bytes = readFileSync(fd), text = bytes.toString("utf8");
    if (text.includes("\0")) throw new Error("binary evidence needs an explicit text projection");
    const lines = text.split(/\r?\n/);
    if (start !== undefined && (!Number.isSafeInteger(start) || start < 1 || start > lines.length)) throw new Error("invalid evidence line range");
    const first = start ?? 1, last = end ?? (start === undefined ? lines.length : start);
    if (!Number.isSafeInteger(last) || last < first || last > lines.length) throw new Error("invalid evidence line range");
    const excerpt = start === undefined && end === undefined ? text : lines.slice(first-1,last).join("\n");
    if (Buffer.byteLength(excerpt) > maxBytes) throw new Error("evidence excerpt too large; supply an explicit narrower line range");
    return { path: isAbsolute(path) && allowAbsolute ? real : rel, file_sha256: sha256(bytes), start: first, end: last, text: excerpt, excerpt_sha256: sha256(excerpt) };
  } finally { closeSync(fd); }
}

export function parseEvidencePointer(pointer) {
  const text = pointer.replace(/`/g, "").trim();
  const match = text.match(/^(.*?):(\d+)(?:[-:](\d+))?$/);
  return match ? { path: match[1], start: Number(match[2]), end: Number(match[3] ?? match[2]) } : { path: text };
}

export function createReviewEvidencePack({ root, base = "HEAD", excerpts = [], criteria = [] }) {
  const started = performance.now();
  const project = realpathSync(root);
  const git = (args) => execFileSync("git", args, { cwd: project, encoding: "utf8", maxBuffer: 32 * 1024 * 1024 });
  // Resolve the ref before using it as a positional argument.
  const baseSha = git(["rev-parse", "--verify", `${base}^{commit}`]).trim();
  const patch = git(["diff", "--binary", "--no-ext-diff", baseSha, "--"]);
  const changed = git(["diff", "--name-only", "-z", baseSha, "--"]).split("\0").filter(Boolean);
  const untracked = git(["ls-files", "--others", "--exclude-standard", "-z"]).split("\0").filter(Boolean);
  const files = [...new Set([...changed, ...untracked])].sort().map((path) => {
    try {
      const evidence = readEvidence(project, path, { maxBytes: 16_777_216 });
      return { path, status: untracked.includes(path) ? "untracked" : "changed", sha256: evidence.file_sha256,
        ...(untracked.includes(path) ? { content: evidence.text } : {}) };
    } catch (error) {
      if (error.code === "ENOENT") return { path, status: "deleted", sha256: null };
      return { path, status: "unavailable", sha256: null, reason: "regular_text_snapshot_required" };
    }
  });
  const selected = excerpts.map(({ path, start, end }) => readEvidence(project, path, { start, end }));
  if (git(["diff", "--binary", "--no-ext-diff", baseSha, "--"]) !== patch) throw new Error("patch changed during snapshot; recapture review evidence");
  const snapshot = { base_sha: baseSha, patch, files, excerpts: selected, criteria };
  return { schema_version: 1, ...snapshot, snapshot_sha256: sha256(JSON.stringify(snapshot)),
    preparation_ms:performance.now()-started,
    complete: files.every((file) => file.status !== "unavailable"), authority: "raw_evidence_only" };
}

export function reviewRoleInput(pack, role) {
  if (!["logic", "spec", "adversary-code", "lead"].includes(role)) throw new Error("invalid evidence role");
  return { role, snapshot_sha256: pack.snapshot_sha256, complete: pack.complete,
    patch: pack.patch, files: pack.files, excerpts: pack.excerpts,
    ...(role === "logic" ? {} : { criteria: pack.criteria }),
    access: "full_patch_and_project_read_required", missing_context: "retrieve_or_escalate", prior_verdicts: [] };
}

export function invalidatedEvidence(previous, current) {
  const references = (pack) => [...pack.files.map((file) => ({ path: file.path, hash: file.sha256 })),
    ...pack.excerpts.map((excerpt) => ({ path: excerpt.path, hash: excerpt.file_sha256 }))];
  const next = new Map(references(current).map((ref) => [ref.path,ref.hash]));
  return [...new Set(references(previous).filter((ref) => ref.hash === null || next.get(ref.path) !== ref.hash).map((ref) => ref.path))];
}
