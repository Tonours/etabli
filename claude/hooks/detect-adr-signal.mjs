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

// git C-quotes non-ASCII paths as octal UTF-8 bytes, e.g. café ->
// "caf\303\251.sql". Decode escapes to bytes then UTF-8, so the gate sees
// the real path instead of mangled digits ("caf303251.sql").
function decodeCQuoted(inner) {
  const bytes = [];
  const simple = {
    a: 7,
    b: 8,
    f: 12,
    n: 10,
    r: 13,
    t: 9,
    v: 11,
    "\\": 92,
    '"': 34,
  };
  for (let i = 0; i < inner.length; i++) {
    if (inner[i] !== "\\" || i + 1 >= inner.length) {
      for (const b of Buffer.from(inner[i], "utf8")) bytes.push(b);
      continue;
    }
    const next = inner.slice(i + 1, i + 4);
    if (/^[0-7]{3}$/.test(next)) {
      bytes.push(parseInt(next, 8));
      i += 3;
      continue;
    }
    const esc = inner[i + 1];
    if (esc in simple) bytes.push(simple[esc]);
    else for (const b of Buffer.from(esc, "utf8")) bytes.push(b);
    i += 1;
  }
  return Buffer.from(bytes).toString("utf8");
}

function unquotePath(path) {
  // Each rename side is fully quoted, but strip quotes independently: a
  // half-fragment must never keep a stray `"` that defeats the (^|\/) anchors.
  const start = path.startsWith('"') ? 1 : 0;
  const end =
    path.length >= 2 && path.endsWith('"') ? path.length - 1 : path.length;
  if (start === 0 && end === path.length) return path;
  if (end <= start) return "";
  return decodeCQuoted(path.slice(start, end));
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
      // Only rename/copy statuses carry "old -> new". Splitting every line
      // breaks non-rename paths that contain " -> " (e.g. ?? "a -> b.proto").
      const isRename = line[0] === "R" || line[0] === "C";
      const arrow = isRename ? rest.lastIndexOf(" -> ") : -1;
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

function alreadyNudgedInLines(lines) {
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

function lastAssistantFromLines(lines) {
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

// The transcript grows without bound and this hook runs on every Stop:
// read it at most once per process, reusing the result for the fallback
// text and the already-nudged check. Laziness preserves short-circuiting:
// a primary last_assistant_message with no signal never touches the file.
let cachedTranscript = null;
function transcript(input) {
  if (!cachedTranscript) cachedTranscript = readTranscript(input.transcript_path);
  return cachedTranscript;
}

function lastAssistantText(input) {
  const primary =
    typeof input.last_assistant_message === "string"
      ? input.last_assistant_message
      : "";
  return primary || lastAssistantFromLines(transcript(input).lines);
}

function alreadyNudgedThisSession(input) {
  const { lines, readable } = transcript(input);
  if (!readable) return true;
  return alreadyNudgedInLines(lines);
}

const input = readHookInput();
const cwd = input.cwd || process.cwd();

if (
  input.stop_hook_active !== true &&
  hasDecisionSignal(lastAssistantText(input)) &&
  hasStructuralChange(cwd) &&
  !alreadyNudgedThisSession(input)
) {
  // no listener makes a closed pipe an unhandled 'error': stack trace on stderr, exit 1
  process.stdout.on("error", () => process.exit(0));
  process.stdout.write(
    `${JSON.stringify({ decision: "block", reason: MODEL_INSTRUCTION, systemMessage: HUMAN_NOTE })}\n`,
  );
}
