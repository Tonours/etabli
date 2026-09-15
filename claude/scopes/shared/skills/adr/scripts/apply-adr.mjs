#!/usr/bin/env node
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { spawnSync } from "node:child_process";
import {
  findRecord,
  nextAdrNumber,
  normalizeAdrRef,
  readRecords,
  validateProject,
} from "./adr-validation.mjs";

const CLAUDE_POINTER = [
  "<!-- ADR:INDEX:START -->",
  "## Architecture Decision Records",
  "",
  "Decisions live in `docs/adr/`, indexed in `docs/adr/README.md`. Run `/adr` to record one.",
  "<!-- ADR:INDEX:END -->",
].join("\n");

const args = parseArgs(process.argv.slice(2));
const root = args.root || process.cwd();
const inputPath = args.input;
const dryRun = args.dryRun || false;
const touched = new Map();

if (args.reindex) {
  const action = updateClaudeIndex(root, [...readRecords(root)]);
  console.log(JSON.stringify({ reindex: action, index: "docs/adr/README.md" }, null, 2));
  process.exit(0);
}

if (!inputPath) {
  die("Usage: apply-adr.mjs --input <draft.json> [--root <project-root>] [--dry-run] | --reindex [--root <project-root>]");
}

const draft = readJson(inputPath);

try {
  const preErrors = validateProject(root);
  if (preErrors.length > 0) {
    die([
      "Existing ADR integrity failure. Fix the existing ADR set before recording a new ADR.",
      ...preErrors.map((error) => `- ${error}`),
      "No files were changed.",
    ].join("\n"));
  }

  const records = readRecords(root);
  const normalizedSupersedes = draft.supersedes ? normalizeAdrRef(draft.supersedes) : null;
  const supersededRecord = normalizedSupersedes ? findRecord(records, normalizedSupersedes) : null;

  if (draft.supersedes && !normalizedSupersedes) {
    die(`Input error: supersedes must be ADR-NNNN, got ${JSON.stringify(draft.supersedes)}. Use an existing local ADR id, for example "ADR-0001".`);
  }
  if (normalizedSupersedes && !supersededRecord) {
    die(`Cannot supersede ${normalizedSupersedes} because no local docs/adr/${normalizedSupersedes.slice(4)}-*.md exists. Read docs/adr and choose an existing ADR, or omit supersedes.`);
  }

  const nextNumber = nextAdrNumber(records);
  const newId = `ADR-${String(nextNumber).padStart(4, "0")}`;
  const title = requiredString(draft.title, "title");
  const body = requiredString(draft.body, "body");
  const date = dateFor(draft.date);
  const tags = optionalList(draft.tags, "tags");
  const affectedComponents = optionalList(draft.affected_components, "affected_components");
  const slug = uniqueSlug(root, nextNumber, slugify(draft.slug || title));
  const relativeAdrPath = join("docs", "adr", `${String(nextNumber).padStart(4, "0")}-${slug}.md`);
  const adrPath = join(root, relativeAdrPath);
  const adrContent = renderAdr({
    title,
    body,
    date,
    supersedes: normalizedSupersedes,
    tags,
    affectedComponents,
  });

  if (dryRun) {
    console.log(JSON.stringify({
      dry_run: true,
      would_write: relativeAdrPath,
      id: newId,
      supersedes: normalizedSupersedes,
      would_update_superseded: supersededRecord ? relative(root, supersededRecord.path) : null,
      index: plannedClaudeIndexAction(root),
    }, null, 2));
    process.exit(0);
  }

  mkdirSync(dirname(adrPath), { recursive: true });
  writeTracked(adrPath, adrContent);

  if (supersededRecord) {
    writeTracked(
      supersededRecord.path,
      renderSupersededRecord(supersededRecord.content, newId)
    );
  }

  const indexAction = updateClaudeIndex(root, [...readRecords(root)]);
  const postErrors = validateProject(root);
  if (postErrors.length > 0) {
    const restored = [...touched.keys()].map((path) => relative(root, path)).join(", ") || "none";
    rollback();
    die([
      "ADR write rolled back after validation failure. The project was restored to its previous file contents.",
      ...postErrors.map((error) => `- ${error}`),
      `Files restored: ${restored}.`,
    ].join("\n"));
  }

  console.log(JSON.stringify({
    written: relative(root, adrPath),
    id: newId,
    supersedes: normalizedSupersedes,
    superseded: supersededRecord ? supersededRecord.id : null,
    index: indexAction,
  }, null, 2));
} catch (error) {
  rollback();
  throw error;
}

function parseArgs(argv) {
  const parsed = {};
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--input") {
      parsed.input = argv[++index];
    } else if (arg === "--root") {
      parsed.root = argv[++index];
    } else if (arg === "--reindex") {
      parsed.reindex = true;
    } else if (arg === "--dry-run") {
      parsed.dryRun = true;
    } else if (arg === "--help") {
      console.log("Usage: apply-adr.mjs --input <draft.json> [--root <project-root>] [--dry-run] | --reindex [--root <project-root>]");
      process.exit(0);
    } else {
      die(`Unknown argument: ${arg}. Run with --help for usage.`);
    }
  }
  return parsed;
}

function readJson(path) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    die(`Cannot read JSON input ${path}: ${error.message}`);
  }
}

function die(message) {
  console.error(message);
  process.exit(1);
}

function requiredString(value, key) {
  if (typeof value !== "string" || value.trim() === "") {
    die(`Input error: ${key} is required and must be a non-empty string in the draft JSON.`);
  }
  return value.trim();
}

function optionalList(value, key) {
  if (value === undefined) return [];
  if (!Array.isArray(value)) {
    die(`Input error: ${key} must be an array of strings when provided.`);
  }
  return value.map((item) => {
    if (typeof item !== "string" || item.trim() === "") {
      die(`Input error: ${key} must contain only non-empty strings.`);
    }
    return item.trim();
  });
}

function dateFor(value) {
  if (value === undefined) return new Date().toISOString().slice(0, 10);
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    die("Input error: date must use YYYY-MM-DD when provided.");
  }
  return value;
}

function slugify(value) {
  const slug = value
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 70)
    .replace(/-+$/g, "");
  return slug || "decision";
}

function uniqueSlug(projectRoot, number, baseSlug) {
  let slug = baseSlug;
  let suffix = 2;
  while (existsSync(join(projectRoot, "docs", "adr", `${String(number).padStart(4, "0")}-${slug}.md`))) {
    slug = `${baseSlug}-${suffix}`;
    suffix += 1;
  }
  return slug;
}

function renderAdr({ title, body, date, supersedes, tags, affectedComponents }) {
  const frontmatter = [
    "---",
    "status: accepted",
    `date: ${date}`,
  ];
  if (supersedes) frontmatter.push(`supersedes: ${supersedes}`);
  if (tags.length > 0) frontmatter.push(`tags: [${tags.join(", ")}]`);
  if (affectedComponents.length > 0) {
    frontmatter.push(`affected_components: [${affectedComponents.join(", ")}]`);
  }
  frontmatter.push("---");
  return `${frontmatter.join("\n")}\n\n# ${title}\n\n${body.trim()}\n`;
}

function renderSupersededRecord(content, newId) {
  const split = splitFrontmatter(content);
  if (!split) die("Cannot supersede ADR without YAML frontmatter");

  const blocks = frontmatterBlocks(split.frontmatter)
    .filter((block) => !["status", "superseded_by"].includes(block.key));
  const frontmatter = [
    "---",
    `status: superseded by ${newId}`,
    ...blocks.flatMap((block) => block.lines),
    `superseded_by: ${newId}`,
    "---",
  ].join("\n");
  const body = split.body.includes(`Superseded by ${newId}`)
    ? split.body.trimEnd()
    : `${split.body.trimEnd()}\n\nSuperseded by ${newId}.`;
  return `${frontmatter}\n${body}\n`;
}

function splitFrontmatter(content) {
  if (!content.startsWith("---\n")) return null;
  const end = content.indexOf("\n---", 4);
  if (end === -1) return null;
  const closeEnd = end + "\n---".length;
  return {
    frontmatter: content.slice(4, end),
    body: content.slice(closeEnd),
  };
}

function frontmatterBlocks(frontmatter) {
  const blocks = [];
  let current = null;
  for (const line of frontmatter.split("\n")) {
    const key = line.match(/^([A-Za-z_][A-Za-z0-9_-]*):/);
    if (key) {
      current = { key: key[1].toLowerCase(), lines: [line] };
      blocks.push(current);
    } else if (current) {
      current.lines.push(line);
    }
  }
  return blocks;
}

function adrIndexPath(projectRoot) {
  return join(projectRoot, "docs/adr/README.md");
}

function updateClaudeIndex(projectRoot, records) {
  const indexPath = adrIndexPath(projectRoot);
  const action = existsSync(indexPath) ? "updated" : "created";

  if (action === "created" && !isGitRepo(projectRoot)) return "skipped";

  writeTracked(indexPath, renderIndex(records));
  updateClaudePointer(projectRoot);
  return action;
}

function updateClaudePointer(projectRoot) {
  const claudePath = join(projectRoot, "CLAUDE.md");

  if (!existsSync(claudePath)) {
    if (!isGitRepo(projectRoot)) return;
    const agentsPath = join(projectRoot, "AGENTS.md");
    const prefix = existsSync(agentsPath) ? "@AGENTS.md\n\n" : "";
    writeTracked(claudePath, `${prefix}${CLAUDE_POINTER}\n`);
    return;
  }

  const content = readFileSync(claudePath, "utf8");
  if (content.includes("<!-- ADR:INDEX:START -->")) {
    const updated = content.replace(
      /<!-- ADR:INDEX:START -->[\s\S]*?<!-- ADR:INDEX:END -->/,
      CLAUDE_POINTER
    );
    if (updated !== content) writeTracked(claudePath, `${updated.trimEnd()}\n`);
    return;
  }

  writeTracked(claudePath, `${content.trimEnd()}\n\n${CLAUDE_POINTER}\n`);
}

function plannedClaudeIndexAction(projectRoot) {
  if (existsSync(adrIndexPath(projectRoot))) return "updated";
  if (!isGitRepo(projectRoot)) return "skipped";
  return "created";
}

function renderIndex(records) {
  const lines = [
    "# Architecture Decision Records",
    "",
    "Decisions live in this directory. Run `/adr` to record one.",
    "",
  ];

  for (const record of records.sort((a, b) => (a.id || "").localeCompare(b.id || ""))) {
    if (!record.id) continue;
    const status = record.frontmatter.status?.[0] || "unknown";
    lines.push(`- [${record.id.slice(4)}](${record.file}) — ${record.title || record.file} [${status}]`);
  }

  lines.push("");
  return lines.join("\n");
}

function isGitRepo(projectRoot) {
  const result = spawnSync("git", ["-C", projectRoot, "rev-parse", "--is-inside-work-tree"], {
    encoding: "utf8",
  });
  return result.status === 0 && result.stdout.trim() === "true";
}

function writeTracked(path, content) {
  if (!touched.has(path)) {
    touched.set(path, existsSync(path) ? readFileSync(path, "utf8") : null);
  }
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, content, "utf8");
}

function rollback() {
  for (const [path, previous] of [...touched.entries()].reverse()) {
    if (previous === null) {
      rmSync(path, { force: true });
    } else {
      writeFileSync(path, previous, "utf8");
    }
  }
}
