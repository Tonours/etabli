import { existsSync, realpathSync } from "node:fs";
import { homedir } from "node:os";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const SAFE_QUERY_PATTERN = /^[a-z0-9 _-]{4,240}$/;
const SAFE_TOPIC_PATTERN = /^[a-z0-9 _-]{4,80}$/;

/**
 * @typedef {object} DynamicKnowledgeContext
 * @property {string[]} topics
 * @property {string} query
 * @property {string} reason
 * @property {string} command
 * @property {"obvault-metadata"} source
 * @property {string[]} matchedNotes
 */

function defaultRoots() {
  return [
    process.env.OBVAULT_ROOT,
    resolve(homedir(), "work/obvault"),
    fileURLToPath(new URL("../../../obvault", import.meta.url)),
  ].filter(Boolean);
}

export function resolveObvaultRoot(roots = defaultRoots()) {
  for (const candidate of roots) {
    const root = resolve(candidate);
    if (!existsSync(resolve(root, "AGENTS.md"))) continue;
    if (!existsSync(resolve(root, "_meta/obvault"))) continue;
    try {
      return realpathSync(root);
    } catch {
      // A disappearing or unreadable vault is a routing miss, not a workflow failure.
    }
  }
  return null;
}

/**
 * @param {unknown} prompt
 * @param {{ roots?: string[], timeoutMs?: number }} [options]
 * @returns {DynamicKnowledgeContext | null}
 */
export function resolveDynamicKnowledgeContext(prompt, { roots, timeoutMs = 1200 } = {}) {
  const trimmed = String(prompt || "").trim();
  if (!trimmed || trimmed.startsWith("/")) return null;

  const root = resolveObvaultRoot(roots);
  if (!root) return null;
  try {
    const result = spawnSync(resolve(root, "_meta/obvault"), ["route", "--json", trimmed], {
      encoding: "utf8",
      env: { ...process.env, OBVAULT_ROOT: root },
      maxBuffer: 1024 * 1024,
      shell: false,
      timeout: timeoutMs,
    });
    if (result.status !== 0 || result.error || !result.stdout) return null;
    const routed = JSON.parse(result.stdout);
    if (routed.abstained || !SAFE_QUERY_PATTERN.test(routed.query || "")) return null;
    const topics = Array.isArray(routed.topics)
      ? routed.topics.filter((topic) => SAFE_TOPIC_PATTERN.test(topic)).slice(0, 6)
      : [];
    if (!topics.length) return null;
    const matchedNotes = Array.isArray(routed.matched_notes)
      ? routed.matched_notes
          .map((note) => String(note?.path || ""))
          .filter((note) => /^(kb|ref)\/[a-z0-9][a-z0-9/_-]*\.md$/.test(note))
          .slice(0, 3)
      : [];
    return {
      topics,
      query: routed.query,
      reason: `matched live obvault metadata: ${topics.join(", ")}`,
      command: `~/work/obvault/_meta/obvault context --json --max-tokens 2500 "${routed.query}"`,
      source: "obvault-metadata",
      matchedNotes,
    };
  } catch {
    return null;
  }
}
