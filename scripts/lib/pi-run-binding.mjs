import { createHash } from "node:crypto";

export const PI_RUN_BINDING_TYPE = "etabli.workflow-run-binding";
export const PI_RUN_BINDING_VERSION = 1;
const DOMAIN = "etabli.pi-session-run-ledger.v1";

function canonicalJson(value) {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  if (value && typeof value === "object") return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonicalJson(value[key])}`).join(",")}}`;
  return JSON.stringify(value);
}

export function createPiRunBinding(sessionId, run, genesis) {
  if (typeof sessionId !== "string" || !sessionId || typeof run !== "string" || !run || !genesis || typeof genesis !== "object" || Array.isArray(genesis)) throw new Error("pi run binding input invalid");
  const fingerprint = createHash("sha256")
    .update(DOMAIN)
    .update("\0")
    .update(sessionId)
    .update("\0")
    .update(run)
    .update("\0")
    .update(canonicalJson(genesis))
    .digest("hex");
  return { schema_version: PI_RUN_BINDING_VERSION, algorithm: "sha256", fingerprint };
}

export function isPiRunBinding(value) {
  return Boolean(value)
    && typeof value === "object"
    && !Array.isArray(value)
    && Object.keys(value).sort().join(",") === "algorithm,fingerprint,schema_version"
    && value.schema_version === PI_RUN_BINDING_VERSION
    && value.algorithm === "sha256"
    && typeof value.fingerprint === "string"
    && /^[0-9a-f]{64}$/.test(value.fingerprint);
}
