import { execFileSync } from "node:child_process";
import { readHookInput } from "./workflow-router-lib.mjs";
import { parseJsonLine, readJsonLines } from "./transcript-lib.mjs";
import {
  STRUCTURAL_PATTERNS,
  hasDecisionSignal,
} from "./adr-signal-policy.mjs";

const HOOK_FILENAME = "detect-adr-signal.mjs";

const HUMAN_NOTE =
  "Possible architecture decision detected. /adr was handed to the model, which decides whether it qualifies.";

const MODEL_INSTRUCTION = [
  "A structural file is uncommitted in this repo and your last message reads like a decision.",
  "Invoke the adr skill, cheapest work first: apply its three-condition gate",
  "(hard to reverse, surprising without context, a real tradeoff) using only what you already know from this turn.",
  "If any condition fails, say so in one line and stop — do not run git, do not read docs/adr.",
  "Only when all three hold, continue with the skill's grounding, draft and approval steps.",
].join(" ");

function porcelainPaths(cwd) {
  let out;
  try {
    out = execFileSync(
      "git",
      ["status", "--porcelain", "-z", "--untracked-files=all"],
      {
        cwd,
        encoding: "utf8",
        maxBuffer: 64 * 1024 * 1024,
        stdio: ["ignore", "pipe", "ignore"],
      },
    );
  } catch {
    return [];
  }
  // -z: NUL-separated records, never quoted, raw UTF-8. A rename/copy
  // status record ("R  <new>") is followed by a bare second record ("<old>").
  const fields = out.split("\0").filter((field) => field !== "");
  const paths = [];
  for (let i = 0; i < fields.length; i++) {
    const field = fields[i];
    paths.push(field.slice(3));
    if ((field[0] === "R" || field[0] === "C") && i + 1 < fields.length) {
      i += 1;
      paths.push(fields[i]);
    }
  }
  return paths;
}

function hasStructuralChange(cwd) {
  return porcelainPaths(cwd).some((p) =>
    STRUCTURAL_PATTERNS.some((re) => re.test(p)),
  );
}

function alreadyNudgedInLines(lines) {
  return lines.some((line) => {
    if (!line.includes("hook_blocking_error")) return false;
    const attachment = parseJsonLine(line)?.attachment;
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
    const entry = parseJsonLine(lines[i]);
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
  if (!cachedTranscript) cachedTranscript = readJsonLines(input.transcript_path);
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
