import { expect, test } from "bun:test";
import { spawn, type ChildProcess } from "node:child_process";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { request } from "../src/cli.ts";
import type { Run } from "../src/runs-doc.ts";
import { localRepo, until } from "./helpers.ts";
import { openNodeSqliteStorage } from "@earendil-works/pi-durable/storage/sqlite/node";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";

const exited = (pid: number) => { try { process.kill(pid, 0); return false; } catch { return true; } };
test("SIGKILL reuses task-owned child and submission, returns result once and reaps stdio server", async () => {
  const root = await mkdtemp(join(tmpdir(), "durable-subagent-kill-"));
  const source = await localRepo(root);
  const state = join(root, "state");
  let daemon: ChildProcess | undefined;
  let serverPid = 0;
  const start = async (stage: string) => {
    daemon = spawn("node", [join(import.meta.dirname, "fixtures/subagent-crash-daemon.ts"), root, source, stage], { stdio: ["ignore", "ignore", "ignore"] });
    await until(async () => (await readFile(join(root, "ready"), "utf8").catch(() => "")) === String(daemon!.pid), 15_000);
    serverPid = Number(await readFile(join(root, "mcp-pid"), "utf8"));
  };
  const stop = async (signal: NodeJS.Signals) => {
    if (!daemon) return;
    const target = daemon;
    const ended = new Promise<void>((resolve) => target.once("exit", () => resolve()));
    target.kill(signal); await ended; daemon = undefined;
    await until(async () => exited(serverPid), 5000);
    serverPid = 0;
  };
  try {
    await start("initial");
    const run = await request(state, { op: "run", repo: "Tonours/fixture", prompt: "crash owned child", requestId: "owned-once" }) as Run;
    await until(async () => (await readFile(join(root, "phase"), "utf8").catch(() => "")) === String(daemon!.pid), 15_000);
    expect(await readFile(join(run.worktree, "effects"), "utf8")).toBe("effect\n");
    await stop("SIGKILL");
    await start("recover");
    await until(async () => (await request(state, { op: "show", id: run.id }) as { run: Run }).run.status === "done", 15_000);
    await stop("SIGTERM");
    const storage = await openNodeSqliteStorage(join(state, "store.sqlite"));
    try {
      const owned = (await storage.scanConversations({ ownerConversationId: run.conversationId }, 100, undefined, context)).items;
      expect(owned).toHaveLength(1);
      const inputs = (await storage.scanSubmissions({ conversationId: owned[0]!.id }, 100, undefined, context)).items;
      expect(inputs).toHaveLength(1);
      const entries = (await storage.scanEntries({ conversationId: run.conversationId }, 100, undefined, context)).items;
      const results = entries.flatMap((entry) => (entry.model ?? []).filter((message) => message.role === "toolResult" && message.toolName === "worker"));
      expect(results).toHaveLength(1);
      expect(JSON.stringify(results)).toContain("recovered child answer");
      expect(await readFile(join(run.worktree, "effects"), "utf8")).toBe("effect\n");
      const tasks = (await storage.scanTasks({}, 100, undefined, context)).items;
      expect(tasks.filter((task) => task.state.status !== "terminal")).toHaveLength(0);
    } finally { await storage.close(context); }
  } finally {
    if (daemon) { try { await stop("SIGKILL"); } catch { daemon?.kill("SIGKILL"); } }
    if (serverPid && !exited(serverPid)) process.kill(serverPid, "SIGKILL");
    await rm(root, { recursive: true, force: true });
  }
}, 40_000);
