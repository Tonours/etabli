import { homedir } from "node:os";
import { existsSync, realpathSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { skillCatalog } from "./etabli-session-catalog.mjs";
import { projectRoot, workflowSnapshot } from "./etabli-session-projection.mjs";
import { reviewDossier, MAX_JSON_BYTES } from "./etabli-session-review.mjs";
import { parseEvidencePointer } from "./review-evidence-pack.mjs";
import { preflight, prospectiveClose } from "./workflow-run-check.mjs";

export const ETABLI_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

export function sessionProjection({ cwd, run, page = 0, home = homedir(), sourceRoot = ETABLI_ROOT }) {
  if (!Number.isSafeInteger(page) || page < 0) throw new TypeError("Page must be a nonnegative integer");
  const root = projectRoot(cwd);
  const { proofs, ...workflow } = workflowSnapshot(root, { run, page });
  return { schema_version: 1, projection_only: true, root, captured_at: new Date().toISOString(),
    ...workflow,
    diagnostic: { state: "not-run", remediation: "Run preflight or prospective closure explicitly" },
    review: { state: "not-captured" }, usage: { source: "native Claude API required", context: null, cost: null, rateLimits: null, turn: null },
    skills: skillCatalog(sourceRoot, home) };
}

export function executeSessionCommand(mode, options, input = {}) {
  if (!["snapshot", "diagnostic", "review"].includes(mode)) throw new TypeError("Allowed commands: snapshot, diagnostic, review");
  if (mode === "snapshot") return sessionProjection(options);
  const root = projectRoot(options.cwd);
  const workflow = workflowSnapshot(root, { run: options.run });
  if (mode === "diagnostic") {
    const binding = { project_root: root, run: workflow.selection.run, captured_at: new Date().toISOString() };
    if (options.kind === "preflight") return { ...preflight(options.sourceRoot || ETABLI_ROOT), ...binding };
    if (options.kind !== "close") throw new TypeError("Diagnostic kind must be preflight or close");
    if (!workflow.selection.valid) return { ...binding, ready: false, error: workflow.selection.reason || "No validated selected run", scope: "prospective-event-chain", archive_checked: false };
    return { ...prospectiveClose(join(root, ".workflow"), workflow.selection.run), ...binding };
  }
  if (mode === "review") return reviewDossier(root, workflow, { base: options.base, excerpts: options.excerpts || [], previous: input.previous });
}

function argumentsOf(args) {
  const mode = args.shift();
  const options = { cwd: process.cwd(), excerpts: [] };
  while (args.length) {
    const flag = args.shift(), value = args.shift();
    if (typeof value !== "string" || !["--cwd", "--run", "--page", "--kind", "--base", "--excerpt"].includes(flag)) throw new TypeError("Expected --cwd/--run/--page/--kind/--base/--excerpt VALUE");
    if (flag === "--excerpt") options.excerpts.push(parseEvidencePointer(value));
    else options[flag.slice(2)] = flag === "--page" ? Number(value) : value;
  }
  return { mode, options };
}

async function inputOf() {
  if (process.stdin.isTTY) return {};
  process.stdin.setEncoding("utf8");
  let text = "";
  for await (const chunk of process.stdin) {
    text += chunk;
    if (Buffer.byteLength(text) > MAX_JSON_BYTES) throw new Error("JSON input exceeds 1 MiB; use a smaller selection");
  }
  const data = text.trim() ? JSON.parse(text) : {};
  if (!data || typeof data !== "object" || Array.isArray(data)) throw new TypeError("JSON input must be an object");
  return data;
}

async function main() {
  try {
    const { mode, options } = argumentsOf(process.argv.slice(2));
    const result = executeSessionCommand(mode, options, await inputOf());
    const text = JSON.stringify(result);
    if (Buffer.byteLength(text) > MAX_JSON_BYTES) {
      const [component, bytes] = Object.entries(result).map(([key, value]) => [key, Buffer.byteLength(JSON.stringify(value))]).sort((a, b) => b[1] - a[1])[0];
      const action = mode === "snapshot" ? component === "journal" ? "choose another journal page or select a shorter historical run; inspect the journal directly"
        : component === "skills" ? "inspect the skill source files directly"
        : "select a shorter historical run or inspect the journal/PLAN directly"
        : mode === "diagnostic" ? "inspect scripts/workflow-run-check directly" : "inspect the review helper directly";
      throw new Error(`${mode} JSON result: ${Buffer.byteLength(text)} bytes exceeds 1 MiB; ${component}=${bytes} bytes is largest; ${action}.`);
    }
    console.log(text);
  } catch (error) {
    console.log(JSON.stringify({ schema_version: 1, error: error.message }));
    process.exitCode = 1;
  }
}

if (process.argv[1] && existsSync(process.argv[1]) && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) await main();
