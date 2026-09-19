import { closeSync, constants, fstatSync, mkdtempSync, openSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, isAbsolute, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { fingerprint } from "./semantic-judgment.mjs";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const CHECKER = resolve(ROOT, "scripts/claim-evidence-check");
const verifiedStates = new WeakMap();

function readRegularFile(path, maxBytes) {
  let descriptor;
  try {
    descriptor = openSync(resolve(path), constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
    const status = fstatSync(descriptor);
    if (!status.isFile()) throw new Error("evidence input must be a regular file");
    if (status.size > maxBytes) throw new Error("evidence input too large");
    return readFileSync(descriptor, "utf8");
  } finally {
    if (descriptor !== undefined) closeSync(descriptor);
  }
}

function isRegularFile(path) {
  let descriptor;
  try {
    descriptor = openSync(resolve(path), constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
    return fstatSync(descriptor).isFile();
  } catch { return false; }
  finally { if (descriptor !== undefined) closeSync(descriptor); }
}

function localEvidencePath(pointer, cwd) {
  const token = pointer.replace(/`/g, "").trim().split(/\s+/)[0];
  if (/^https?:\/\//i.test(token)) return null;
  const bare = token.replace(/:\d+(?::\d+)?$/, "");
  if (isAbsolute(bare)) return isRegularFile(bare) ? bare : undefined;
  return [resolve(ROOT, bare), resolve(cwd, bare)].find(isRegularFile);
}

export function prepareClaimEvidenceState({ claimsFile, claimIndex, evidenceText = null, cwd = process.cwd() }) {
  if (!Number.isInteger(claimIndex) || claimIndex < 0) throw new Error("invalid claim index");
  const source = readRegularFile(claimsFile, 1_048_576);
  const snapshotRoot = mkdtempSync(join(tmpdir(), "etabli-claim-check-"));
  const snapshot = join(snapshotRoot, "claims.md");
  let checked;
  try {
    writeFileSync(snapshot, source, { mode: 0o600, flag: "wx" });
    checked = spawnSync(CHECKER, ["--json", snapshot], { cwd: resolve(cwd), encoding: "utf8", maxBuffer: 1_048_576 });
  } finally { rmSync(snapshotRoot, { recursive: true, force: true }); }
  let report;
  try { report = JSON.parse(checked.stdout); } catch { throw new Error("claim structural checker failed"); }
  const claim = report.claims?.[claimIndex];
  if (!claim || claim.ok !== true) throw new Error("claim structural check failed");
  const external = /^https?:\/\//i.test(claim.evidence.replace(/`/g, "").trim());
  const localPath = localEvidencePath(claim.evidence, cwd);
  if (!external && !localPath) throw new Error("claim structural check failed");
  const evidence = localPath ? readRegularFile(localPath, 6500) : typeof evidenceText === "string" && evidenceText.trim() ? evidenceText.trim() : null;
  if (!evidence) throw new Error("external evidence text required");
  const state = { claim: claim.claim, evidence, structural_valid: true };
  verifiedStates.set(state, fingerprint(state));
  return state;
}

export function isPreparedClaimEvidenceState(state) {
  return verifiedStates.get(state) === fingerprint(state);
}
