import type { ExtensionAPI, ToolCallEvent } from "@mariozechner/pi-coding-agent";
import { isToolCallEventType } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { homedir } from "node:os";
import { execSync } from "node:child_process";

function getHomeDir(): string {
  return process.env.HOME || process.env.USERPROFILE || homedir();
}

export interface Snapshot {
  id: string;
  timestamp: string;
  cwd: string;
  reason: string;
  files: string[];
  gitSha?: string;
}

interface SnapshotIndex {
  snapshots: Snapshot[];
  maxSnapshots: number;
}

const SNAPSHOTS_DIR = join(getHomeDir(), ".pi", "snapshots");
const INDEX_FILE = join(SNAPSHOTS_DIR, "index.json");
const MAX_SNAPSHOTS = 10;

function ensureSnapshotsDir(): void {
  mkdirSync(SNAPSHOTS_DIR, { recursive: true });
}

export function readIndex(): SnapshotIndex {
  if (!existsSync(INDEX_FILE)) {
    return { snapshots: [], maxSnapshots: MAX_SNAPSHOTS };
  }

  try {
    return JSON.parse(readFileSync(INDEX_FILE, "utf-8")) as SnapshotIndex;
  } catch {
    return { snapshots: [], maxSnapshots: MAX_SNAPSHOTS };
  }
}

function writeIndex(index: SnapshotIndex): void {
  writeFileSync(INDEX_FILE, JSON.stringify(index, null, 2), "utf-8");
}

function getGitSha(cwd: string): string | undefined {
  try {
    return execSync("git rev-parse --short HEAD 2>/dev/null", { cwd, encoding: "utf-8" }).trim();
  } catch {
    return undefined;
  }
}

export function createSnapshot(cwd: string, reason: string, files: string[]): Snapshot {
  ensureSnapshotsDir();
  const id = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  const snapshotDir = join(SNAPSHOTS_DIR, id);
  mkdirSync(snapshotDir, { recursive: true });

  const copiedFiles: string[] = [];
  for (const file of files) {
    const sourcePath = join(cwd, file);
    if (!existsSync(sourcePath)) continue;

    const destPath = join(snapshotDir, file);
    mkdirSync(dirname(destPath), { recursive: true });
    cpSync(sourcePath, destPath, { recursive: true });
    copiedFiles.push(file);
  }

  const snapshot: Snapshot = {
    id,
    timestamp: new Date().toISOString(),
    cwd,
    reason,
    files: copiedFiles,
    gitSha: getGitSha(cwd),
  };

  writeFileSync(join(snapshotDir, "meta.json"), JSON.stringify(snapshot, null, 2), "utf-8");

  const index = readIndex();
  index.snapshots.push(snapshot);
  while (index.snapshots.length > index.maxSnapshots) {
    const old = index.snapshots.shift();
    if (old) rmSync(join(SNAPSHOTS_DIR, old.id), { recursive: true, force: true });
  }
  writeIndex(index);

  return snapshot;
}

export function isRiskyOperation(event: ToolCallEvent): boolean {
  if (isToolCallEventType("bash", event)) {
    const riskyPatterns = [
      /rm\s+-rf/,
      /find\b.*\b-delete\b/,
      /(^|[^>])>(?!>)\s*\S+/,
      /git\s+clean\b.*-f/,
      /git\s+reset\b.*--hard/,
    ];
    return riskyPatterns.some((pattern) => pattern.test(event.input.command));
  }

  if (isToolCallEventType("write", event)) {
    return existsSync(event.input.path);
  }

  if (isToolCallEventType("edit", event)) {
    return event.input.newText.length > 1000 || event.input.oldText.length > 1000;
  }

  return false;
}

export function getFilesToSnapshot(cwd: string, event: ToolCallEvent): string[] {
  const files = new Set<string>();

  if (isToolCallEventType("bash", event)) {
    const matches = event.input.command.matchAll(/\s([\w./-]+\.(?:ts|js|tsx|jsx|lua|md|json|yml|yaml))\s?/g);
    for (const match of matches) {
      files.add(match[1]);
    }
  }

  if (isToolCallEventType("write", event) || isToolCallEventType("read", event)) {
    files.add(event.input.path);
  }

  if (isToolCallEventType("edit", event)) {
    files.add(event.input.path);
  }

  if (files.size === 0 && existsSync(join(cwd, "PLAN.md"))) {
    files.add("PLAN.md");
  }

  return [...files];
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (!isRiskyOperation(event)) {
      return { block: false };
    }

    const files = getFilesToSnapshot(ctx.cwd, event);
    if (files.length === 0) {
      return { block: false };
    }

    const snapshot = createSnapshot(ctx.cwd, `Pre-${event.toolName}`, files);
    ctx.ui.notify(`Snapshot created: ${snapshot.id.slice(0, 8)} (${files.length} files)`, "info");
    return { block: false };
  });

  pi.registerCommand("snapshots", {
    description: "List available snapshots for current project",
    handler: async (_args, ctx) => {
      const projectSnapshots = readIndex().snapshots.filter((snapshot) => snapshot.cwd === ctx.cwd);
      if (projectSnapshots.length === 0) {
        ctx.ui.notify("No snapshots for this project", "info");
        return;
      }

      const lines = [`Snapshots (${projectSnapshots.length})`, ""];
      for (const snapshot of projectSnapshots) {
        const ageMinutes = Math.round((Date.now() - new Date(snapshot.timestamp).getTime()) / 60000);
        lines.push(`${snapshot.id.slice(0, 8)} - ${ageMinutes}m ago`);
        lines.push(`  Reason: ${snapshot.reason}`);
        lines.push(`  Files: ${snapshot.files.length}`);
        if (snapshot.gitSha) lines.push(`  Git: ${snapshot.gitSha}`);
        lines.push("");
      }

      pi.sendMessage({ customType: "snapshot-list", content: lines.join("\n"), display: true });
      ctx.ui.notify(`${projectSnapshots.length} snapshot(s) available`, "info");
    },
  });

  pi.registerCommand("snapshot-create", {
    description: "Create manual snapshot of current state",
    handler: async (args, ctx) => {
      const reason = args.trim() || "Manual snapshot";
      let files: string[] = [];

      try {
        const gitFiles = execSync("git ls-files", { cwd: ctx.cwd, encoding: "utf-8" });
        files = gitFiles.split("\n").filter((file) => file.trim());
      } catch {
        files = existsSync(join(ctx.cwd, "PLAN.md")) ? ["PLAN.md"] : [];
      }

      const snapshot = createSnapshot(ctx.cwd, reason, files);
      ctx.ui.notify(`Snapshot created: ${snapshot.id.slice(0, 8)} (${files.length} files)`, "info");
    },
  });

  pi.registerTool({
    name: "snapshot_create",
    label: "Snapshot Create",
    description: "Create a manual snapshot of specified files.",
    parameters: Type.Object({
      reason: Type.String(),
      files: Type.Optional(Type.Array(Type.String())),
    }),
    async execute(_toolCallId, args, _signal, _onUpdate, ctx) {
      const input = args as { reason: string; files?: string[] };
      let files = input.files ?? [];

      if (files.length === 0) {
        try {
          const modified = execSync("git diff --name-only", { cwd: ctx.cwd, encoding: "utf-8" });
          files = modified.split("\n").filter((file) => file.trim());
        } catch {
          files = existsSync(join(ctx.cwd, "PLAN.md")) ? ["PLAN.md"] : [];
        }
      }

      const snapshot = createSnapshot(ctx.cwd, input.reason, files);
      return {
        content: [{ type: "text" as const, text: `Snapshot created: ${snapshot.id}\nFiles: ${files.length}\nReason: ${input.reason}` }],
        details: {
          snapshotId: snapshot.id,
          fileCount: files.length,
          timestamp: snapshot.timestamp,
        },
      };
    },
  });
}
