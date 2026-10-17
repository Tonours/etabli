import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

function withFix(message, fix) {
  return `${message} Fix: ${fix}`;
}

export function hasAdrDirectory(projectRoot) {
  return existsSync(join(projectRoot, "docs", "adr"));
}

export function cleanValue(value) {
  return String(value).trim().replace(/^['"]|['"]$/g, "");
}

export function parseListValue(raw) {
  const value = cleanValue(raw);
  if (value === "") return [];
  if (value.startsWith("[") && value.endsWith("]")) {
    return value
      .slice(1, -1)
      .split(",")
      .map(cleanValue)
      .filter(Boolean);
  }
  return [value];
}

export function parseFrontmatter(content) {
  if (!content.startsWith("---\n")) return {};
  const end = content.indexOf("\n---", 4);
  if (end === -1) return {};

  const frontmatter = {};
  let currentKey = null;
  const lines = content.slice(4, end).split("\n");

  for (const line of lines) {
    const keyValue = line.match(/^([A-Za-z_][A-Za-z0-9_-]*):\s*(.*)$/);
    if (keyValue) {
      currentKey = keyValue[1].toLowerCase();
      frontmatter[currentKey] = parseListValue(keyValue[2]);
      continue;
    }

    const listItem = line.match(/^\s*-\s+(.+)$/);
    if (currentKey && listItem) {
      frontmatter[currentKey].push(cleanValue(listItem[1]));
    }
  }

  return frontmatter;
}

export function normalizeAdrRef(value) {
  const match = String(value).trim().match(/^(?:ADR[-_ ]?)?0*(\d{1,4})$/i);
  if (!match) return null;
  return `ADR-${match[1].padStart(4, "0")}`;
}

export function refsFor(record, key) {
  return (record.frontmatter[key] || []).map((value) => ({
    raw: value,
    ref: normalizeAdrRef(value),
  }));
}

export function titleFor(content) {
  const match = content.match(/^#\s+(.+)$/m);
  return match ? match[1].trim() : "";
}

export function idFromFilename(file) {
  const match = file.match(/^(\d{4})-/);
  return match ? `ADR-${match[1]}` : null;
}

export function readRecords(projectRoot) {
  const adrDir = join(projectRoot, "docs", "adr");
  if (!existsSync(adrDir)) return [];

  return readdirSync(adrDir)
    .filter((file) => file.endsWith(".md") && file !== "README.md")
    .sort()
    .map((file) => {
      const path = join(adrDir, file);
      const content = readFileSync(path, "utf8");
      return {
        file,
        path,
        id: idFromFilename(file),
        title: titleFor(content),
        frontmatter: parseFrontmatter(content),
        content,
      };
    });
}

export function validateProject(projectRoot) {
  const errors = [];
  validateClaudeIndex(projectRoot, errors);
  validateRecords(readRecords(projectRoot), errors);
  return errors;
}

const INDEX_ENTRY_RE = /^\s*-\s+\[(\d{4})\]\((?:docs\/adr\/)?([^)\s]+\.md)\)/;

export function parseClaudeIndexEntries(block) {
  const entries = [];
  for (const line of block.split("\n")) {
    const match = line.match(INDEX_ENTRY_RE);
    if (match) entries.push({ file: match[2] });
  }
  return entries;
}

export function validateClaudeIndex(projectRoot, errors) {
  validateClaudePointerMarkers(projectRoot, errors);

  const indexPath = join(projectRoot, "docs/adr/README.md");
  if (!existsSync(indexPath)) return;

  validateIndexCompleteness(projectRoot, readFileSync(indexPath, "utf8"), errors);
}

export function validateClaudePointerMarkers(projectRoot, errors) {
  const claudePath = join(projectRoot, "CLAUDE.md");
  if (!existsSync(claudePath)) return;

  const content = readFileSync(claudePath, "utf8");
  const startCount = (content.match(/<!-- ADR:INDEX:START -->/g) || []).length;
  const endCount = (content.match(/<!-- ADR:INDEX:END -->/g) || []).length;

  if (startCount !== endCount) {
    errors.push(withFix(
      `CLAUDE.md ADR index markers are unbalanced (${startCount} start, ${endCount} end).`,
      "Keep exactly one START marker paired with one END marker, or remove the partial ADR index block."
    ));
    return;
  }
  if (startCount > 1) {
    errors.push(withFix(
      `CLAUDE.md contains ${startCount} ADR index blocks; expected at most one.`,
      "Merge the entries into one ADR index block and delete the extra marker pair."
    ));
    return;
  }
  if (startCount !== 1) return;

  if (content.indexOf("<!-- ADR:INDEX:END -->") <= content.indexOf("<!-- ADR:INDEX:START -->")) {
    errors.push(withFix(
      "CLAUDE.md ADR index END marker appears before START.",
      "Place the START marker above the END marker."
    ));
  }
}

export function validateIndexCompleteness(projectRoot, block, errors) {
  const listed = parseClaudeIndexEntries(block);
  const listedFiles = new Set();

  for (const entry of listed) {
    if (listedFiles.has(entry.file)) {
      errors.push(withFix(
        `docs/adr/README.md lists ${entry.file} more than once.`,
        "Keep a single list entry for that ADR."
      ));
      continue;
    }
    listedFiles.add(entry.file);
  }

  const diskFiles = readRecords(projectRoot)
    .filter((record) => record.id)
    .map((record) => record.file)
    .sort();

  for (const file of diskFiles) {
    if (!listedFiles.has(file)) {
      errors.push(withFix(
        `docs/adr/README.md is missing ${file}.`,
        "Add a list entry for that ADR, or rerun the ADR helper."
      ));
    }
  }

  for (const file of [...listedFiles].sort()) {
    if (!diskFiles.includes(file)) {
      errors.push(withFix(
        `docs/adr/README.md lists ${file}, which is not in docs/adr/.`,
        "Remove the extra index entry or add the missing ADR file."
      ));
    }
  }
}

export function validateRecords(records, errors) {
  const byId = new Map();
  for (const record of records) {
    if (!record.id) {
      errors.push(withFix(
        `${record.file}: ADR filename must start with NNNN-.`,
        "Rename it to the next ADR number, for example 0001-short-title.md."
      ));
      continue;
    }
    if (!byId.has(record.id)) byId.set(record.id, []);
    byId.get(record.id).push(record);
  }

  for (const [id, matches] of byId.entries()) {
    if (matches.length > 1) {
      errors.push(withFix(
        `${id}: duplicate ADR number in ${matches.map((record) => record.file).join(", ")}.`,
        "Keep one file for that ADR number and rename later decisions to the next available number."
      ));
    }
  }

  for (const record of records) {
    validateRequiredFields(record, errors);

    for (const key of ["supersedes", "superseded_by"]) {
      for (const { raw, ref } of refsFor(record, key)) {
        if (!ref) {
          errors.push(withFix(
            `${record.file}: ${key} value "${raw}" must be ADR-NNNN.`,
            `Use ${key}: ADR-0001 style references.`
          ));
          continue;
        }
        if (ref === record.id) {
          errors.push(withFix(
            `${record.file}: ${key} must not reference itself.`,
            "Remove the self-reference or point it at the separate ADR that actually replaces it."
          ));
        }
        if (!byId.has(ref)) {
          errors.push(withFix(
            `${record.file}: ${key} references missing ${ref}.`,
            "Create the referenced ADR first, choose an existing ADR, or remove the reference."
          ));
        }
      }
    }

    for (const key of ["tags", "affected_components"]) {
      if (key in record.frontmatter && record.frontmatter[key].length === 0) {
        errors.push(withFix(
          `${record.file}: ${key} must be omitted or contain at least one value.`,
          `Delete ${key} or add at least one non-empty value.`
        ));
      }
    }
  }

  for (const record of records) {
    const supersedes = refsFor(record, "supersedes").map(({ ref }) => ref).filter(Boolean);
    const supersededBy = refsFor(record, "superseded_by").map(({ ref }) => ref).filter(Boolean);
    const status = (record.frontmatter.status?.[0] || "").toLowerCase();
    const statusRef = normalizeAdrRef(status.match(/superseded by\s+(ADR[-_ ]?\d{1,4}|\d{1,4})/i)?.[1] || "");

    if (supersededBy.length > 0 && (!statusRef || !supersededBy.includes(statusRef))) {
      errors.push(withFix(
        `${record.file}: superseded_by must match status: superseded by ADR-NNNN.`,
        "Set status and superseded_by to the same replacement ADR."
      ));
    }
    if (statusRef && !supersededBy.includes(statusRef)) {
      errors.push(withFix(
        `${record.file}: status says superseded by ${statusRef} but superseded_by is missing it.`,
        `Add superseded_by: ${statusRef} or change the status back to accepted.`
      ));
    }

    for (const targetId of supersedes) {
      const target = byId.get(targetId)?.[0];
      if (!target) continue;
      const reverseRefs = refsFor(target, "superseded_by").map(({ ref }) => ref).filter(Boolean);
      if (!reverseRefs.includes(record.id)) {
        errors.push(withFix(
          `${record.file}: supersedes ${targetId}, but ${target.file} does not list superseded_by: ${record.id}.`,
          `Update ${target.file} with status: superseded by ${record.id} and superseded_by: ${record.id}.`
        ));
      }
    }

    for (const targetId of supersededBy) {
      const target = byId.get(targetId)?.[0];
      if (!target) continue;
      const reverseRefs = refsFor(target, "supersedes").map(({ ref }) => ref).filter(Boolean);
      if (!reverseRefs.includes(record.id)) {
        errors.push(withFix(
          `${record.file}: is superseded by ${targetId}, but ${target.file} does not list supersedes: ${record.id}.`,
          `Update ${target.file} with supersedes: ${record.id}, or remove this superseded_by link.`
        ));
      }
    }
  }
}

export function validateRequiredFields(record, errors) {
  if (!record.title) {
    errors.push(withFix(
      `${record.file}: ADR title is required.`,
      "Add a top-level Markdown heading such as # Use Postgres for events."
    ));
  }

  const status = record.frontmatter.status?.[0] || "";
  if (!status) {
    errors.push(withFix(
      `${record.file}: frontmatter status is required.`,
      "Add YAML frontmatter with status: accepted, proposed, rejected, deprecated, or superseded by ADR-NNNN."
    ));
  } else if (!/^(accepted|proposed|rejected|deprecated|superseded by ADR-\d{4})$/i.test(status)) {
    errors.push(withFix(
      `${record.file}: status must be accepted, proposed, rejected, deprecated, or superseded by ADR-NNNN.`,
      "Use one supported status value exactly."
    ));
  }

  const date = record.frontmatter.date?.[0] || "";
  if (!date) {
    errors.push(withFix(
      `${record.file}: frontmatter date is required.`,
      "Add date: YYYY-MM-DD to the YAML frontmatter."
    ));
  } else if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    errors.push(withFix(
      `${record.file}: date must use YYYY-MM-DD.`,
      "Rewrite the date as four-digit year, two-digit month, two-digit day."
    ));
  }
}

export function findRecord(records, id) {
  return records.find((record) => record.id === id);
}

export function nextAdrNumber(records) {
  return records.reduce((max, record) => {
    const ref = normalizeAdrRef(record.id || "");
    return Math.max(max, ref ? Number(ref.slice(4)) : 0);
  }, 0) + 1;
}
