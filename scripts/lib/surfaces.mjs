#!/usr/bin/env node
import {
  closeSync,
  constants,
  copyFileSync,
  existsSync,
  fchmodSync,
  fsyncSync,
  lstatSync,
  mkdirSync,
  openSync,
  readFileSync,
  readdirSync,
  readlinkSync,
  realpathSync,
  renameSync,
  rmSync,
  statSync,
  symlinkSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { randomBytes } from "node:crypto";
import { userInfo } from "node:os";
import { basename, dirname, join, relative, sep } from "node:path";
import { pathToFileURL } from "node:url";

const realpath = realpathSync.native;

const SKILL_SLUG = /^[a-z0-9][a-z0-9-]*$/;
const SHADOWS = [["work", "adr"]];
const PI_SKILLS = ".pi/agent/skills";
const CLAUDE_SKILLS = ".claude/skills";
const MAX_LINK_DEPTH = 40;
const MANAGED_SKILL_TARGET = /^(skills\/[^/]+|pi\/skills|vendor\/[^/]+\/skills|claude\/scopes\/[^/]+\/skills)\/./;
const ORPHAN_SKILL_TARGET = /^(skills\/[^/]+|vendor\/[^/]+\/skills)\/./;
const TIMESTAMP_BACKUP = /^\.bak[.-](\d{8}-\d{6}|\d{8}T\d{6}Z?)(\.\d+)?$/;
const KEPT_BACKUPS = 5;

function lstatOrNull(path) {
  try {
    return lstatSync(path);
  } catch {
    return null;
  }
}

function isDir(path) {
  try {
    return statSync(path).isDirectory();
  } catch {
    return false;
  }
}

function entries(dir) {
  try {
    return readdirSync(dir).sort();
  } catch {
    return [];
  }
}

function globEntries(dir, suffix) {
  return entries(dir).filter((name) => !name.startsWith(".") && (!suffix || name.endsWith(suffix)));
}

function tsvRows(path) {
  return readFileSync(path, "utf8")
    .split("\n")
    .filter((line) => line && !line.startsWith("#"))
    .map((line) => line.split("\t"));
}

function frontmatterName(skillDir) {
  let lines;
  try {
    lines = readFileSync(join(skillDir, "SKILL.md"), "utf8").split("\n");
  } catch {
    return "";
  }
  if (lines[0] !== "---") return "";
  for (const line of lines.slice(1)) {
    if (line === "---") return "";
    const match = line.match(/^name:\s+(.*)$/);
    if (match) return match[1].replace(/^["']|["']$/g, "");
  }
  return "";
}

export function declaredName(skillDir) {
  const declared = frontmatterName(skillDir);
  return SKILL_SLUG.test(declared) ? declared : basename(skillDir);
}

export function skillRecords(repoDir) {
  const catalogPath = join(repoDir, "workflow/runtime/skill-surface.tsv");
  const sourcesPath = join(repoDir, "vendor/sources.tsv");
  if (!existsSync(catalogPath) || !existsSync(sourcesPath)) return null;
  const catalog = tsvRows(catalogPath).filter((row) => row.length >= 4 && row[0]);
  const record = (scope, dir, piCore, source) => ({ scope, name: declaredName(dir), dir, piCore, source });
  const records = catalog
    .filter((row) => row[1] === "etabli")
    .map(([name, , piCore]) => record(name.split("/")[0], join(repoDir, "skills", name), piCore, "etabli"));
  for (const [vendor, , , scope] of tsvRows(sourcesPath)) {
    for (const [name, , piCore] of catalog.filter((row) => row[1] === vendor)) {
      records.push(record(scope, join(repoDir, "vendor", vendor, "skills", name), piCore, vendor));
    }
  }
  return records;
}

export function surfaceExpected(surface, record, scopes) {
  if (!record.scope || !scopes.includes(record.scope)) return false;
  return surface !== PI_SKILLS || record.piCore === "1";
}

export function isShadowed(name, scopes) {
  return SHADOWS.some(([scope, skill]) => skill === name && scopes.includes(scope));
}

export function physicalHome(path) {
  return path ? physicalPath(path.startsWith("/") ? path : `${process.cwd()}/${path}`) : null;
}

export function activeScopes(homeDir, env = process.env) {
  const home = physicalHome(homeDir);
  if (home === null) throw new Error(`cannot resolve home directory: ${homeDir}`);
  const scopeFile = join(home, ".etabli-scope");
  let declared = env.ETABLI_SCOPE ?? "";
  if (!declared && existsSync(scopeFile) && statSync(scopeFile).isFile()) {
    declared = readFileSync(scopeFile, "utf8").replace(/\s/g, "");
  }
  if (declared === "") return ["shared"];
  if (declared === "work" || declared === "personal") return ["shared", declared];
  throw new Error(
    `unknown scope ${JSON.stringify(declared)} in ${scopeFile}: expected work or personal; fix the file or unset ETABLI_SCOPE`,
  );
}

function physicalDir(path) {
  return path && isDir(path) ? realpath(path) : null;
}

function loginHome() {
  try {
    return physicalDir(userInfo().homedir);
  } catch {
    return null;
  }
}

export function claudeConfigOverride(env = process.env) {
  const configDir = physicalDir(env.CLAUDE_CONFIG_DIR);
  const homeDir = physicalDir(env.HOME);
  if (!configDir || !homeDir || configDir === join(homeDir, ".claude")) return null;
  if (configDir === physicalDir(join(homeDir, ".claude"))) return null;
  if (configDir.startsWith(homeDir + sep)) return configDir;
  return homeDir === loginHome() ? configDir : null;
}

export function claudeEffectiveDir(env = process.env) {
  return claudeConfigOverride(env) ?? `${env.HOME.replace(/\/+$/, "")}/.claude`;
}

function linkTarget(link) {
  const raw = readlinkSync(link);
  return raw.startsWith("/") ? raw : `${dirname(link)}/${raw}`;
}

export function physicalPath(path, depth = 0) {
  try {
    return realpath(path);
  } catch (error) {
    if (error.code !== "ENOENT" && error.code !== "ENOTDIR") return null;
    if (dirname(path) === path) return path;
  }
  const head = physicalPath(dirname(path), depth);
  const name = basename(path);
  if (head === null || name === "" || name === ".") return head;
  if (name === "..") return dirname(head);
  const joined = join(head, name);
  if (!lstatOrNull(joined)?.isSymbolicLink()) return joined;
  return depth < MAX_LINK_DEPTH ? physicalPath(linkTarget(joined), depth + 1) : null;
}

function under(path, root) {
  return path !== null && path.startsWith(root + sep);
}

function backupPath(path, timestamp) {
  const parent = dirname(path);
  const base = basename(parent) === "skills" ? join(`${parent}.bak`, basename(path)) : path;
  let candidate = `${base}.bak.${timestamp}`;
  for (let index = 1; lstatOrNull(candidate); index += 1) candidate = `${base}.bak.${timestamp}.${index}`;
  return candidate;
}

export function backupStamp(date = new Date()) {
  return date.toISOString().replace(/[-:]|\.\d+/g, "");
}

export function backupFile(path, { stamp = backupStamp(), keep = KEPT_BACKUPS } = {}) {
  let backup = `${path}.bak.${stamp}`;
  for (let index = 1; lstatOrNull(backup); index += 1) backup = `${path}.bak.${stamp}.${index}`;
  copyFileSync(path, backup, constants.COPYFILE_EXCL);
  rotateBackups(path, keep);
  return backup;
}

export function rotateBackups(path, keep = KEPT_BACKUPS) {
  const dir = dirname(path);
  const name = basename(path);
  const removed = entries(dir)
    .filter((entry) => entry.startsWith(name) && TIMESTAMP_BACKUP.test(entry.slice(name.length)))
    .map((entry) => ({ path: join(dir, entry), stat: lstatOrNull(join(dir, entry)) }))
    .filter(({ stat }) => stat?.isFile())
    .sort((a, b) => b.stat.mtimeMs - a.stat.mtimeMs)
    .slice(keep)
    .map((backup) => backup.path);
  for (const backup of removed) rmSync(backup, { force: true });
  return removed;
}

function replaceFile(path, content, mode) {
  const staged = join(dirname(path), `.${basename(path)}.${process.pid}.${randomBytes(4).toString("hex")}.tmp`);
  const fd = openSync(staged, "wx", 0o600);
  try {
    try {
      writeFileSync(fd, content);
      fchmodSync(fd, mode);
      fsyncSync(fd);
    } finally {
      closeSync(fd);
    }
    renameSync(staged, path);
  } catch (error) {
    rmSync(staged, { force: true });
    throw error;
  }
  try {
    const dirFd = openSync(dirname(path), "r");
    try {
      fsyncSync(dirFd);
    } finally {
      closeSync(dirFd);
    }
  } catch {}
}

export function writeJsonAtomic(path, value) {
  const target = existsSync(path) ? realpath(path) : path;
  const mode = lstatOrNull(target)?.mode ?? 0o600;
  replaceFile(target, `${JSON.stringify(value, null, 2)}\n`, mode & 0o7777);
}

function moveAside(ctx, path) {
  const backup = backupPath(path, ctx.timestamp);
  mkdirSync(dirname(backup), { recursive: true });
  renameSync(path, backup);
  ctx.emit("BACKUP", backup);
}

function inRepo(ctx, path) {
  return under(physicalPath(path), ctx.repoReal);
}

function isDisposable(ctx, path) {
  if (!lstatOrNull(path)?.isSymbolicLink()) return false;
  const parent = physicalPath(dirname(path));
  return (parent !== null && under(join(parent, basename(path)), ctx.repoReal)) || inRepo(ctx, linkTarget(path));
}

function unresolved(ctx, status, message) {
  ctx.counts.unresolved += 1;
  if (ctx.mode === "check") ctx.counts.issues += 1;
  ctx.emit(status, message);
}

function report(ctx, verb, label, fix) {
  if (ctx.mode === "check") {
    ctx.counts.issues += 1;
    ctx.emit("WARN", label);
  } else if (!ctx.apply) {
    ctx.emit(`WOULD_${verb}`, label);
  }
  if (!ctx.apply) return;
  try {
    fix();
  } catch (error) {
    ctx.counts.unresolved += 1;
    ctx.emit("FAIL", `${label}: ${error.message}`);
    return;
  }
  if (ctx.mode === "check") ctx.counts.fixed += 1;
  ctx.emit(ctx.mode === "check" ? "FIXED" : verb, label);
}

function ok(ctx, message, status = "OK") {
  if (ctx.mode === "deploy" || ctx.verbose) ctx.emit(status, message);
}

function ensureLink(ctx, source, dest, label) {
  if (!lstatOrNull(source)) {
    unresolved(ctx, ctx.mode === "check" ? "WARN" : "MISSING", `${label} source missing (expected ${source})`);
    return;
  }
  const stat = lstatOrNull(dest);
  const current = stat?.isSymbolicLink() ? readlinkSync(dest) : null;
  if (current === source && existsSync(dest)) {
    ok(ctx, label);
    return;
  }
  const replace = current !== null && (ctx.install || isDisposable(ctx, dest));
  let state = "missing";
  if (current !== null) state = `-> ${current}`;
  else if (stat) state = "exists but is not a symlink";
  if (!ctx.apply && ctx.mode === "deploy" && stat) ctx.emit(replace ? "WOULD_REPLACE" : "WOULD_BACKUP", dest);
  report(ctx, "LINK", ctx.mode === "check" ? `${label} ${state} (expected ${source})` : `${label} -> ${source}`, () => {
    mkdirSync(dirname(dest), { recursive: true });
    if (replace) unlinkSync(dest);
    else if (stat) moveAside(ctx, dest);
    symlinkSync(source, dest);
  });
}

function ensureAbsent(ctx, path, label) {
  if (!lstatOrNull(path)) {
    ok(ctx, `${label} absent`);
  } else if (isDisposable(ctx, path)) {
    report(ctx, "REMOVE", `${label} exists but must be absent`, () => unlinkSync(path));
  } else {
    report(ctx, "BACKUP", `${label} exists but must be absent`, () => moveAside(ctx, path));
  }
}

function retireLink(ctx, path, label, retiredSource) {
  const stat = lstatOrNull(path);
  if (stat?.isSymbolicLink() && readlinkSync(path) === retiredSource) {
    report(ctx, "REMOVE", label, () => unlinkSync(path));
  } else {
    ok(ctx, stat ? `${label} unmanaged` : `${label} absent`, stat ? "KEEP" : "OK");
  }
}

function pruneLink(ctx, link, label) {
  report(ctx, "REMOVE", label, () => unlinkSync(link));
}

function links(dir, { hidden = false, suffix } = {}) {
  const names = hidden ? entries(dir) : globEntries(dir, suffix);
  return names.map((name) => join(dir, name)).filter((path) => lstatOrNull(path)?.isSymbolicLink());
}

function pruneStaleChildren(ctx, dir, managedParent, label, suffix) {
  for (const link of links(dir, { suffix })) {
    if (existsSync(link)) continue;
    const target = physicalPath(linkTarget(link));
    if (!under(target, ctx.repoReal) || basename(target) !== basename(link)) continue;
    if (managedParent.test(relative(ctx.repoReal, dirname(target)))) pruneLink(ctx, link, `${label} ${basename(link)}`);
  }
}

function skillSurfaces(ctx) {
  const surfaces = [[CLAUDE_SKILLS, join(ctx.claudeRoot, "skills")]];
  if (!ctx.claudeOnly) surfaces.unshift([PI_SKILLS, join(ctx.homeDir, PI_SKILLS)]);
  return surfaces;
}

function matchingRecord(ctx, name, raw) {
  return ctx.records.find((record) => {
    const suffix = relative(ctx.repoDir, record.dir).replace(/^vendor\//, "");
    return record.name === name && (raw === record.dir || raw.endsWith(`/${suffix}`));
  });
}

function pruneSkillLinks(ctx, surface, dir) {
  for (const link of links(dir)) {
    const name = basename(link);
    const raw = readlinkSync(link);
    if (raw.includes("/.claude/skills/") && !existsSync(link)) {
      pruneLink(ctx, link, `broken cross-surface mirror ${name} from ${surface}`);
      continue;
    }
    const record = matchingRecord(ctx, name, raw);
    if (record) {
      const shadowed = surface === CLAUDE_SKILLS && isShadowed(name, ctx.scopes);
      if (shadowed || !surfaceExpected(surface, record, ctx.scopes)) pruneLink(ctx, link, `skill ${name} not expected in ${surface}`);
      continue;
    }
    const target = physicalPath(linkTarget(link));
    if (under(target, ctx.repoReal) && ORPHAN_SKILL_TARGET.test(relative(ctx.repoReal, target))) {
      pruneLink(ctx, link, `orphan skill ${name} from ${surface}`);
    }
  }
}

function reconcileSkills(ctx) {
  ctx.emit("SECTION", "Skills");
  for (const [surface, dir] of skillSurfaces(ctx)) {
    for (const link of links(dir, { hidden: true })) {
      if (existsSync(link)) continue;
      const target = physicalPath(linkTarget(link));
      if (under(target, ctx.repoReal) && MANAGED_SKILL_TARGET.test(relative(ctx.repoReal, target))) {
        pruneLink(ctx, link, `stale managed skill ${basename(link)} from ${surface}`);
      }
    }
  }
  if (ctx.records === null) {
    unresolved(ctx, "WARN", `skill catalog source missing; expected ${join(ctx.repoDir, "workflow/runtime/skill-surface.tsv")}`);
    return;
  }
  for (const [surface, dir] of skillSurfaces(ctx)) pruneSkillLinks(ctx, surface, dir);
  for (const record of ctx.records) {
    for (const [surface, dir] of skillSurfaces(ctx)) {
      if (!surfaceExpected(surface, record, ctx.scopes)) continue;
      if (surface === CLAUDE_SKILLS && isShadowed(record.name, ctx.scopes)) continue;
      const runtime = surface === CLAUDE_SKILLS ? "Claude" : "Pi";
      ensureLink(ctx, record.dir, join(dir, record.name), `${runtime} skill ${record.name}`);
    }
  }
}

function repoFiles(dir, suffix) {
  return globEntries(dir, suffix).filter((name) => lstatOrNull(join(dir, name))?.isFile());
}

function reconcileNodeModules(ctx) {
  const nodeModules = join(ctx.homeDir, ".pi/agent/npm/node_modules");
  const label = "Pi extension node_modules";
  if (!ctx.live) {
    ctx.emit("SKIP", `${label} repo link for isolated or non-default home`);
  } else if (!ctx.apply && ctx.mode === "deploy" && !existsSync(nodeModules)) {
    ctx.emit("WOULD_LINK", `${label} -> ${nodeModules}`);
  } else {
    if (ctx.apply) mkdirSync(nodeModules, { recursive: true });
    ensureLink(ctx, nodeModules, join(ctx.repoDir, "pi/extensions/node_modules"), label);
  }
}

function reconcilePi(ctx) {
  const { repoDir, homeDir } = ctx;
  const agentDir = join(homeDir, ".pi/agent");
  ctx.emit("SECTION", "Pi");
  ensureLink(ctx, join(repoDir, "workflow/agent-rules.md"), join(agentDir, "AGENTS.md"), "Pi AGENTS.md");
  ensureLink(ctx, join(repoDir, "workflow"), join(agentDir, "workflow"), "Pi workflow");
  for (const template of ["PLAN_TEMPLATE.md", "PLAN_TEMPLATE_FULL.md"]) {
    ensureLink(ctx, join(repoDir, template), join(agentDir, template), `Pi ${template}`);
  }
  ensureLink(ctx, join(repoDir, "pi/models.json"), join(agentDir, "models.json"), "Pi models.json");
  retireLink(ctx, join(agentDir, "subagents.json"), "retired Pi subagents.json", join(repoDir, "pi/agent/subagents.json"));
  ensureLink(ctx, join(repoDir, "pi/settings.json"), join(homeDir, ".pi/settings.json"), "Pi settings.json");
  for (const name of repoFiles(join(repoDir, "pi/agents"), ".md")) {
    ensureLink(ctx, join(repoDir, "pi/agents", name), join(agentDir, "agents", name), `Pi agent ${name}`);
  }
  ensureAbsent(ctx, join(homeDir, ".pi/extensions"), "Pi root extensions path");
  ensureLink(ctx, join(repoDir, "scripts"), join(homeDir, ".pi/scripts"), "Pi canonical scripts");
  ensureLink(ctx, join(repoDir, "workflow"), join(homeDir, ".pi/workflow"), "Pi canonical workflow");
  ensureLink(ctx, join(repoDir, "pi/extensions"), join(agentDir, "extensions"), "Pi agent extensions");
  ensureLink(ctx, join(repoDir, "pi/themes"), join(homeDir, ".pi/themes"), "Pi themes");
  reconcileNodeModules(ctx);
  for (const name of repoFiles(join(repoDir, "pi/themes"), ".json")) {
    ensureLink(ctx, join(repoDir, "pi/themes", name), join(agentDir, "themes", name), `Pi theme ${name}`);
  }
  for (const script of ["fix-links", "deploy-workflow"]) {
    ensureLink(ctx, join(repoDir, "scripts", script), join(homeDir, ".local/bin", script), `script ${script}`);
  }
}

function reconcileClaudeHooks(ctx) {
  const hooksDir = join(ctx.repoDir, "claude/hooks");
  for (const suffix of [".mjs", ".sh"]) {
    for (const name of repoFiles(hooksDir, suffix)) {
      ensureLink(ctx, join(hooksDir, name), join(ctx.claudeRoot, "hooks", name), `Claude hook ${name}`);
    }
  }
  for (const link of links(join(ctx.claudeRoot, "hooks"))) {
    const retired = join(hooksDir, basename(link));
    if (readlinkSync(link) === retired && !existsSync(retired)) pruneLink(ctx, link, `stale Claude hook ${basename(link)}`);
  }
}

function reconcileClaudeScopes(ctx) {
  const { repoDir, claudeRoot } = ctx;
  pruneStaleChildren(ctx, join(claudeRoot, "agents"), /^claude\/(agents|scopes\/[^/]+\/agents)$/, "stale managed Claude agent", ".md");
  for (const scope of ctx.scopes) {
    const agentsDir = join(repoDir, "claude/scopes", scope, "agents");
    for (const name of repoFiles(agentsDir, ".md")) {
      ensureLink(ctx, join(agentsDir, name), join(claudeRoot, "agents", name), `Claude agent ${name}`);
    }
    const scriptsDir = join(repoDir, "claude/scopes", scope, "scripts");
    for (const name of globEntries(scriptsDir)) {
      ensureLink(ctx, join(scriptsDir, name), join(claudeRoot, "scripts", name), `Claude script ${name}`);
    }
  }
  pruneStaleChildren(ctx, join(claudeRoot, "scripts"), /^claude\/scopes\/[^/]+\/scripts$/, "stale Claude script");
}

function reconcileClaude(ctx) {
  const { repoDir, claudeRoot } = ctx;
  ctx.emit("SECTION", "Claude");
  ensureLink(ctx, join(repoDir, "claude/CLAUDE.md"), join(claudeRoot, "CLAUDE.md"), "Claude CLAUDE.md");
  ensureLink(ctx, join(repoDir, "workflow"), join(claudeRoot, "workflow"), "Claude workflow");
  for (const template of ["PLAN_TEMPLATE.md", "PLAN_TEMPLATE_FULL.md"]) {
    ensureLink(ctx, join(repoDir, template), join(claudeRoot, template), `Claude ${template}`);
  }
  for (const link of links(join(claudeRoot, "commands"))) {
    if (inRepo(ctx, linkTarget(link))) pruneLink(ctx, link, `retired Claude command ${basename(link)}`);
  }
  reconcileClaudeHooks(ctx);
  ensureLink(ctx, join(repoDir, "claude/statusline-command.sh"), join(claudeRoot, "statusline-command.sh"), "Claude statusline command");
  ensureLink(
    ctx,
    join(repoDir, "claude/settings.workflow-hooks.json"),
    join(claudeRoot, "settings.workflow-hooks.json"),
    "Claude workflow hooks fragment",
  );
  reconcileClaudeScopes(ctx);
  ensureLink(ctx, join(repoDir, "workflow/review-rubric.md"), join(claudeRoot, "review-rubric.md"), "Claude review-rubric.md");
}

export function reconcile(options, emit) {
  const ctx = { ...options, repoReal: realpath(options.repoDir), emit, counts: { issues: 0, fixed: 0, unresolved: 0 } };
  if (!ctx.claudeOnly) reconcilePi(ctx);
  reconcileSkills(ctx);
  reconcileClaude(ctx);
  return ctx.counts;
}

export function seedPiSettings({ homeDir, repoDir, apply }, emit) {
  const local = join(homeDir, ".pi/agent/settings.json");
  const tracked = join(repoDir, "pi/agent/settings.json");
  if (lstatOrNull(local)?.isSymbolicLink()) {
    if (!apply) {
      emit("WOULD_MIGRATE", "Pi agent settings symlink to local file");
      return false;
    }
    const dangling = !existsSync(local);
    replaceFile(local, readFileSync(dangling ? tracked : local), 0o600);
    emit(dangling ? "COPY" : "MIGRATE", dangling ? "Pi agent settings bootstrap after dangling symlink" : "Pi agent settings symlink to local file");
  }
  if (lstatOrNull(local)?.isFile()) return true;
  if (!apply) {
    emit("WOULD_COPY", "Pi agent settings bootstrap");
    return false;
  }
  mkdirSync(dirname(local), { recursive: true });
  replaceFile(local, readFileSync(tracked), statSync(tracked).mode & 0o7777);
  emit("COPY", "Pi agent settings bootstrap");
  return true;
}

function main([command, repoDir, homeDir]) {
  if (command === "claude-dir") {
    process.stdout.write(`${claudeEffectiveDir()}\n`);
  } else if (command === "skill-names" && repoDir && homeDir) {
    const records = skillRecords(repoDir) ?? [];
    const scopes = activeScopes(homeDir);
    const expected = records.filter((record) => surfaceExpected(CLAUDE_SKILLS, record, scopes) && !isShadowed(record.name, scopes));
    process.stdout.write(JSON.stringify({ known: records.map((record) => record.name), expected: expected.map((record) => record.name) }));
  } else {
    process.stderr.write("usage: surfaces.mjs claude-dir | skill-names <repo-dir> <home-dir>\n");
    process.exitCode = 2;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(realpath(process.argv[1])).href) {
  try {
    main(process.argv.slice(2));
  } catch (error) {
    process.stderr.write(`surfaces: ${error.message}\n`);
    process.exitCode = 2;
  }
}
