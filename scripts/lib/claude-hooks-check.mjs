import { existsSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { bypassesRtkGuard, hookScriptNames, identityOf, isRetiredHookCommand, loadFragment } from "./claude-hooks-fragment.mjs";

const claudeDir = process.argv[2];
const repoDir = process.argv[3];
const livePath = join(claudeDir, "settings.json");
const remedy = "remediation: run scripts/claude-hooks-merge --dry-run, review, then run it for real";

let fragment;
try {
  fragment = loadFragment(repoDir);
} catch (error) {
  console.error(`claude-hooks-check: ${error.message}; fix the repo fragment`);
  process.exit(1);
}

if (!existsSync(livePath)) {
  console.error(`claude-hooks-check: ${livePath} is absent; ${remedy}`);
  process.exit(1);
}
let live;
try {
  live = JSON.parse(readFileSync(livePath, "utf8"));
} catch {
  console.error(`claude-hooks-check: invalid JSON in ${livePath}; fix it by hand`);
  process.exit(1);
}
if (typeof live === "object" && live !== null && live.disableAllHooks === true) {
  console.error(`claude-hooks-check: ${livePath} sets disableAllHooks=true, no hook runs; remove it (a project-level false overrides) and re-run; ${remedy}`);
  process.exit(1);
}
const liveIdentities = new Set();
const retiredWired = [];
const guardBypass = [];
const hooksObj = typeof live === "object" && live !== null && typeof live.hooks === "object" && live.hooks !== null && !Array.isArray(live.hooks) ? live.hooks : {};
for (const [event, groups] of Object.entries(hooksObj)) {
  if (!Array.isArray(groups)) continue;
  for (const group of groups) {
    if (typeof group !== "object" || group === null || Array.isArray(group)) continue;
    const hooks = Array.isArray(group.hooks) ? group.hooks : [];
    for (const hook of hooks) {
      if (typeof hook !== "object" || hook === null || Array.isArray(hook)) continue;
      liveIdentities.add(identityOf(event, group.matcher, hook));
      if (isRetiredHookCommand(hook.command)) retiredWired.push(`${event}/${group.matcher ?? ""}: ${hook.command}`);
      if (bypassesRtkGuard(event, group.matcher, hook.command)) guardBypass.push(`${event}/${group.matcher ?? ""}: ${hook.command}`);
    }
  }
}

const missing = [];
for (const [event, groups] of Object.entries(fragment.hooks ?? {})) {
  for (const group of groups) {
    for (const hook of group.hooks ?? []) {
      if (!liveIdentities.has(identityOf(event, group.matcher, hook))) {
        missing.push(`${event}/${group.matcher ?? ""}: ${hook.command}`);
      }
    }
  }
}
if (missing.length || retiredWired.length || guardBypass.length) {
  for (const entry of missing) console.error(`claude-hooks-check: not wired: ${entry}`);
  for (const entry of retiredWired) console.error(`claude-hooks-check: retired hook still wired: ${entry}`);
  for (const entry of guardBypass) {
    console.error(`claude-hooks-check: custom Bash PreToolUse hook calls rtk outside rtk-guard: ${entry} (edit it by hand to drop the rtk call; rtk-guard already delegates to rtk hook claude)`);
  }
  console.error(remedy);
  process.exit(1);
}
const scriptNames = hookScriptNames(fragment);
if (!scriptNames.length) {
  console.error("claude-hooks-check: no hook scripts derived from the fragment; fix the repo fragment");
  process.exit(1);
}
const hooksDir = join(claudeDir, "hooks");
const isRunnableFile = (path) => {
  try {
    return statSync(path).isFile();
  } catch {
    return false;
  }
};
const scriptsMissing = scriptNames.filter((name) => !isRunnableFile(join(hooksDir, name)));
if (scriptsMissing.length) {
  for (const name of scriptsMissing) console.error(`claude-hooks-check: hook script missing: ${join(hooksDir, name)}`);
  console.error("restore the scripts (re-run scripts/deploy-agent-workflow --apply), then re-run this check");
  process.exit(1);
}
console.log("claude-hooks-check: ok, all fragment hooks wired");
