import { readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { readHookInput } from "./workflow-router-lib.mjs";
import { hasDecisionSignal } from "./adr-signal-policy.mjs";

const HOOK_FILENAME = "detect-adr-signal.mjs";

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

const HUMAN_NOTE =
  "Possible architecture decision detected. /adr was handed to the model, which decides whether it qualifies.";

const MODEL_INSTRUCTION = [
  "A structural file is uncommitted in this repo and your last message reads like a decision.",
  "Invoke the adr skill, cheapest work first: apply its three-condition gate",
  "(hard to reverse, surprising without context, a real tradeoff) using only what you already know from this turn.",
  "If any condition fails, say so in one line and stop — do not run git, do not read docs/adr.",
  "Only when all three hold, continue with the skill's grounding, draft and approval steps.",
].join(" ");

function unquotePath(path) {
  if (!path.startsWith('"') || !path.endsWith('"') || path.length < 2)
    return path;
  return path.slice(1, -1).replace(/\\(.)/g, "$1");
}

function porcelainPaths(cwd) {
  let out;
  try {
    const args = ["status", "--porcelain", "--untracked-files=all"];
    out = execFileSync("git", args, {
      cwd,
      encoding: "utf8",
      maxBuffer: 64 * 1024 * 1024,
      stdio: ["ignore", "pipe", "ignore"],
    });
  } catch {
    return [];
  }
  return out
    .split("\n")
    .filter((line) => line.trim() !== "")
    .flatMap((line) => {
      const rest = line.slice(3);
      const arrow = rest.lastIndexOf(" -> ");
      return arrow === -1
        ? [rest]
        : [rest.slice(0, arrow), rest.slice(arrow + 4)];
    })
    .map(unquotePath);
}

function hasStructuralChange(cwd) {
  return porcelainPaths(cwd).some((p) =>
    STRUCTURAL_PATTERNS.some((re) => re.test(p)),
  );
}

function readTranscript(transcriptPath) {
  if (!transcriptPath) return { lines: [], readable: true };
  try {
    const lines = readFileSync(transcriptPath, "utf8")
      .split("\n")
      .filter((l) => l.trim() !== "");
    return { lines, readable: true };
  } catch {
    return { lines: [], readable: false };
  }
}

function parseEntry(line) {
  let entry;
  try {
    entry = JSON.parse(line);
  } catch {
    return null;
  }
  return typeof entry === "object" && entry !== null ? entry : null;
}

function alreadyNudgedThisSession(transcriptPath) {
  const { lines, readable } = readTranscript(transcriptPath);
  if (!readable) return true;
  return lines.some((line) => {
    if (!line.includes("hook_blocking_error")) return false;
    const attachment = parseEntry(line)?.attachment;
    if (
      attachment?.type !== "hook_blocking_error" ||
      attachment.hookEvent !== "Stop"
    )
      return false;
    const command = attachment.blockingError?.command;
    return typeof command === "string" && command.includes(HOOK_FILENAME);
  });
}

function lastAssistantFromTranscript(transcriptPath) {
  const { lines } = readTranscript(transcriptPath);
  for (let i = lines.length - 1; i >= 0; i--) {
    const entry = parseEntry(lines[i]);
    if (!entry) continue;
    const role = entry.role ?? entry.message?.role;
    if (role !== "assistant") continue;
    const content = entry.content ?? entry.message?.content;
    if (typeof content === "string") return content;
    if (Array.isArray(content)) {
      return content
        .map((part) => (typeof part === "string" ? part : (part?.text ?? "")))
        .join(" ");
    }
  }
  return "";
}

function lastAssistantText(input) {
  const primary =
    typeof input.last_assistant_message === "string"
      ? input.last_assistant_message
      : "";
  return primary || lastAssistantFromTranscript(input.transcript_path);
}

const input = readHookInput();
const cwd = input.cwd || process.cwd();

if (
  input.stop_hook_active !== true &&
  hasDecisionSignal(lastAssistantText(input)) &&
  hasStructuralChange(cwd) &&
  !alreadyNudgedThisSession(input.transcript_path)
) {
  // no listener makes a closed pipe an unhandled 'error': stack trace on stderr, exit 1
  process.stdout.on("error", () => process.exit(0));
  process.stdout.write(
    `${JSON.stringify({ decision: "block", reason: MODEL_INSTRUCTION, systemMessage: HUMAN_NOTE })}\n`,
  );
}
