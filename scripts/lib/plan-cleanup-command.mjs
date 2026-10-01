import { realpathSync } from "node:fs";
import { isAbsolute, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const CENTRAL_CLEANUP = fileURLToPath(new URL("../plan-cleanup", import.meta.url));

function tokens(command) {
  if (!command || /[;$`\\\n\r|<>]/.test(command)) return null;
  const pattern = /[ \t]*(?:'([^']*)'|"([^"]*)"|([^ \t'"]+))(?=[ \t]|$)/gy;
  const values = [];
  let end = 0;
  let match;
  while ((match = pattern.exec(command))) {
    const value = match[1] ?? match[2] ?? match[3];
    if (match[3] && value !== "&&" && /[~*?\[\]{}()!&]/.test(value)) return null;
    if (!match[3] && value === "&&") return null;
    values.push(value);
    end = pattern.lastIndex;
  }
  return end === command.length ? values : null;
}

export function isNarrowPlanCleanupCommand(command, cwd = process.cwd()) {
  const words = tokens(String(command || "").replace(/^[ \t]+|[ \t]+$/g, ""));
  if (!words) return false;
  if (words[0] === "cd") {
    words.shift();
    if (words[0] === "--") words.shift();
    const directory = words.shift();
    if (!directory || words.shift() !== "&&" ||
        !(isAbsolute(directory) || directory === "." || directory.startsWith("./")) ||
        directory.split("/").includes("..")) return false;
    try {
      if (realpathSync(resolve(cwd, directory)) !== realpathSync(cwd)) return false;
    } catch {
      return false;
    }
  }
  if (words.includes("&&")) return false;
  if (["node", "bun", "bash"].includes(words[0])) words.shift();
  if (words.length !== 3) return false;
  const [executable, mode, argument] = words;
  if (!executable.includes("/") || executable.split("/").includes("..")) return false;
  const binary = resolve(cwd, executable);
  if (binary !== resolve(cwd, "scripts/plan-cleanup") && binary !== CENTRAL_CLEANUP) return false;
  if (mode === "--discard") return /^[a-z0-9][a-z0-9_-]{0,80}$/.test(argument);
  return mode === "--archive" && /^(?:\.\/)?docs\/plan\/[A-Za-z0-9][A-Za-z0-9._-]*\.md$/.test(argument);
}
