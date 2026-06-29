import { readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";

const DECISION_MARKERS = [
  "we decided",
  "chosen",
  "instead of",
  "rather than",
  "trade-off",
  "opted for",
  "décidé",
  "on choisit",
  "plutôt que",
  "au lieu de",
  "écarté",
];

const STRUCTURAL_PATTERNS = [
  /(^|\/)package\.json$/,
  /(^|\/)tsconfig[^/]*\.json$/,
  /(^|\/)[^/]*\.config\.(ts|js|mjs|cjs)$/,
  /(^|\/)schema\.(prisma|sql|graphql)$/,
  /(^|\/)migrations\//,
  /(^|\/)Dockerfile$/,
  /(^|\/)docker-compose[^/]*\.ya?ml$/,
  /(^|\/)\.github\/workflows\//,
  /\.proto$/,
  /(^|\/)auth(\/|\.|$)/i,
  /(^|\/)middleware(\/|\.|$)/i,
];

const SUGGESTION =
  "Possible architecture decision detected. Run /adr to record it if it is hard to reverse, surprising without context, and the result of a real trade-off.";

function porcelainPaths(cwd, pathspec) {
  let out;
  try {
    const args = ["status", "--porcelain", "--untracked-files=all"];
    if (pathspec) args.push("--", pathspec);
    out = execFileSync("git", args, { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] });
  } catch {
    return [];
  }
  return out
    .split("\n")
    .filter((line) => line.trim() !== "")
    .map((line) => {
      const rest = line.slice(3);
      const arrow = rest.indexOf(" -> ");
      return arrow === -1 ? rest : rest.slice(arrow + 4);
    });
}

function hasStructuralChange(cwd) {
  return porcelainPaths(cwd).some((p) => STRUCTURAL_PATTERNS.some((re) => re.test(p)));
}

function adrAlreadyTouched(cwd) {
  return porcelainPaths(cwd, "docs/adr").length > 0;
}

function lastAssistantFromTranscript(transcriptPath) {
  if (!transcriptPath) return "";
  let raw;
  try {
    raw = readFileSync(transcriptPath, "utf8");
  } catch {
    return "";
  }
  const lines = raw.split("\n").filter((l) => l.trim() !== "");
  for (let i = lines.length - 1; i >= 0; i--) {
    let entry;
    try {
      entry = JSON.parse(lines[i]);
    } catch {
      continue;
    }
    const role = entry.role ?? entry.message?.role;
    if (role !== "assistant") continue;
    const content = entry.content ?? entry.message?.content;
    if (typeof content === "string") return content;
    if (Array.isArray(content)) {
      return content
        .map((part) => (typeof part === "string" ? part : part?.text ?? ""))
        .join(" ");
    }
  }
  return "";
}

function hasDecisionSignal(input) {
  const primary = typeof input.last_assistant_message === "string" ? input.last_assistant_message : "";
  const text = (primary || lastAssistantFromTranscript(input.transcript_path)).toLowerCase();
  if (text === "") return false;
  return DECISION_MARKERS.some((marker) => text.includes(marker));
}

const input = JSON.parse(readFileSync(0, "utf8") || "{}");
const cwd = input.cwd || process.cwd();

if (
  !adrAlreadyTouched(cwd) &&
  hasStructuralChange(cwd) &&
  hasDecisionSignal(input)
) {
  process.stdout.write(`${JSON.stringify({ systemMessage: SUGGESTION })}\n`);
}

process.exit(0);
