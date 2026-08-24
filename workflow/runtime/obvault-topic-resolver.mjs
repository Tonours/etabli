import { createHash } from "node:crypto";
import {
  chmodSync,
  existsSync,
  readFileSync,
  readdirSync,
  realpathSync,
  renameSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { homedir, tmpdir } from "node:os";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const SAFE_QUERY_PATTERN = /^[a-z0-9 _-]{4,240}$/;
const SAFE_TOPIC_PATTERN = /^[a-z0-9 _-]{4,80}$/;

// Route-result caching. The `_meta/obvault route` spawn costs ~100ms+ per
// call and `before_agent_start` pays it every turn, so identical prompts are
// served from an LRU cache (memory + a per-user disk mirror for fresh
// processes). Correctness is guarded by a vault fingerprint: any note
// addition/removal/edit under kb/, ref/ or docs/ changes the fingerprint and
// invalidates cached routes immediately (no index rebuild, no TTL grace).
const ROUTE_CACHE_TTL_MS = 10_000;
const ROUTE_CACHE_MAX_ENTRIES = 128;
const FINGERPRINT_MAX_FILES = 600;
const FINGERPRINT_MAX_DEPTH = 8;
const ABSTAIN = 0; // cached "router abstained" marker (distinct from no entry)

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
  // An explicit OBVAULT_ROOT is exclusive: a machine that points somewhere else
  // (or nowhere) must not silently fall back to a vault it opted out of.
  if (process.env.OBVAULT_ROOT) return [process.env.OBVAULT_ROOT];
  // Scope-aware resolution (decision 2026-08-23, ratifying ADR-0017's
  // direction without breaking machines where `brain` does not exist yet):
  //   work scope     -> brain first, obvault as documented fallback
  //   personal scope -> obvault only
  // `~/.etabli-scope` selects the scope; absence means the shared default
  // (obvault), which is the live reality on machines without brain.
  const roots = [];
  let scope = "personal";
  try {
    scope =
      readFileSync(resolve(homedir(), ".etabli-scope"), "utf8").trim() ||
      "personal";
  } catch {
    // no scope file: personal default
  }
  if (scope === "work") {
    roots.push(resolve(homedir(), "work/brain"));
  }
  roots.push(resolve(homedir(), "work/obvault"));
  roots.push(fileURLToPath(new URL("../../../obvault", import.meta.url)));
  return roots;
}

// Memoized for 10s: root discovery stats several paths per call and the set
// of installed vaults changes rarely. Keyed by the exact roots list so an
// exclusive OBVAULT_ROOT override never sees a memoized fallback answer.
const ROOT_MEMO_TTL_MS = 10_000;
let rootMemo = null;

export function resolveObvaultRoot(roots = defaultRoots()) {
  const key = JSON.stringify(roots);
  const now = Date.now();
  if (rootMemo && rootMemo.key === key && rootMemo.expires > now) {
    return rootMemo.root;
  }
  let resolved = null;
  for (const candidate of roots) {
    const root = resolve(candidate);
    if (!existsSync(resolve(root, "AGENTS.md"))) continue;
    if (!existsSync(resolve(root, "_meta/obvault"))) continue;
    try {
      resolved = realpathSync(root);
      break;
    } catch {
      // A disappearing or unreadable vault is a routing miss, not a workflow failure.
    }
  }
  rootMemo = { key, root: resolved, expires: now + ROOT_MEMO_TTL_MS };
  return resolved;
}

function cacheEnabled() {
  return process.env.ETABLI_OBVAULT_ROUTE_CACHE !== "0";
}

function cacheFile() {
  const uid = typeof process.getuid === "function" ? process.getuid() : 0;
  return resolve(tmpdir(), `etabli-obvault-route-${uid}.json`);
}

/**
 * Deterministic fingerprint of the vault content the router reads.
 * `_meta/obvault route` builds its catalog from kb/ and ref/ markdown
 * (buildManifest(root, includeDocs=false)); any note add/remove/edit there
 * changes this fingerprint. docs/ is deliberately excluded: it never feeds
 * routing and can hold thousands of transcript files.
 * Returns null when the tree is too large to fingerprint cheaply: caching
 * is then disabled (fail-safe, routing stays live).
 */
function vaultFingerprint(root) {
  const parts = [];
  let files = 0;
  const walk = (dir, rel, depth) => {
    let entries;
    try {
      entries = readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }
    entries.sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
    for (const entry of entries) {
      const childRel = rel ? `${rel}/${entry.name}` : entry.name;
      if (entry.isDirectory()) {
        if (depth >= FINGERPRINT_MAX_DEPTH) continue;
        walk(resolve(dir, entry.name), childRel, depth + 1);
      } else if (entry.isFile()) {
        if (++files > FINGERPRINT_MAX_FILES) throw new Error("overflow");
        const stat = statSync(resolve(dir, entry.name), {
          throwIfNoEntry: false,
        });
        if (stat) parts.push(`${childRel}:${stat.mtimeMs}:${stat.size}`);
      }
    }
  };
  try {
    for (const dir of ["kb", "ref"]) {
      walk(resolve(root, dir), dir, 0);
    }
  } catch {
    return null;
  }
  return createHash("sha256").update(parts.join("\n")).digest("hex");
}

// --- two-tier route cache -------------------------------------------------
const memoryCache = new Map(); // key -> { f, x, v } (insertion order = LRU)
let diskCache = null; // null until first load
const stats = { memoryHits: 0, diskHits: 0, misses: 0, spawns: 0 };

export function resolverCacheStats() {
  return { ...stats, memorySize: memoryCache.size };
}

function routeCacheKey(root, prompt) {
  // Only a hash of the prompt is persisted: raw prompt text must never be
  // copied outside the turn (obvault-memory contract).
  return createHash("sha256")
    .update(`${root}\n${prompt}`)
    .digest("hex");
}

function loadDiskCache() {
  if (diskCache) return diskCache;
  diskCache = new Map();
  try {
    const parsed = JSON.parse(readFileSync(cacheFile(), "utf8"));
    if (parsed && typeof parsed === "object" && Array.isArray(parsed.e)) {
      const now = Date.now();
      for (const entry of parsed.e) {
        if (
          entry &&
          typeof entry.k === "string" &&
          typeof entry.f === "string" &&
          typeof entry.x === "number" &&
          entry.x > now
        ) {
          diskCache.set(entry.k, { f: entry.f, x: entry.x, v: entry.v });
        }
      }
    }
  } catch {
    // Missing/corrupt cache file: start empty (fail open).
  }
  return diskCache;
}

function persistMemoryCache() {
  const payload = JSON.stringify({
    v: 1,
    e: [...memoryCache.entries()].map(([k, { f, x, v }]) => ({
      k,
      f,
      x,
      v: v === ABSTAIN ? 0 : v,
    })),
  });
  const target = cacheFile();
  const staging = `${target}.${process.pid}.tmp`;
  try {
    writeFileSync(staging, payload, { mode: 0o600 });
    chmodSync(staging, 0o600);
    renameSync(staging, target);
  } catch {
    // A read-only tmpdir or a concurrent writer must never break routing.
  }
}

function cacheGet(key, fingerprint, now) {
  const memoryHit = memoryCache.get(key);
  if (memoryHit) {
    // Refresh LRU recency.
    memoryCache.delete(key);
    memoryCache.set(key, memoryHit);
    if (memoryHit.x > now && memoryHit.f === fingerprint) {
      stats.memoryHits++;
      return memoryHit.v;
    }
    memoryCache.delete(key);
  }
  const disk = loadDiskCache();
  const diskHit = disk.get(key);
  if (diskHit && diskHit.x > now && diskHit.f === fingerprint) {
    stats.diskHits++;
    memoryCache.set(key, diskHit);
    return diskHit.v;
  }
  stats.misses++;
  return undefined;
}

function cachePut(key, fingerprint, expiresAt, value) {
  memoryCache.set(key, { f: fingerprint, x: expiresAt, v: value });
  while (memoryCache.size > ROUTE_CACHE_MAX_ENTRIES) {
    memoryCache.delete(memoryCache.keys().next().value);
  }
  persistMemoryCache();
}

/**
 * @param {unknown} prompt
 * @param {{ roots?: string[], timeoutMs?: number }} [options]
 * @returns {DynamicKnowledgeContext | null}
 */
export function resolveDynamicKnowledgeContext(
  prompt,
  { roots, timeoutMs = 1200 } = {},
) {
  const trimmed = String(prompt || "").trim();
  if (!trimmed || trimmed.startsWith("/")) return null;

  const root = resolveObvaultRoot(roots);
  if (!root) return null;

  const useCache = cacheEnabled();
  const fingerprint = useCache ? vaultFingerprint(root) : null;
  const now = Date.now();
  if (fingerprint) {
    const cached = cacheGet(routeCacheKey(root, trimmed), fingerprint, now);
    if (cached !== undefined) {
      // Cached abstentions are the router's own "no match" answer.
      return cached === ABSTAIN ? null : structuredClone(cached);
    }
  }

  try {
    stats.spawns++;
    const result = spawnSync(
      resolve(root, "_meta/obvault"),
      ["route", "--json", trimmed],
      {
        encoding: "utf8",
        env: { ...process.env, OBVAULT_ROOT: root },
        maxBuffer: 1024 * 1024,
        shell: false,
        timeout: timeoutMs,
      },
    );
    if (result.status !== 0 || result.error || !result.stdout) return null;
    const routed = JSON.parse(result.stdout);
    const key = fingerprint ? routeCacheKey(root, trimmed) : null;
    if (routed.abstained) {
      // The router's own "no match" answer is deterministic for a given
      // (vault fingerprint, prompt): cache it like a positive match.
      if (fingerprint) {
        cachePut(key, fingerprint, now + ROUTE_CACHE_TTL_MS, ABSTAIN);
      }
      return null;
    }
    if (!SAFE_QUERY_PATTERN.test(routed.query || "")) return null;
    const topics = Array.isArray(routed.topics)
      ? routed.topics
          .filter((topic) => SAFE_TOPIC_PATTERN.test(topic))
          .slice(0, 6)
      : [];
    if (!topics.length) {
      if (fingerprint) {
        cachePut(key, fingerprint, now + ROUTE_CACHE_TTL_MS, ABSTAIN);
      }
      return null;
    }
    const matchedNotes = Array.isArray(routed.matched_notes)
      ? routed.matched_notes
          .map((note) => String(note?.path || ""))
          .filter((note) => /^(kb|ref)\/[a-z0-9][a-z0-9/_-]*\.md$/.test(note))
          .slice(0, 3)
      : [];
    const context = {
      topics,
      query: routed.query,
      reason: `matched live obvault metadata: ${topics.join(", ")}`,
      command: `${root}/_meta/obvault context --json --max-tokens 2500 "${routed.query}"`,
      source: "obvault-metadata",
      matchedNotes,
    };
    if (fingerprint) {
      cachePut(key, fingerprint, now + ROUTE_CACHE_TTL_MS, context);
    }
    return context;
  } catch {
    return null;
  }
}
