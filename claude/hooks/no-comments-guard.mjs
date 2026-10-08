#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { recordGuardDenial } from "../../workflow/runtime/guard-journal.mjs";

const CODE_EXT =
  /\.(m?[jt]sx?|c[jt]s|go|rs|java|kt|swift|c|h|cc|cpp|hpp|cs|php|rb|py|sh|bash|zsh|scss|sass|less|vue|svelte|astro)$/i;

const ALLOW =
  /(eslint-disable|eslint-enable|@ts-expect-error|@ts-ignore|@ts-nocheck|biome-ignore|prettier-ignore|stylelint-disable|c8 ignore|istanbul ignore|v8 ignore|@jsxImportSource|#!\/)/;

const HASH_LANG = /\.(py|sh|bash|zsh|rb)$/i;

function editPairs(input, toolName, cwd) {
  if (toolName === "Write") {
    let previous = "";
    try {
      previous = readFileSync(resolve(cwd, String(input.file_path ?? "")), "utf8");
    } catch {
      previous = "";
    }
    return [{ before: previous, after: String(input.content ?? "") }];
  }
  if (toolName === "MultiEdit")
    return (input.edits ?? []).map((e) => ({
      before: String(e.old_string ?? ""),
      after: String(e.new_string ?? ""),
    }));
  return [{ before: String(input.old_string ?? ""), after: String(input.new_string ?? "") }];
}

const REGEX_LITERAL_PREFIX = /[=(,:[!&|?{;+]\s*$/;

function stripRegexLiterals(line) {
  let out = "";
  let index = 0;

  while (index < line.length) {
    const opensComment = line[index + 1] === "/" || line[index + 1] === "*";
    if (
      line[index] !== "/" ||
      opensComment ||
      !REGEX_LITERAL_PREFIX.test(out)
    ) {
      out += line[index];
      index += 1;
      continue;
    }

    let cursor = index + 1;
    let inClass = false;
    let closed = false;

    while (cursor < line.length) {
      const char = line[cursor];
      if (char === "\\") {
        cursor += 2;
        continue;
      }
      if (char === "[") inClass = true;
      else if (char === "]") inClass = false;
      else if (char === "/" && !inClass) {
        closed = true;
        break;
      }
      cursor += 1;
    }

    if (!closed) {
      out += line.slice(index);
      break;
    }

    out += "RE";
    index = cursor + 1;
    while (index < line.length && /[dgimsuvy]/.test(line[index])) index += 1;
  }

  return out;
}

function stripStrings(line) {
  return stripRegexLiterals(line)
    .replace(/"(?:[^"\\]|\\.)*"/g, "")
    .replace(/'(?:[^'\\]|\\.)*'/g, "")
    .replace(/`(?:[^`\\]|\\.)*`/g, "");
}

function findComments(lines, filePath) {
  const allowHash = HASH_LANG.test(filePath);
  const found = [];
  for (const raw of lines) {
    const line = raw.trimEnd();
    if (!line.trim()) continue;
    if (ALLOW.test(line)) continue;
    const code = stripStrings(line);
    if (/(^|[^:])\/\//.test(code) ||
      /\/\*/.test(code) ||
      /^\s*\*(\s|$|\/)/.test(raw) ||
      (allowHash && /(^|\s)#(?!!)/.test(code) && !/^\s*#!/.test(raw))
    )
      found.push(line.trim());
  }
  return found;
}

function addedComment(pairs, filePath) {
  for (const { before, after } of pairs) {
    const existing = new Map();
    for (const line of findComments(before.split("\n"), filePath))
      existing.set(line, (existing.get(line) ?? 0) + 1);
    for (const line of findComments(after.split("\n"), filePath)) {
      const count = existing.get(line) ?? 0;
      if (count === 0) return line;
      existing.set(line, count - 1);
    }
  }
  return null;
}

function main() {
  let payload;
  try {
    payload = JSON.parse(readFileSync(0, "utf8"));
  } catch {
    process.exit(0);
  }
  const tool = payload.tool_name;
  const input = payload.tool_input ?? {};
  const filePath = input.file_path ?? "";
  if (!CODE_EXT.test(filePath)) process.exit(0);

  const hit = addedComment(editPairs(input, tool, payload.cwd ?? process.cwd()), filePath);
  if (!hit) process.exit(0);

  recordGuardDenial({
    cwd: payload.cwd,
    harness: "claude",
    guard: "no-comments",
    pattern: "code-comment-added",
    target: filePath,
    tool,
  });

  const out = {
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: `no-comments: ${filePath} adds a code comment: "${hit}". Remove it and encode the rationale in names or the commit message.`,
    },
  };
  process.stdout.write(JSON.stringify(out));
  process.exit(0);
}

main();
