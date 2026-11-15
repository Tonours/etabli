import { chmod, mkdir, readFile, unlink } from "node:fs/promises";
import { join, resolve } from "node:path";
import { hostname, homedir } from "node:os";
import { createServer, type Server } from "node:net";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { createModels, type Models } from "@earendil-works/pi-ai";
import { zaiProvider } from "@earendil-works/pi-ai/providers/zai";
import { openaiCodexProvider } from "@earendil-works/pi-ai/providers/openai-codex";
import { Harness, AgentDoc, LiveDoc, createRegistry, type ModelRef, type ConversationRetryPolicy } from "@earendil-works/pi-durable";
import { CodingTools } from "@earendil-works/pi-durable/tools";
import { NodeExecutionEnv } from "@earendil-works/pi-durable/env/node";
import { openNodeSqliteStorage } from "@earendil-works/pi-durable/storage/sqlite/node";
import { SharedCredentialStore } from "./credentials.ts";
import { createGuards, configureGuard } from "./guards.ts";
import { OwnerPolicy } from "./policy.ts";
import { Repositories } from "./repositories.ts";
import { Runs } from "./runs.ts";
import { writerLock } from "./lock.ts";
import { authorFamilies, createPlanExtension, EtabliPlanDoc, phaseModel, type ModelRole } from "./plan-doc.ts";
import { createReviewExtension } from "./review.ts";
import { createPublishExtension, type Command } from "./publish.ts";
import type { runCliReview } from "./review-cli.ts";

export const defaultState = () => join(homedir(), ".local/state/etabli-durable");
export const defaultConfig = () => join(homedir(), ".config/etabli/durable.json");
export const checkout = resolve(import.meta.dirname, "../..");

export async function defaultModel(): Promise<ModelRef> {
  return phaseModel(checkout, "implementer");
}

export async function openCore(options: { state: string; policy: OwnerPolicy; models: Models; model?: () => Promise<ModelRef>; workflow?: boolean; phaseModel?: (role: ModelRole) => Promise<ModelRef>; reviewCli?: typeof runCliReview; publishCommand?: Command; repositories?: Repositories; now?: () => number; wallMs?: number; maxTurns?: number; notifyArgv?: readonly string[]; restartLimit?: number; retry?: Partial<ConversationRetryPolicy>; fatal?: () => void }) {
  process.umask(0o077);
  await mkdir(options.state, { recursive: true, mode: 0o700 });
  await chmod(options.state, 0o700);
  const unlock = await writerLock(join(options.state, "daemon.lock"));
  let opened: Harness | undefined;
  try {
    const storage = await openNodeSqliteStorage(join(options.state, "store.sqlite"));
    await chmod(join(options.state, "store.sqlite"), 0o600);
    const registry = createRegistry();
    const guard = createGuards(checkout, options.policy);
    registry.install(CodingTools);
    registry.install(guard);
    const host = { async conversation(id: Parameters<Harness["conversation"]>[0], ctx: Parameters<Harness["conversation"]>[1]) { if (!opened) throw new Error("Harness is not ready"); return opened.conversation(id, ctx); } };
    const workflow = options.workflow ? [createPlanExtension(checkout, async (id, ctx) => { const conversation = await host.conversation(id, ctx); if (!conversation) throw new Error("Author conversation missing"); return authorFamilies(checkout, conversation, ctx); }, options.phaseModel), createReviewExtension(checkout, host, options.reviewCli), createPublishExtension(checkout, options.policy, host, options.publishCommand)] : [];
    for (const extension of workflow) registry.install(extension);
    const harness = await Harness.open(storage, {
      models: options.models,
      registry,
      settings: { extensions: [CodingTools, guard, ...workflow], toolExecution: "sequential", restartLimit: options.restartLimit ?? 5, retry: options.retry, compaction: { enabled: false } },
      env: ({ cwd }) => cwd ? new NodeExecutionEnv({ cwd, shellPath: "/bin/bash" }) : undefined,
      conversationCreated: (tx, conversation) => configureGuard(tx, conversation, guard),
      now: options.now,
      onReport: (report) => { if (report.kind === "storage_failed") options.fatal?.(); },
    }, context);
    opened = harness;
    const runs = new Runs({ ...options, workflow: options.workflow ? checkout : undefined, guard, harness, repositories: options.repositories ?? new Repositories(options.state, options.policy), model: options.model ?? defaultModel });
    let enforcing: Promise<void> | undefined;
    const limits = setInterval(() => {
      if (enforcing) return;
      enforcing = runs.enforceLimits().catch(() => (options.fatal ?? (() => process.exit(1)))()).finally(() => { enforcing = undefined; });
    }, 100);
    limits.unref();
    try { await runs.reconcile(); } catch (error) {
      clearInterval(limits);
      await enforcing;
      await runs.drainStops();
      await harness.close(context);
      throw error;
    }
    return { harness, runs, close: async () => { clearInterval(limits); await enforcing; await runs.drainStops(); await harness.close(context); await unlock(); } };
  } catch (error) {
    await opened?.close(context).catch(() => undefined);
    await unlock();
    throw error;
  }
}

export type Core = Awaited<ReturnType<typeof openCore>>;

type Request = { op: string; id?: string; repo?: string; prompt?: string; requestId?: string; content?: string; route?: string };

function requiredText(value: unknown): string {
  if (typeof value !== "string") throw new Error("Request fields must be strings");
  return value;
}

export async function dispatch(core: Core, request: Request): Promise<unknown> {
  switch (request.op) {
    case "run": {
      if (request.route !== undefined && !["answer", "plan"].includes(request.route)) throw new Error("Run route must be answer or plan");
      return core.runs.submit(requiredText(request.repo), requiredText(request.prompt), requiredText(request.requestId), request.route as "answer" | "plan" | undefined);
    }
    case "plan": return core.harness.snapshot(EtabliPlanDoc, (await core.runs.show(requiredText(request.id))).conversationId, context);
    case "ls": return core.runs.list();
    case "show": {
      const run = await core.runs.show(requiredText(request.id));
      const conversation = await core.harness.conversation(run.conversationId, context);
      return { run, agent: await core.harness.snapshot(AgentDoc, run.conversationId, context), live: await core.harness.snapshot(LiveDoc, run.conversationId, context), entries: (await conversation?.entries({ order: "ascending" }, 1000, undefined, context))?.items ?? [] };
    }
    case "steer": return core.runs.steer(requiredText(request.id), requiredText(request.content), requiredText(request.requestId));
    case "abort": return { aborted: await core.runs.abort(requiredText(request.id)) };
    default: throw new Error("Unknown operation; use run, ls, show, plan, steer or abort");
  }
}

export async function serve(core: Core, state: string): Promise<Server> {
  const path = join(state, "daemon.sock");
  await unlink(path).catch((error: NodeJS.ErrnoException) => { if (error.code !== "ENOENT") throw error; });
  const server = createServer((socket) => {
    let body = "";
    socket.setEncoding("utf8");
    socket.setTimeout(30_000, () => socket.destroy());
    socket.on("data", (chunk: string) => {
      body += chunk;
      if (body.length > 128_000) { socket.destroy(); return; }
      const end = body.indexOf("\n");
      if (end === -1) return;
      socket.removeAllListeners("data");
      void (async () => {
        try {
          const parsed: unknown = JSON.parse(body.slice(0, end));
          if (!parsed || typeof parsed !== "object" || !("op" in parsed) || typeof parsed.op !== "string") throw new Error("Invalid request");
          const fields = parsed as Record<string, unknown>;
          if (["id", "repo", "prompt", "requestId", "content", "route"].some((key) => key in fields && typeof fields[key] !== "string")) throw new Error("Request fields must be strings");
          const value = await dispatch(core, parsed as Request);
          socket.end(`${JSON.stringify({ ok: true, value })}\n`);
        } catch (error) {
          socket.end(`${JSON.stringify({ ok: false, error: error instanceof Error ? error.message : "Request refused" })}\n`);
        }
      })();
    });
    socket.on("error", () => undefined);
  });
  await new Promise<void>((resolve, reject) => { server.once("error", reject); server.listen(path, resolve); });
  await chmod(path, 0o600);
  return server;
}

export function daemonConfig(raw: unknown) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) throw new Error("Invalid durable configuration");
  const config = raw as Record<string, unknown>;
  const notifyArgv = config.notifyArgv ?? [];
  if (!Array.isArray(notifyArgv) || notifyArgv.some((part) => typeof part !== "string") || notifyArgv.length > 32) throw new Error("notifyArgv must be an argument array");
  const maxTurns = config.maxTurns ?? 64;
  const wallMs = config.wallMs ?? 14_400_000;
  const restartLimit = config.restartLimit ?? 5;
  if (typeof maxTurns !== "number" || !Number.isSafeInteger(maxTurns) || maxTurns < 1 || maxTurns > 256 || typeof wallMs !== "number" || !Number.isSafeInteger(wallMs) || wallMs < 1 || wallMs > 14_400_000) throw new Error("Run limits must be positive and within 256 turns / four hours");
  if (typeof restartLimit !== "number" || !Number.isSafeInteger(restartLimit) || restartLimit < 1 || restartLimit > 32) throw new Error("restartLimit must be an integer from 1 to 32");
  return { notifyArgv, maxTurns, wallMs, restartLimit };
}

export async function daemon(state = defaultState(), configPath = defaultConfig()): Promise<void> {
  if (Number(process.versions.node.split(".")[0]) !== 26) throw new Error("Use Node 26 for the durable daemon");
  const policy = await OwnerPolicy.load(hostname(), join(homedir(), ".etabli-scope"), join(homedir(), ".config/etabli/work-orgs"));
  const config = daemonConfig(JSON.parse(await readFile(configPath, "utf8").catch((error: NodeJS.ErrnoException) => { if (error.code === "ENOENT") return "{}"; throw error; })));
  const models = createModels({ credentials: new SharedCredentialStore(join(homedir(), ".pi/agent/auth.json")) });
  models.setProvider(zaiProvider());
  models.setProvider(openaiCodexProvider());
  const core = await openCore({ state, policy, models, workflow: true, ...config, fatal: () => process.exit(1) });
  const server = await serve(core, state);
  let ticking = false;
  const timer = setInterval(() => {
    if (ticking) return;
    ticking = true;
    void core.runs.tick().catch(() => process.exit(1)).finally(() => { ticking = false; });
  }, 250);
  const stop = async () => {
    clearInterval(timer);
    server.close();
    await core.close();
    process.exit(0);
  };
  process.once("SIGTERM", () => void stop());
  process.once("SIGINT", () => void stop());
}
