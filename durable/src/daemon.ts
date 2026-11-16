import { chmod, mkdir, readFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { hostname, homedir } from "node:os";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { createModels, type Models } from "@earendil-works/pi-ai";
import { zaiProvider } from "@earendil-works/pi-ai/providers/zai";
import { openaiCodexProvider } from "@earendil-works/pi-ai/providers/openai-codex";
import { Harness, createRegistry, type ModelRef, type ConversationRetryPolicy } from "@earendil-works/pi-durable";
import { CodingTools } from "@earendil-works/pi-durable/tools";
import { NodeExecutionEnv } from "@earendil-works/pi-durable/env/node";
import { openNodeSqliteStorage } from "@earendil-works/pi-durable/storage/sqlite/node";
import { SharedCredentialStore } from "./credentials.ts";
import { createGuards, configureGuard } from "./guards.ts";
import { OwnerPolicy } from "./policy.ts";
import { Repositories } from "./repositories.ts";
import { Runs } from "./runs.ts";
import { Schedules } from "./schedule.ts";
import { Ci } from "./ci.ts";
import { writerLock } from "./lock.ts";
import { authorFamilies, createPlanExtension, phaseModel, type ModelRole } from "./plan-doc.ts";
import { createReviewExtension } from "./review.ts";
import { createPublishExtension, type Command } from "./publish.ts";
import { createSubagentsExtension, type SubagentRole } from "./subagents.ts";
import { openMcp, mcpConfig } from "./mcp.ts";
import { Push } from "./push.ts";
import type { runCliReview } from "./review-cli.ts";

import { serve, serveRemote, type ApiServer } from "./api.ts";
import { apiConfig, loadToken } from "./auth.ts";
export { dispatch, serve } from "./api.ts";

export const defaultState = () => join(homedir(), ".local/state/etabli-durable");
export const defaultConfig = () => join(homedir(), ".config/etabli/durable.json");
export const checkout = resolve(import.meta.dirname, "../..");

export async function defaultModel(): Promise<ModelRef> {
  return phaseModel(checkout, "implementer");
}

export async function openCore(options: { state: string; policy: OwnerPolicy; models: Models; model?: () => Promise<ModelRef>; workflow?: boolean; subagentModel?: (role: SubagentRole) => Promise<ModelRef>; mcpServers?: Record<string, unknown>; phaseModel?: (role: ModelRole) => Promise<ModelRef>; reviewCli?: typeof runCliReview; publishCommand?: Command; ciCommand?: Command; repositories?: Repositories; now?: () => number; wallMs?: number; maxTurns?: number; notifyArgv?: readonly string[]; restartLimit?: number; retry?: Partial<ConversationRetryPolicy>; fatal?: () => void; web?: { origin: string; identities: readonly string[] } }) {
  process.umask(0o077);
  await mkdir(options.state, { recursive: true, mode: 0o700 });
  await chmod(options.state, 0o700);
  const unlock = await writerLock(join(options.state, "daemon.lock"));
  let opened: Harness | undefined;
  let mcp: Awaited<ReturnType<typeof openMcp>> | undefined;
  let closePush: (() => Promise<void>) | undefined;
  try {
    const storage = await openNodeSqliteStorage(join(options.state, "store.sqlite"));
    await chmod(join(options.state, "store.sqlite"), 0o600);
    const registry = createRegistry();
    const guard = createGuards(checkout, options.policy);
    registry.install(CodingTools);
    registry.install(guard);
    mcp = await openMcp(options.mcpServers);
    const extensions = [createSubagentsExtension(checkout, guard, options.subagentModel), mcp.extension];
    for (const extension of extensions) registry.install(extension);
    const host = { async conversation(id: Parameters<Harness["conversation"]>[0], ctx: Parameters<Harness["conversation"]>[1]) { if (!opened) throw new Error("Harness is not ready"); return opened.conversation(id, ctx); } };
    const workflow = options.workflow ? [createPlanExtension(checkout, async (id, ctx) => { const conversation = await host.conversation(id, ctx); if (!conversation) throw new Error("Author conversation missing"); return authorFamilies(checkout, conversation, ctx); }, options.phaseModel), createReviewExtension(checkout, host, options.reviewCli), createPublishExtension(checkout, options.policy, host, options.publishCommand)] : [];
    for (const extension of workflow) registry.install(extension);
    const harness = await Harness.open(storage, {
      models: options.models,
      registry,
      settings: { extensions: [CodingTools, guard, ...workflow, ...extensions], toolExecution: "sequential", restartLimit: options.restartLimit ?? 5, retry: options.retry, compaction: { enabled: false } },
      env: ({ cwd }) => cwd ? new NodeExecutionEnv({ cwd, shellPath: "/bin/bash" }) : undefined,
      conversationCreated: (tx, conversation) => configureGuard(tx, conversation, guard),
      now: options.now,
      onReport: (report) => { if (report.kind === "storage_failed") options.fatal?.(); },
    }, context);
    opened = harness;
    const push = options.web ? await Push.open(harness, options.state, options.web.origin, options.web.identities) : undefined;
    closePush = async () => { await push?.close(); };
    const runs = new Runs({ ...options, pushNotify: push ? () => push.notify() : undefined, workflow: options.workflow ? checkout : undefined, guard, harness, repositories: options.repositories ?? new Repositories(options.state, options.policy), model: options.model ?? defaultModel });
    closePush = async () => { await push?.close(); await runs.drainNotifications(); };
    const schedules = new Schedules(runs);
    const ci = new Ci(runs, options.ciCommand);
    let closing = false;
    let triggers: Promise<void> | undefined;
    const tickTriggers = () => {
      if (closing) return Promise.resolve();
      triggers ??= (async () => { await schedules.tick(); await ci.tick(); })().catch(() => { console.error("Trigger tick unavailable; retrying"); }).finally(() => { triggers = undefined; });
      return triggers;
    };
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
      await closePush();
      await harness.close(context);
      throw error;
    }
    return { harness, runs, push, schedules, ci, tickTriggers, close: async () => { closing = true; await triggers; clearInterval(limits); await enforcing; await runs.drainTicks(); await runs.drainStops(); await closePush!(); await harness.close(context); await mcp?.close(); await unlock(); } };
  } catch (error) {
    await closePush?.().catch(() => undefined);
    await opened?.close(context).catch(() => undefined);
    await mcp?.close();
    await unlock();
    throw error;
  }
}

export type Core = Awaited<ReturnType<typeof openCore>>;

export function daemonConfig(raw: unknown) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) throw new Error("Invalid durable configuration");
  const config = raw as Record<string, unknown>;
  if ("webOrigin" in config || "web" in config) throw new Error("Configure webOrigin inside api, never at top level");
  const notifyArgv = config.notifyArgv ?? [];
  if (!Array.isArray(notifyArgv) || notifyArgv.some((part) => typeof part !== "string") || notifyArgv.length > 32) throw new Error("notifyArgv must be an argument array");
  const maxTurns = config.maxTurns ?? 64;
  const wallMs = config.wallMs ?? 14_400_000;
  const restartLimit = config.restartLimit ?? 5;
  if (typeof maxTurns !== "number" || !Number.isSafeInteger(maxTurns) || maxTurns < 1 || maxTurns > 256 || typeof wallMs !== "number" || !Number.isSafeInteger(wallMs) || wallMs < 1 || wallMs > 14_400_000) throw new Error("Run limits must be positive and within 256 turns / four hours");
  if (typeof restartLimit !== "number" || !Number.isSafeInteger(restartLimit) || restartLimit < 1 || restartLimit > 32) throw new Error("restartLimit must be an integer from 1 to 32");
  return { notifyArgv, maxTurns, wallMs, restartLimit, mcpServers: mcpConfig(config.mcpServers), api: apiConfig(config.api) };
}

export async function daemon(state = defaultState(), configPath = defaultConfig()): Promise<void> {
  if (Number(process.versions.node.split(".")[0]) !== 26) throw new Error("Use Node 26 for the durable daemon");
  const policy = await OwnerPolicy.load(hostname(), join(homedir(), ".etabli-scope"), join(homedir(), ".config/etabli/work-orgs"));
  const config = daemonConfig(JSON.parse(await readFile(configPath, "utf8").catch((error: NodeJS.ErrnoException) => { if (error.code === "ENOENT") return "{}"; throw error; })));
  const models = createModels({ credentials: new SharedCredentialStore(join(homedir(), ".pi/agent/auth.json")) });
  models.setProvider(zaiProvider());
  models.setProvider(openaiCodexProvider());
  const core = await openCore({ state, policy, models, workflow: true, ...config, web: config.api?.webOrigin ? { origin: config.api.webOrigin, identities: config.api.identities } : undefined, fatal: () => process.exit(1) });
  const servers: ApiServer[] = [];
  try {
    const token = await loadToken(join(state, "api.token"));
    servers.push(await serve(core, state));
    if (config.api) servers.push(await serveRemote(core, config.api.port, token, config.api.identities, config.api.webOrigin ? { origin: config.api.webOrigin, push: core.push } : undefined));
  } catch (error) {
    await Promise.all(servers.map((server) => server.shutdown()));
    await core.close();
    throw error;
  }
  let ticking = false;
  const timer = setInterval(() => {
    if (ticking) return;
    ticking = true;
    void core.runs.tick().catch(() => process.exit(1)).finally(() => { ticking = false; });
  }, 250);
  const triggerTimer = setInterval(() => { void core.tickTriggers(); }, 250);
  const stop = async () => {
    clearInterval(triggerTimer);
    clearInterval(timer);
    await Promise.all(servers.map((server) => server.shutdown()));
    await core.close();
    process.exit(0);
  };
  process.once("SIGTERM", () => void stop());
  process.once("SIGINT", () => void stop());
}
