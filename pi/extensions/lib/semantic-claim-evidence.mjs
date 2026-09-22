import { closeSync, constants, fstatSync, mkdtempSync, openSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, isAbsolute, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { readEvidence, parseEvidencePointer } from "../../../scripts/lib/review-evidence-pack.mjs";
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

function checkedClaims(claimsFile, cwd) {
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
  return { report, source_sha256: fingerprint(source) };
}

function stateFromClaim({ report, source_sha256 }, { claimIndex, evidenceText = null, cwd = process.cwd(), version = "v1", conclusion = null }, evidenceCache = new Map()) {
  if (!Number.isSafeInteger(claimIndex) || claimIndex < 0) throw new Error("invalid claim index");
  if (!["v1", "v2"].includes(version)) throw new Error("unknown claim evidence version");
  const claim = report.claims?.[claimIndex];
  if (!claim || claim.ok !== true) throw new Error("claim structural check failed");
  const external = /^https?:\/\//i.test(claim.evidence.replace(/`/g, "").trim());
  const pointer = parseEvidencePointer(claim.evidence);
  const localPath = version === "v2" ? (external ? null : resolve(cwd, pointer.path)) : localEvidencePath(claim.evidence, cwd);
  if (!external && !localPath) throw new Error("claim structural check failed");
  let excerpt = null;
  if (version === "v2" && localPath) {
    const key = JSON.stringify([localPath,pointer.start,pointer.end]);
    if (!evidenceCache.has(key)) {
      try { evidenceCache.set(key,readEvidence(cwd,pointer.path,{...pointer,allowAbsolute:true})); }
      catch { throw new Error("claim structural check failed"); }
    }
    excerpt = evidenceCache.get(key);
  }
  const evidence = excerpt ? excerpt.text : localPath ? readRegularFile(localPath, 6500) : typeof evidenceText === "string" && evidenceText.trim() ? evidenceText.trim() : null;
  if (!evidence) throw new Error("external evidence text required");
  const state = { claim: claim.claim, evidence, structural_valid: true,
    ...(version === "v2" ? { candidate_version: "claim-evidence-v2", claim_source_sha256: source_sha256, evidence_source: excerpt ?? { path: claim.evidence, excerpt_sha256: fingerprint(evidence), text: evidence }, ...(conclusion ? { conclusion } : {}) } : {}) };
  verifiedStates.set(state, fingerprint(state));
  return state;
}

export function prepareClaimEvidenceState(options) {
  const cwd = options.cwd ?? process.cwd();
  return stateFromClaim(checkedClaims(options.claimsFile,cwd),{...options,cwd});
}

export function prepareClaimEvidenceStates({ claimIndices, ...options }) {
  const cwd = options.cwd ?? process.cwd();
  const snapshot = checkedClaims(options.claimsFile,cwd), cache = new Map();
  return claimIndices.map((index) => {
    try { return { index, state: stateFromClaim(snapshot,{...options,cwd,claimIndex:index},cache) }; }
    catch { return { index, result:{outcome:"invalid",action:"repair_evidence",error:"claim_preparation_failed"} }; }
  });
}

export function isPreparedClaimEvidenceState(state) {
  return verifiedStates.get(state) === fingerprint(state);
}


export function prepareClaimEvidenceBatchState(items) {
  if(!Array.isArray(items)||!items.length||items.some(item=>!Number.isSafeInteger(item.index)||item.index<0||
    !isPreparedClaimEvidenceState(item.state)||item.state.candidate_version!=="claim-evidence-v2"))
    throw new Error("claim batch requires prepared v2 states");
  const first=items[0].state;
  if(new Set(items.map(item=>item.index)).size!==items.length || items.some(item=>
    fingerprint(item.state.evidence_source)!==fingerprint(first.evidence_source)||item.state.conclusion!==first.conclusion))
    throw new Error("claim batch requires identical prepared evidence and conclusion");
  const state={evidence:first.evidence_source,claims:items.map(({index,state})=>({id:index,claim:state.claim})),
    ...(first.conclusion?{conclusion:first.conclusion}:{})};
  verifiedStates.set(state,fingerprint(state));
  return state;
}
