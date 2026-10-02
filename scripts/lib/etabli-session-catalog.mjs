import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { loadScope } from "./claude-profile.mjs";
import { readEvidence } from "./review-evidence-pack.mjs";

function metadata(text) {
  const header = text.replaceAll("\r\n", "\n").match(/^---\n([\s\S]*?)\n---(?:\n|$)/)?.[1] || "";
  const fields = {};
  for (const line of header.split("\n")) {
    const match = line.match(/^([a-z][a-z-]*):\s*(.*)$/);
    if (match) fields[match[1]] = match[2].replace(/^['"]|['"]$/g, "");
  }
  if (/^[>|][-+]?\s*$/.test(fields.description || "")) {
    fields.description = header.match(/^description:\s*[>|][-+]?\s*\n((?:[ \t]+.*(?:\n|$))*)/m)?.[1].trim().replace(/\n\s*/g, " ") || "";
  }
  return fields;
}

function skill(root, path, source, scope, catalogName) {
  try {
    const evidence = readEvidence(root, path, { maxBytes: 16_777_216 });
    const fields = metadata(evidence.text);
    const declared = fields.name;
    const name = declared && /^[a-z0-9][a-z0-9-]*$/.test(declared) ? declared : catalogName.split("/").at(-1);
    return {
      name, catalog_name: catalogName, path, source, scope, available: true,
      description: fields.description || null,
      model_invocation: fields["disable-model-invocation"] === "true" ? "explicit-only" : "declared-allowed",
      user_invocable: fields["user-invocable"] === "false" ? false : true,
      invocation_condition: fields.description || "Not declared; consult SKILL.md",
      sha256: evidence.file_sha256,
    };
  } catch (error) {
    return { name: catalogName.split("/").at(-1), catalog_name: catalogName, path, source, scope, available: false, error: error.message };
  }
}

export function skillCatalog(root, home) {
  const vendors = new Map(readFileSync(join(root, "vendor/sources.tsv"), "utf8")
    .split("\n").filter((line) => line && !line.startsWith("#"))
    .map((line) => { const row = line.split("\t"); return [row[0], row[3]]; }));
  const rows = readFileSync(join(root, "workflow/runtime/skill-surface.tsv"), "utf8")
    .split("\n").filter((line) => line && !line.startsWith("#"));
  const skills = rows.map((line) => {
    const [name, source, piCore, visible, locked] = line.split("\t");
    const directory = source === "pi" ? "pi/skills" : source === "extras" ? "extras/skills" : `vendor/${source}/skills`;
    const scope = vendors.get(source) || "shared";
    return { ...skill(root, `${directory}/${name}/SKILL.md`, source, scope, name),
      declared_surfaces: { pi_core: piCore === "1", agents_visible: visible === "1", locked: locked === "1" },
      opt_in: piCore === "0" && visible === "0" && locked === "0" };
  });
  for (const scope of ["shared", "work", "personal"]) {
    const directory = `claude/scopes/${scope}/skills`;
    let entries;
    try { entries = readdirSync(join(root, directory), { withFileTypes: true }); }
    catch (error) { if (error.code === "ENOENT") continue; throw error; }
    for (const entry of entries.filter((entry) => entry.isDirectory())) {
      skills.push(skill(root, `${directory}/${entry.name}/SKILL.md`, "claude", scope, entry.name));
    }
  }
  let declaredScope = null;
  try { declaredScope = readFileSync(join(home, ".etabli-scope"), "utf8").trim(); }
  catch (error) { if (error.code !== "ENOENT") declaredScope = "unreadable"; }
  const activeScope = loadScope(home);
  return {
    active_scope: activeScope,
    scope_source: ["work", "personal"].includes(declaredScope) ? "~/.etabli-scope" : "installer default: personal",
    runtime_visibility: "unknown until $.command.list is observed",
    items: skills.map((entry) => ({ ...entry, scope_active: entry.scope === "shared" || entry.scope === activeScope })),
  };
}
