#!/usr/bin/env node
/**
 * Derived graph neighborhood pack over a Markdown wiki vault.
 * Canonical truth remains files on disk; this only expands wikilinks.
 * Default hops=1; max hops=2. Untrusted retrieval semantics for callers.
 */
import { readdirSync, readFileSync, statSync, existsSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
export const ROOT_DIR = resolve(__dirname, "../..");

const WIKILINK_RE = /\[\[([^\]|#]+)(?:[|#][^\]]*)?\]\]/g;
const MAX_HOPS = 2;
const DEFAULT_HOPS = 1;
const DEFAULT_MAX_TOKENS = 800;

export function estimateTokens(text) {
  return Math.ceil(Buffer.byteLength(String(text), "utf8") / 4);
}

export function parseFrontmatter(text) {
  if (!text.startsWith("---\n")) return { meta: {}, body: text };
  const end = text.indexOf("\n---\n", 4);
  if (end < 0) return { meta: {}, body: text };
  const raw = text.slice(4, end);
  const meta = {};
  for (const line of raw.split("\n")) {
    const m = line.match(/^([A-Za-z0-9_]+):\s*(.*)$/);
    if (!m) continue;
    meta[m[1]] = m[2].replace(/^["']|["']$/g, "").trim();
  }
  return { meta, body: text.slice(end + 5) };
}

export function extractWikilinks(text) {
  const names = new Set();
  let match;
  const re = new RegExp(WIKILINK_RE.source, "g");
  while ((match = re.exec(text)) !== null) {
    names.add(match[1].trim().toLowerCase());
  }
  return [...names];
}

export function loadWikiNotes(vaultRoot) {
  const notes = new Map();
  const dirs = ["kb", "ref"];
  for (const dir of dirs) {
    const abs = join(vaultRoot, dir);
    if (!existsSync(abs)) continue;
    for (const name of readdirSync(abs)) {
      if (!name.endsWith(".md")) continue;
      const path = join(abs, name);
      if (!statSync(path).isFile()) continue;
      const rel = relative(vaultRoot, path).replaceAll("\\", "/");
      const text = readFileSync(path, "utf8");
      const { meta, body } = parseFrontmatter(text);
      const basename = name.replace(/\.md$/, "");
      const key = basename.toLowerCase();
      const note = {
        path: rel,
        basename,
        key,
        status: meta.status || "unknown",
        summary: meta.summary || "",
        text,
        body,
        links: extractWikilinks(text),
      };
      notes.set(key, note);
      notes.set(rel.toLowerCase(), note);
    }
  }
  return notes;
}

export function resolveNote(notes, name) {
  const key = String(name).toLowerCase().replace(/\.md$/, "");
  return notes.get(key) || notes.get(`kb/${key}`) || notes.get(`ref/${key}`) || null;
}

/**
 * Lexical seed: match query terms against path, basename, summary, body.
 */
export function seedNotes(notes, query, limit = 3) {
  const q = String(query).toLowerCase();
  const terms = q
    .split(/[^a-z0-9äöüéèêàùç_-]+/i)
    .filter((t) => t.length > 2);
  const seen = new Set();
  const ranked = [];
  for (const note of notes.values()) {
    if (seen.has(note.path)) continue;
    seen.add(note.path);
    const base = note.basename.toLowerCase();
    const hay = `${note.path} ${base} ${note.summary} ${note.body}`.toLowerCase();
    let score = 0;
    // Prefer basename / title hits so multi-hop packs start from one clear seed
    if (q.includes(base) || base.split("-").every((p) => !p || q.includes(p))) {
      score += 10;
    }
    for (const t of terms) {
      if (base.includes(t)) score += 4;
      else if (hay.includes(t)) score += 1;
    }
    if (score > 0) ranked.push({ note, score });
  }
  ranked.sort((a, b) => b.score - a.score || a.note.path.localeCompare(b.note.path));
  return ranked.slice(0, limit).map((r) => r.note);
}

export function expandNeighborhood(notes, seeds, hops = DEFAULT_HOPS) {
  const hopLimit = Math.min(Math.max(Number(hops) || DEFAULT_HOPS, 0), MAX_HOPS);
  const selected = new Map();
  const edges = [];

  for (const seed of seeds) {
    selected.set(seed.path, { note: seed, hop: 0, reason: "seed" });
  }

  let frontier = seeds.map((s) => ({ note: s, hop: 0 }));
  while (frontier.length > 0) {
    const next = [];
    for (const { note, hop } of frontier) {
      if (hop >= hopLimit) continue;
      for (const link of note.links) {
        const target = resolveNote(notes, link);
        if (!target) continue;
        edges.push({ from: note.path, to: target.path, hop: hop + 1 });
        if (!selected.has(target.path)) {
          selected.set(target.path, {
            note: target,
            hop: hop + 1,
            reason: `graph:${note.path}`,
          });
          next.push({ note: target, hop: hop + 1 });
        }
      }
    }
    frontier = next;
  }

  return { selected, edges, hops: hopLimit };
}

export function buildNeighborhoodPack(options = {}) {
  const vaultRoot = resolve(options.vaultRoot || process.cwd());
  const query = options.query || "";
  const hops = options.hops ?? DEFAULT_HOPS;
  const maxTokens = options.maxTokens ?? DEFAULT_MAX_TOKENS;
  const notes = loadWikiNotes(vaultRoot);
  const seeds = seedNotes(notes, query, options.seedLimit ?? 1);
  const { selected, edges, hops: hopLimit } = expandNeighborhood(notes, seeds, hops);

  const ordered = [...selected.values()].sort(
    (a, b) => a.hop - b.hop || a.note.path.localeCompare(b.note.path),
  );

  const paths = [];
  const excerpts = [];
  let tokens = 0;
  const trust = "untrusted-retrieved-content";

  for (const item of ordered) {
    const n = item.note;
    const snippet = (n.summary || n.body.split("\n").find((l) => l.trim()) || "").slice(0, 240);
    const block = `## ${n.path} [hop=${item.hop} status=${n.status}]\n${snippet}\n`;
    const cost = estimateTokens(block);
    if (tokens + cost > maxTokens && paths.length > 0) break;
    tokens += cost;
    paths.push(n.path);
    excerpts.push({
      path: n.path,
      hop: item.hop,
      status: n.status,
      reason: item.reason,
      status_stale: n.status === "stale" || n.status === "superseded",
    });
  }

  const stale_paths = excerpts.filter((e) => e.status_stale).map((e) => e.path);
  const neighbor_paths = excerpts.filter((e) => e.hop >= 1).map((e) => e.path);

  return {
    vault_root: vaultRoot,
    query,
    hops: hopLimit,
    max_hops: MAX_HOPS,
    max_tokens: maxTokens,
    estimated_tokens: tokens,
    trust,
    content_policy: "untrusted-jit-derived-graph",
    canonical: "markdown-files",
    seeds: seeds.map((s) => s.path),
    paths,
    neighbors: neighbor_paths,
    edges: edges.filter((e) => paths.includes(e.from) || paths.includes(e.to)),
    excerpts,
    stale_paths,
    seed_count: seeds.length,
    selected_count: paths.length,
  };
}

function main(argv) {
  const args = argv.slice(2);
  let vaultRoot = null;
  let query = "";
  let hops = DEFAULT_HOPS;
  let maxTokens = DEFAULT_MAX_TOKENS;
  let seedLimit = 1;
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === "--vault") vaultRoot = args[++i];
    else if (a === "--hops") hops = Number(args[++i]);
    else if (a === "--max-tokens") maxTokens = Number(args[++i]);
    else if (a === "--seed-limit") seedLimit = Number(args[++i]);
    else if (a === "-h" || a === "--help") {
      console.log(
        "Usage: graph-neighborhood --vault <path> [--hops 1|2] [--seed-limit N] [--max-tokens N] <query>",
      );
      process.exit(0);
    } else {
      query = query ? `${query} ${a}` : a;
    }
  }
  if (!vaultRoot || !query) {
    console.error("graph-neighborhood: --vault and query required");
    process.exit(2);
  }
  const pack = buildNeighborhoodPack({ vaultRoot, query, hops, maxTokens, seedLimit });
  console.log(JSON.stringify(pack, null, 2));
}

const isMain =
  process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  main(process.argv);
}
