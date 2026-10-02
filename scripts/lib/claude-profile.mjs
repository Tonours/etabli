import {
  existsSync,
  readFileSync,
  statSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import {
  projectVaultRoots,
  resolveObvaultRoot,
} from "../../workflow/runtime/obvault-topic-resolver.mjs";

export function loadScope(home) {
  try {
    const value = readFileSync(join(home, ".etabli-scope"), "utf8").trim();
    return value === "work" ? "work" : "personal";
  } catch {
    return "personal";
  }
}
export const leanProfilePath = (root) =>
  join(root, "claude/profiles/lean.settings.json");
export const leanMcpTemplatePath = (root) =>
  join(root, "claude/profiles/lean.mcp.template.json");

function substitute(value, variables) {
  if (typeof value === "string")
    return value.replace(
      /\$\{(VAULT_ROOT|VAULT_NAME)\}/g,
      (_, key) => variables[key],
    );
  if (Array.isArray(value))
    return value.map((item) => substitute(item, variables));
  if (value && typeof value === "object")
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [
        substitute(key, variables),
        substitute(item, variables),
      ]),
    );
  return value;
}

export function renderMcpConfig({ repoRoot, home, cwd = process.cwd() }) {
  let template;
  try {
    template = JSON.parse(readFileSync(leanMcpTemplatePath(repoRoot), "utf8"));
    if (
      !template.mcpServers ||
      typeof template.mcpServers !== "object" ||
      Array.isArray(template.mcpServers)
    )
      throw new Error("mcpServers must be an object");
  } catch (error) {
    throw new Error(
      `unreadable lean MCP template: ${error.message} — restore claude/profiles/lean.mcp.template.json`,
    );
  }
  const roots = projectVaultRoots({ cwd, home });
  const root = resolveObvaultRoot(roots);
  const vault =
    resolve(roots[0]) === resolve(home, "work/brain") ? "brain" : "obvault";
  let available = false;
  try {
    available = Boolean(
      root && statSync(join(root, "_meta/mcp/server.mjs")).isFile(),
    );
  } catch {}
  const servers = available
    ? substitute(template.mcpServers, { VAULT_ROOT: root, VAULT_NAME: vault })
    : {};
  const directory = mkdtempSync(join(tmpdir(), "claude-lean-mcp-"));
  const path = join(directory, "config.json");
  const cleanup = () => rmSync(directory, { recursive: true, force: true });
  try {
    writeFileSync(
      path,
      JSON.stringify({ mcpServers: servers }, null, 2) + "\n",
      { mode: 0o600 },
    );
  } catch (error) {
    cleanup();
    throw error;
  }
  return {
    path,
    cleanup,
    vault,
    root,
    skipped: available ? [] : [`alambic-${vault}`],
  };
}

export function buildLeanLaunch({
  repoRoot,
  home,
  cwd = process.cwd(),
  strictMcp = true,
  extraArgs = [],
}) {
  const profile = leanProfilePath(repoRoot);
  if (!existsSync(profile))
    throw new Error(
      `lean profile missing: ${profile} — restore claude/profiles/lean.settings.json`,
    );
  const rendered = renderMcpConfig({ repoRoot, home, cwd });
  const args = ["--settings", profile];
  if (strictMcp) args.push("--strict-mcp-config");
  args.push("--mcp-config", rendered.path, ...extraArgs);
  return {
    args,
    mcpPath: rendered.path,
    scope: loadScope(home),
    vault: rendered.vault,
    skippedServers: rendered.skipped,
    cleanup: rendered.cleanup,
  };
}
