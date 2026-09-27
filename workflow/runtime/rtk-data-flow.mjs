const DISPLAY_CONSUMERS = new Map([
  ["head", /^-[qv]$/],
  ["tail", /^-[qvfF]$/],
  ["cat", /^-[A-Za-z]+$/],
]);
const COUNT_OPTION = /^-[nc]$/;
const COUNT_ATTACHED = /^-[nc]?\d+$/;
const MASK = "\u0000";
const STATE_COMMANDS = new Set(["export", "alias", "unalias", "function", "enable", "builtin", "hash", "set", "declare", "typeset", "local", "readonly", "source", "exec", "eval", "trap", "coproc", "command", "time", "nohup", "nice", "env", "sudo", "doas", "timeout", "stdbuf", "if", "then", "elif", "else", "fi", "for", "while", "until", "do", "done", "case", "esac", "select"]);
const PLAIN_COMMAND = /^(?:\/|\.\.?\/)?[A-Za-z0-9_][A-Za-z0-9_.+:@%-]*(?:\/[A-Za-z0-9_][A-Za-z0-9_.+:@%-]*)*$/;
const COMPOUND = /[;(){}\n]|\|\||\|&|(?<![>|])&(?!>)/;

function isSimpleCommand(scan, segments) {
  if (COMPOUND.test(scan)) return false;
  return segments.every((segment) => {
    const name = segment.trim().split(/\s+/)[0] ?? "";
    return PLAIN_COMMAND.test(name) && !STATE_COMMANDS.has(name.split("/").pop());
  });
}

function displayArgsAllowed(consumer, args) {
  const flag = DISPLAY_CONSUMERS.get(consumer);
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (consumer !== "cat" && COUNT_ATTACHED.test(arg)) continue;
    if (consumer !== "cat" && COUNT_OPTION.test(arg) && /^\d+$/.test(args[index + 1] ?? "")) {
      index += 1;
      continue;
    }
    if (!flag.test(arg)) return false;
  }
  return true;
}
const SAFE_REDIRECTS = new Set(["2>&1", "2>/dev/null", "2>>/dev/null", ">/dev/null", ">>/dev/null", "1>/dev/null", "&>/dev/null"]);
const TOKEN_BOUNDARY = /[\s;&|()]/;
const TARGET_END = /[\s;&|<>]/;
const PIPE_SPLIT = /(?<!\|)\|&?(?!\|)/;

function maskQuoted(command) {
  let out = "";
  let quote = null;
  for (let index = 0; index < command.length; index += 1) {
    const char = command[index];
    const next = command[index + 1];
    if (quote === "'") {
      if (char === "'") quote = null;
      out += MASK;
    } else if (quote === '"') {
      if (char === "`" || (char === "$" && (next === "(" || next === "{" || next === "["))) return null;
      if (char === '"') quote = null;
      else if (char === "\\") index += 1;
      out += MASK;
    } else if (char === "`" || (char === "$" && (next === "(" || next === "{" || next === "[" || next === "'" || next === '"')) || ((char === "<" || char === ">") && next === "(") || (char === "<" && next === "&")) {
      return null;
    } else if (char === "\\") {
      return null;
    } else if (char === "'" || char === '"') {
      quote = char;
      out += MASK;
    } else {
      out += char;
    }
  }
  return quote === null ? out : null;
}

function redirections(scan) {
  const found = [];
  for (let index = 0; index < scan.length; index += 1) {
    if (scan[index] !== ">") continue;
    let start = index;
    while (start > 0 && /[0-9]/.test(scan[start - 1])) start -= 1;
    if (start > 0 && scan[start - 1] === "&" && start === index) start -= 1;
    const atBoundary = start === 0 || TOKEN_BOUNDARY.test(scan[start - 1]);
    const prefix = atBoundary ? scan.slice(start, index) : "";
    let cursor = index + 1;
    if (scan[cursor] === ">") cursor += 1;
    const operator = scan.slice(index, cursor);
    let dup = "";
    if (scan[cursor] === "&") {
      dup = "&";
      cursor += 1;
    }
    while (cursor < scan.length && /\s/.test(scan[cursor])) cursor += 1;
    let end = cursor;
    while (end < scan.length && !TARGET_END.test(scan[end])) end += 1;
    found.push(`${prefix}${operator}${dup}${scan.slice(cursor, end)}`);
    index = Math.max(index, cursor - 1);
  }
  return found;
}

export function rtkDataFlowReason(command) {
  if (typeof command !== "string" || command.trim() === "") return null;
  if (/[\r\n]/.test(command)) return "unsupported-syntax";
  const scan = maskQuoted(command);
  if (scan === null || /[^\S \t\n]/.test(scan)) return "unsupported-syntax";
  const segments = scan.split(PIPE_SPLIT);
  if (!isSimpleCommand(scan, segments)) return "unsupported-syntax";
  if (scan.includes("<") || redirections(scan).some((redirect) => !SAFE_REDIRECTS.has(redirect))) return "redirect";
  for (const segment of segments.slice(1)) {
    const [consumer = "", ...args] = segment.trim().split(/\s+/);
    if (!DISPLAY_CONSUMERS.has(consumer)) return "pipe";
    if (!displayArgsAllowed(consumer, args)) return "pipe";
  }
  return null;
}
