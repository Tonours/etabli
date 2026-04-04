import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";

function getHomeDir(): string {
  return process.env.HOME || process.env.USERPROFILE || homedir();
}

export interface ProjectEntry {
  path: string;
  name: string;
  lastVisited: string;
  visitCount: number;
  favorite: boolean;
}

interface ProjectState {
  projects: ProjectEntry[];
  lastProject?: string;
}

const PROJECTS_FILE = join(getHomeDir(), ".pi", "projects.json");

export function readProjects(): ProjectState {
  if (!existsSync(PROJECTS_FILE)) {
    return { projects: [] };
  }

  try {
    return JSON.parse(readFileSync(PROJECTS_FILE, "utf-8")) as ProjectState;
  } catch {
    return { projects: [] };
  }
}

function writeProjects(state: ProjectState): void {
  mkdirSync(join(getHomeDir(), ".pi"), { recursive: true });
  writeFileSync(PROJECTS_FILE, JSON.stringify(state, null, 2), "utf-8");
}

export function addProject(path: string, name?: string): void {
  const state = readProjects();
  const resolvedPath = resolve(path);
  const existing = state.projects.find((project) => project.path === resolvedPath);

  if (existing) {
    existing.lastVisited = new Date().toISOString();
    existing.visitCount += 1;
    state.lastProject = resolvedPath;
    writeProjects(state);
    return;
  }

  state.projects.push({
    path: resolvedPath,
    name: name || resolvedPath.split("/").pop() || "unnamed",
    lastVisited: new Date().toISOString(),
    visitCount: 1,
    favorite: false,
  });
  state.lastProject = resolvedPath;
  writeProjects(state);
}

export function getRecentProjects(limit = 5): ProjectEntry[] {
  return readProjects()
    .projects.filter((project) => !project.favorite)
    .sort((a, b) => new Date(b.lastVisited).getTime() - new Date(a.lastVisited).getTime())
    .slice(0, limit);
}

export function getFavoriteProjects(): ProjectEntry[] {
  return readProjects()
    .projects.filter((project) => project.favorite)
    .sort((a, b) => a.name.localeCompare(b.name));
}

export function toggleFavorite(path: string): boolean {
  const state = readProjects();
  const project = state.projects.find((entry) => entry.path === resolve(path));
  if (!project) return false;

  project.favorite = !project.favorite;
  writeProjects(state);
  return project.favorite;
}

function findProject(query: string): ProjectEntry | undefined {
  const favorites = getFavoriteProjects();
  const recent = getRecentProjects(10);
  const all = [...favorites, ...recent];

  const number = Number.parseInt(query, 10);
  if (!Number.isNaN(number) && number > 0 && number <= recent.length) {
    return recent[number - 1];
  }

  return all.find(
    (project) =>
      project.name.toLowerCase() === query.toLowerCase() ||
      project.name.toLowerCase().includes(query.toLowerCase()) ||
      project.path.includes(query),
  );
}

function getOpsStatusPath(cwd: string): string {
  const sanitized = cwd.replace(/[^a-zA-Z0-9._-]+/g, "_");
  return join(getHomeDir(), ".pi", "status", `${sanitized}.ops.json`);
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    addProject(ctx.cwd);
  });

  pi.registerCommand("projects", {
    description: "List recent and favorite projects",
    handler: async (_args, ctx) => {
      const favorites = getFavoriteProjects();
      const recent = getRecentProjects(5);
      const lines = ["Projects", ""];

      if (favorites.length > 0) {
        lines.push("Favorites:");
        for (const project of favorites) {
          lines.push(`  * ${project.name}: ${project.path}`);
        }
        lines.push("");
      }

      if (recent.length > 0) {
        lines.push("Recent:");
        for (const [index, project] of recent.entries()) {
          lines.push(`  ${index + 1}. ${project.name}: ${project.path} (${project.visitCount} visits)`);
        }
      }

      lines.push("", "Use /switch <name|number|path> to change project");
      pi.sendMessage({ customType: "project-list", content: lines.join("\n"), display: true });
      ctx.ui.notify(`${favorites.length} favorites, ${recent.length} recent`, "info");
    },
  });

  pi.registerCommand("switch", {
    description: "Switch to another project",
    handler: async (args, ctx) => {
      const query = args.trim();
      if (!query) {
        ctx.ui.notify("Usage: /switch <name|number|path>", "warning");
        return;
      }

      const target = findProject(query);
      if (!target) {
        ctx.ui.notify(`Project \"${query}\" not found. Use /projects to list choices.`, "error");
        return;
      }

      const lines = [`Switching to: ${target.name}`, `Path: ${target.path}`, "", `cd ${target.path}`];
      if (existsSync(getOpsStatusPath(target.path))) {
        lines.push("# OPS snapshot found - previous state is available");
      }

      pi.sendMessage({ customType: "project-switch", content: lines.join("\n"), display: true });
      ctx.ui.notify(`Ready to switch to ${target.name}`, "info");
    },
  });

  pi.registerCommand("favorite", {
    description: "Toggle favorite status for current project",
    handler: async (_args, ctx) => {
      const favorite = toggleFavorite(ctx.cwd);
      const project = readProjects().projects.find((entry) => entry.path === resolve(ctx.cwd));
      if (!project) return;

      ctx.ui.notify(
        `${project.name} ${favorite ? "added to" : "removed from"} favorites`,
        "info",
      );
    },
  });

  pi.registerTool({
    name: "project_switch",
    label: "Project Switch",
    description: "Switch to a different project or list available ones.",
    parameters: Type.Object({ query: Type.String() }),
    async execute(
      _toolCallId,
      args,
    ): Promise<{
      content: [{ type: "text"; text: string }];
      details: {
        found: boolean;
        available: Array<{ name: string; path: string }>;
        project: ProjectEntry | null;
        instructions: string[];
      };
    }> {
      const query = (args as { query: string }).query;
      const target = findProject(query);
      if (!target) {
        const available = [...getFavoriteProjects(), ...getRecentProjects(10)].map((project) => ({
          name: project.name,
          path: project.path,
        }));
        return {
          content: [{ type: "text" as const, text: `Project \"${query}\" not found.` }],
          details: { found: false, available, project: null, instructions: [] },
        };
      }

      return {
        content: [{ type: "text" as const, text: `Switch to ${target.name}:\ncd ${target.path}` }],
        details: {
          found: true,
          available: [],
          project: target,
          instructions: [`cd ${target.path}`],
        },
      };
    },
  });
}
