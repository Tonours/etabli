import { readFileSync } from "node:fs";
import { join } from "node:path";

const stableOf = (value) => {
  if (Array.isArray(value)) return `[${value.map(stableOf).join(",")}]`;
  if (typeof value === "object" && value !== null) {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${stableOf(value[key])}`).join(",")}}`;
  }
  return JSON.stringify(value) ?? "null";
};

export const identityOf = (event, matcher, hook) =>
  [event, matcher ?? "", stableOf(hook)].join("\u0000");

export function parseFragment(text) {
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch (error) {
    throw new Error(`invalid fragment JSON: ${error.message}`);
  }
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
    throw new Error("fragment root is not an object");
  }
  if (parsed.hooks !== undefined && (typeof parsed.hooks !== "object" || parsed.hooks === null || Array.isArray(parsed.hooks))) {
    throw new Error("fragment hooks key is not an object");
  }
  const hooks = parsed.hooks ?? {};
  if (typeof hooks !== "object" || hooks === null || Array.isArray(hooks)) {
    throw new Error("fragment hooks key is not an object");
  }
  for (const [event, groups] of Object.entries(hooks)) {
    if (!Array.isArray(groups)) throw new Error(`fragment event ${event} is not an array`);
    for (const group of groups) {
      if (typeof group !== "object" || group === null || !Array.isArray(group.hooks)) {
        throw new Error(`fragment event ${event} has a malformed group`);
      }
      for (const hook of group.hooks) {
        if (typeof hook !== "object" || hook === null || typeof hook.command !== "string") {
          throw new Error(`fragment event ${event} has a malformed hook`);
        }
      }
    }
  }
  let count = 0;
  for (const groups of Object.values(hooks)) for (const group of groups) count += group.hooks.length;
  if (!count) throw new Error("fragment contains no hooks");
  return parsed;
}

export function loadFragment(repoDir) {
  return parseFragment(readFileSync(join(repoDir, "claude/settings.workflow-hooks.json"), "utf8"));
}

export function hookScriptNames(fragment) {
  const names = new Set();
  for (const groups of Object.values(fragment.hooks ?? {})) {
    for (const group of groups) {
      for (const hook of group.hooks ?? []) {
        const match = /hooks\/([^"/]+)"?$/.exec(hook.command ?? "");
        if (match) names.add(match[1]);
      }
    }
  }
  return [...names];
}

export const RETIRED_HOOK_COMMANDS = Object.freeze([
  ...["outcome-metric-emit.mjs", "proof-shadow.mjs"].map(
    (name) => `node "\${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/${name}"`,
  ),
  "rtk hook claude",
]);

const OPERATORS = new Set([";", "&", "|", "(", ")", "<", ">", "\n", "`"]);

function shellWords(command) {
  const words = [];
  let word = null;
  let quote = null;
  const flush = () => {
    if (word !== null) words.push({ text: word.text, quoted: word.quoted });
    word = null;
  };
  for (let index = 0; index < command.length; index += 1) {
    const char = command[index];
    if (quote === "'") {
      if (char === "'") quote = null;
      else word.text += char;
      continue;
    }
    if (quote === '"') {
      if (char === '"') quote = null;
      else if (char === "\\" && index + 1 < command.length) {
        index += 1;
        word.text += command[index];
      } else word.text += char;
      continue;
    }
    if (char === "\\" && index + 1 < command.length) {
      index += 1;
      if (command[index] === "\n") continue;
      word ??= { text: "", quoted: false };
      word.text += command[index];
      continue;
    }
    if (char === "'" || char === '"') {
      word ??= { text: "", quoted: false };
      word.quoted = true;
      quote = char;
      continue;
    }
    if (char === "$" && command[index + 1] === "(") {
      flush();
      words.push({ operator: "$(" });
      index += 1;
      continue;
    }
    if (OPERATORS.has(char) || char === "\r") {
      flush();
      words.push({ operator: char });
      continue;
    }
    if (/\s/.test(char)) {
      flush();
      continue;
    }
    word ??= { text: "", quoted: false };
    word.text += char;
  }
  flush();
  return words;
}

const SIMPLE_RTK_CLAUDE_HOOK = /^[ \t]*(?:[A-Za-z0-9_.\/-]*\/)?rtk(?:[ \t]+-[A-Za-z0-9_-]+)*[ \t]+hook[ \t]+claude(?:[ \t]+-[A-Za-z0-9_-]+)*[ \t]*$/;

function isSimpleRtkClaudeHook(command) {
  return SIMPLE_RTK_CLAUDE_HOOK.test(command);
}

export function isRetiredHookCommand(command) {
  return typeof command === "string" && (RETIRED_HOOK_COMMANDS.includes(command) || isSimpleRtkClaudeHook(command));
}

const RTK_WORD = /(?:^|[^A-Za-z0-9_-])rtk(?:[^A-Za-z0-9_-]|$)/i;

function mayMatchBash(matcher) {
  if (matcher === undefined || matcher === "" || matcher === "*") return true;
  try {
    return new RegExp(matcher).test("Bash");
  } catch {
    return true;
  }
}

export function bypassesRtkGuard(event, matcher, command) {
  return (
    event === "PreToolUse" &&
    mayMatchBash(matcher) &&
    typeof command === "string" &&
    !isRetiredHookCommand(command) &&
    [command, command.replace(/\\\r?\n/g, ""), ...shellWords(command).map((entry) => entry.text ?? "")]
      .flatMap((text) => [text, text.replace(/['"\\]/g, "")])
      .some((text) => RTK_WORD.test(text))
  );
}
