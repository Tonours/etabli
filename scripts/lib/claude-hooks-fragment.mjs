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
