import { randomUUID, timingSafeEqual } from 'node:crypto';
import { realpath, readFile, chmod, unlink } from 'node:fs/promises';
import { createServer, type Server, type Socket } from 'node:net';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { setTimeout as delay } from 'node:timers/promises';
import { BACKGROUND_CONTEXT as ctx } from '@earendil-works/chord/context';
import { createModels, type Models } from '@earendil-works/pi-ai/models';
import { fauxAssistantMessage, fauxProvider, fauxToolCall } from '@earendil-works/pi-ai/providers/faux';
import { ModelRuntime } from '@earendil-works/pi-coding-agent';
import { Harness, createRegistry, defineExtension, LiveDoc, CompactionTask, type TaskId, type Storage, type ConversationId } from '@earendil-works/pi-durable';
import { NodeExecutionEnv } from '@earendil-works/pi-durable/env/node';
import { openNodeSqliteStorage } from '@earendil-works/pi-durable/storage/sqlite/node';
import { acquireOwner, capability, privateFile, type Owner } from './owner.ts';
import { State, Role, fingerprint, requireKey, requireModel, type Model, type Json } from './state.ts';
import { definitions, type AgentInput, type WaitInput, type GroupInput } from './tasks.ts';
import { groupDefinition, deadlineDefinition, validateGroup } from './groups.ts';
import { reviewDefinition, validateReview, type ReviewInput } from './reviews.ts';
import type { CommandInput } from './commands.ts';
import { tools } from './tools.ts';
import { policy } from './policy.ts';
import { Ledger } from './ledger.ts';
import { commandEffect, verifyInputs, publication } from './guards.ts';
import { projection, handoffProjection, reconcileWork } from './projection.ts';

export type Options = { dir: string; cwd: string; model?: Model; providers?: string[]; maxRequests?: number; deadline?: number; models?: Models; fixture?: string; resume?: boolean };
export type Request = { command: string; payload?: unknown };

export class Host {
  readonly dir: string;
  readonly cwd: string;
  readonly owner: Owner;
  readonly harness: Harness;
  readonly ledger: Ledger;
  readonly tasks: ReturnType<typeof definitions>;
  readonly GroupTask: ReturnType<typeof groupDefinition>;
  readonly ReviewTask: ReturnType<typeof reviewDefinition>;
  readonly root: Awaited<ReturnType<Harness['root']>>;
  #server: Server | null = null;
  #queue: Promise<unknown> = Promise.resolve();
  #sockets = new Set<Socket>();
  #listeners = new Set<() => void>();
  #closed = false;

  private constructor(dir: string, cwd: string, owner: Owner, harness: Harness, ledger: Ledger, tasks: ReturnType<typeof definitions>, GroupTask: ReturnType<typeof groupDefinition>, ReviewTask: ReturnType<typeof reviewDefinition>, root: Awaited<ReturnType<Harness['root']>>) {
    this.dir = dir; this.cwd = cwd; this.owner = owner; this.harness = harness; this.ledger = ledger; this.tasks = tasks; this.GroupTask = GroupTask; this.ReviewTask = ReviewTask; this.root = root;
    harness.subscribeCommits(() => {
      setImmediate(() => { for (const listener of this.#listeners) listener(); });
    });
  }
  static async open(options: Options) {
    const dir = resolve(options.dir);
    const cwd = await realpath(options.cwd);
    const owner = await acquireOwner(dir);
    let storage: Storage | undefined;
    let opened: Harness | undefined;
    try {
      const database = join(dir, 'session.sqlite');
      try { await privateFile(database); } catch (error) { if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error; }
      storage = await openNodeSqliteStorage(database);
      await chmod(database, 0o600);
      const guarded = new Proxy(storage, { get(target, key) { const value = Reflect.get(target, key); if (typeof value !== 'function') return value; return (...args: unknown[]) => { if (key === 'commit' || key === 'mintId') owner.assert(); return Reflect.apply(value, target, args); }; } }) as Storage;
      let models = options.models;
      if (!models && options.fixture) {
        const data = JSON.parse(await readFile(options.fixture, 'utf8')) as { responses: (string | { text: string; delayMs?: number } | { tool: { name: string; args: Record<string, Json> }; delayMs?: number })[]; delayMs?: number };
        const faux = fauxProvider({ models: [{ id: 'fixture', contextWindow: 100000, maxTokens: 4000 }] });
        faux.setResponses(data.responses.map(response => async (_request, settings, _state, model) => {
          const duration = typeof response === 'string' ? data.delayMs : response.delayMs;
          if (duration) await delay(duration, undefined, { signal: settings?.signal });
          const message = typeof response !== 'string' && 'tool' in response ? fauxAssistantMessage(fauxToolCall(response.tool.name, response.tool.args), { stopReason: 'toolUse' }) : fauxAssistantMessage(typeof response === 'string' ? response : response.text);
          return { ...message, model: model.id };
        }));
        const fake = createModels(); fake.setProvider(faux.provider); models = fake;
      }
      models ??= await ModelRuntime.create({ allowModelNetwork: false });
      let harness: Harness;
      let ledger: Ledger;
      let ReviewTask: ReturnType<typeof reviewDefinition>;
      const tasks = definitions({ dir, cwd, review: () => ReviewTask, ledger: () => ledger });
      const DeadlineTask = deadlineDefinition(() => ledger);
      const GroupTask = groupDefinition(tasks, () => ledger, cwd, DeadlineTask);
      ReviewTask = reviewDefinition(tasks, () => ledger, cwd);
      const toolExtension = tools(async (grantId, api, context) => {
        const state = (await api.snapshot(State, context))!;
        const grant = state.grants[grantId];
        if (!grant) throw new Error('Unknown human command grant');
        const role = await api.snapshot(Role, api.conversationId, context);
        if (publication(commandEffect(grant.argv, cwd).action)) throw new Error('Agent command tools cannot consume publication grants; use the reviewed manifest step');
        const writer = role?.attempt ? state.attempts[role.attempt]?.taskId : null;
        const consumer = writer ? Object.entries(state.work).find(([, work]) => work.taskId === writer)?.[0] : `root:${api.conversationId}`;
        if (!consumer || grant.consumer !== consumer) throw new Error('Agent command grant must name this recorded writer work key (or root conversation) as its consumer');
        const input: CommandInput = { key: `tool-command:${api.taskId}`, grantId, argv: grant.argv, timeoutMs: 300000, files: { ...role?.frozenInputs }, validation: false, run: role?.mission?.run ?? null, mission: role?.mission ?? null, toolSurface: true, consumer };
        const id = await api.commit(tx => tasks.createStep(tx, { name: input.key, kind: 'command', input, dependsOn: [] }, api.taskId), context);
        const result = (await api.waitForTask(id, context)).state.outcome;
        if (result.status !== 'completed' || result.result.status !== 'passed') throw new Error('Granted command did not complete; inspect the durable command receipt');
        return result.result.data ?? result.result.evidence;
      }, () => ledger);
      const registry = createRegistry();
      registry.install(defineExtension({ name: 'etabli-tasks', tasks: [tasks.AgentTask, tasks.CommandTask, tasks.WaitTask, GroupTask, DeadlineTask, ReviewTask] }));
      registry.install(toolExtension); registry.install(policy(() => harness, models));
      harness = await Harness.open(guarded, { models, registry, settings: { retry: { enabled: false }, compaction: { enabled: false, keepRecentTokens: 200 }, stream: { maxRetries: 0, timeoutMs: 120000 } }, env: ({ cwd: target }) => new NodeExecutionEnv({ cwd: target ?? cwd }), onReport: error => process.stderr.write(`Durable: ${error instanceof Error ? error.name : 'runtime failure'}\n`) }, ctx);
      opened = harness;
      const prior = await harness.snapshot(State, ctx);
      if (prior?.sessionId && (prior.cwd !== cwd || (options.model && fingerprint(options.model) !== fingerprint(prior.model)))) throw new Error('Recorded session is bound to a different cwd/model; reopen with its original settings');
      const model = prior?.sessionId ? prior.model : options.model;
      if (!model) throw new Error('New session requires --provider and --model');
      const providers = prior?.sessionId ? prior.providers : options.providers ?? [model.provider];
      if (!providers.includes(model.provider) || !models.getModel(model.provider, model.modelId)) throw new Error('Selected model is unavailable or outside the provider allowlist');
      if (options.maxRequests !== undefined && (!Number.isSafeInteger(options.maxRequests) || options.maxRequests < 1)) throw new Error('Request budget must be a positive integer');
      if (options.deadline !== undefined && (!Number.isSafeInteger(options.deadline) || options.deadline < 1)) throw new Error('Deadline must be an absolute Unix time in milliseconds');
      if (prior?.sessionId && ((options.maxRequests !== undefined && options.maxRequests !== prior.maxRequests) || (options.deadline !== undefined && options.deadline !== prior.deadline))) throw new Error('Resume keeps the consumed budget; use the human budget control to extend it');
      const root = await harness.root(ctx, { agent: { cwd, model } });
      await harness.commit(async tx => {
        const state = await tx.doc(State);
        if (!state.sessionId) { state.sessionId = randomUUID(); state.cwd = cwd; state.model = model; state.providers = providers; state.maxRequests = options.maxRequests ?? 200; state.deadline = options.deadline ?? Date.now() + 8 * 3600000; }
        await tx.doc(Role, root.id);
      }, ctx);
      const repo = fileURLToPath(new URL('../../', import.meta.url));
      ledger = new Ledger(harness, repo, cwd);
      const host = new Host(dir, cwd, owner, harness, ledger, tasks, GroupTask, ReviewTask, root);
      await host.reconcileWork();
      await ledger.reconcile();
      const state = (await harness.snapshot(State, ctx))!;
      for (const [id, input] of Object.entries(state.admissions)) if (input.submissionId === null) await host.admit(id, input);
      if (options.resume !== false) harness.resume();
      return host;
    } catch (error) {
      try { if (opened) await opened.close(ctx); else await storage?.close(ctx); }
      finally { owner.close(); }
      throw error;
    }
  }
  async snapshot() { return projection(this.harness, this.root.id); }
  async handoff() { return handoffProjection(this.harness, this.root.id); }
  onChange(listener: () => void) { this.#listeners.add(listener); return () => this.#listeners.delete(listener); }
  async admit(id: string, input: { session: string; conversation: ConversationId; text: string; deliverAs: 'steer' | 'followUp' | null }) {
    requireKey(id);
    const state = (await this.harness.snapshot(State, ctx))!;
    if (input.session !== state.sessionId || input.conversation !== this.root.id || typeof input.text !== 'string' || !input.text.trim() || ![null, 'steer', 'followUp'].includes(input.deliverAs)) throw new Error('Message binding/content is invalid for this recorded conversation');
    await this.harness.commit(async tx => {
      const draft = await tx.doc(State);
      const old = draft.admissions[id];
      if (old && fingerprint([old.session, old.conversation, old.text, old.deliverAs]) !== fingerprint([input.session, input.conversation, input.text, input.deliverAs])) throw new Error('Message ID reused with different content, delivery mode or target');
      draft.admissions[id] ??= { ...input, submissionId: null };
    }, ctx);
    const submission = await this.root.submit({ type: 'input', requestId: id, content: input.text, ...(input.deliverAs ? { whenBusy: input.deliverAs } : {}) }, ctx);
    await this.harness.commit(async tx => { (await tx.doc(State)).admissions[id].submissionId = submission.id; }, ctx);
    return { status: 'submitted', detail: null, admissionId: id, durableAdmission: true, submissionId: submission.id };
  }
  async start(kind: string, input: AgentInput | CommandInput | WaitInput | GroupInput | ReviewInput) {
    await this.reconcileWork();
    requireKey(input.key);
    if (['agent', 'command'].includes(kind) && (input as CommandInput).mission) throw new Error('Standalone work cannot supply a mission; use an owned parent manifest step');
    if (kind === 'group') validateGroup(input as GroupInput);
    if (kind === 'review') validateReview(input as ReviewInput);
    if (kind === 'agent') requireModel((input as AgentInput).model ?? (await this.harness.snapshot(State, ctx))!.model);
    if (kind !== 'wait') await verifyInputs(this.cwd, (input as AgentInput).files ?? {});
    const id = await this.root.commit(async tx => {
      const state = await tx.doc(State);
      const old = state.work[input.key];
      if (old) { if (old.inputHash !== fingerprint(input)) throw new Error('Work key reused with different immutable inputs'); return old.taskId; }
      const options = { ownership: { kind: 'conversation' as const } };
      const id = kind === 'agent' ? await tx.createTask(this.tasks.AgentTask, input as AgentInput, options) : kind === 'command' ? await tx.createTask(this.tasks.CommandTask, input as CommandInput, options) : kind === 'wait' ? await tx.createTask(this.tasks.WaitTask, input as WaitInput, options) : kind === 'review' ? await tx.createTask(this.ReviewTask, input as ReviewInput, options) : kind === 'group' ? await tx.createTask(this.GroupTask, input as GroupInput, options) : null;
      if (!id) throw new Error('Unknown task kind');
      state.work[input.key] = { taskId: id, kind, inputHash: fingerprint(input), phase: 'prepare', result: null, children: [] };
      return id;
    }, ctx);
    this.harness.resume(); return { taskId: id };
  }
  async reconcileWork() { await this.harness.commit(reconcileWork, ctx); }
  async compact(key: string) {
    requireKey(key);
    const id = await this.root.commit(async tx => {
      const state = await tx.doc(State);
      const old = state.compactions[key];
      if (old) return old.taskId;
      const live = await tx.doc(LiveDoc, this.root.id);
      if (live.compactions?.length) throw new Error('A native compaction controller is already active; join its task');
      const taskId = await tx.createTask(CompactionTask, { reason: 'manual', instructions: `Preserve Durable mission progress and receipt identities; request ${key}` }, { ownership: { kind: 'conversation' } });
      live.compactions = [{ taskId, reason: 'manual', blocking: false, attempt: 1 }];
      state.compactions[key] = { taskId, status: 'admitted' };
      return taskId;
    }, ctx);
    this.harness.resume(); return { taskId: id };
  }
  async handle(request: Request): Promise<unknown> {
    const payload = request.payload;
    switch (request.command) {
      case 'state': return this.snapshot();
      case 'handoff': return this.handoff();
      case 'input': { const value = payload as Parameters<Host['admit']>[1] & { id: string }; return this.admit(value.id, value); }
      case 'agent': case 'command': case 'wait': case 'review': return this.start(request.command, payload as AgentInput | CommandInput | WaitInput | ReviewInput);
      case 'tasks': case 'campaign': case 'goal': case 'plan-implement': case 'ship': {
        const input = payload as GroupInput;
        return this.start('group', { ...input, kind: request.command === 'campaign' ? 'campaign' : request.command === 'tasks' ? 'tasks' : 'mission', route: ['goal', 'plan-implement', 'ship'].includes(request.command) ? request.command as GroupInput['route'] : null });
      }
      case 'compact': return this.compact(String((payload as { key: string }).key));
      case 'task': { const { id } = payload as { id: number }; if (!Number.isSafeInteger(id)) throw new Error('Task id must be an integer'); return this.harness.getTask(id as TaskId, ctx); }
      case 'cancel': { const { id } = payload as { id: number }; if (!Number.isSafeInteger(id)) throw new Error('Task id must be an integer'); return this.harness.abortTask(id as TaskId, ctx); }
      case 'grant': {
        const value = payload as { key: string; argv: string[]; expiresAt: number; evidence: string; consumer?: string };
        requireKey(value.key);
        if (!Array.isArray(value.argv) || !value.argv.length || value.argv.some(word => typeof word !== 'string' || !word || word.includes('\0')) || !Number.isSafeInteger(value.expiresAt) || value.expiresAt <= Date.now() || typeof value.evidence !== 'string' || !value.evidence.trim()) throw new Error('Human grant requires exact argv, future expiry and approval evidence');
        const effect = commandEffect(value.argv, this.cwd);
        if (value.consumer !== undefined) requireKey(value.consumer);
        if (publication(effect.action) && !value.consumer) throw new Error('Publication grant requires the intended manifest work key as consumer');
        await this.harness.commit(async tx => {
          const state = await tx.doc(State);
          if (state.grants[value.key]) throw new Error('Grant identities are immutable; issue a new grant');
          state.grants[value.key] = { ...effect, argv: value.argv, cwd: this.cwd, expiresAt: value.expiresAt, evidence: value.evidence, usedBy: null, consumer: value.consumer ?? null };
        }, ctx); return { granted: value.key, ...effect };
      }
      case 'budget': {
        const value = payload as { maxRequests: number; deadline: number; evidence: string };
        if (!Number.isSafeInteger(value.maxRequests) || !Number.isSafeInteger(value.deadline) || value.deadline <= Date.now() || typeof value.evidence !== 'string' || !value.evidence.trim()) throw new Error('Budget extension requires integer limits, a future deadline and human evidence');
        await this.harness.commit(async tx => {
          const state = await tx.doc(State);
          if (value.maxRequests < state.maxRequests || value.deadline < state.deadline || (value.maxRequests === state.maxRequests && value.deadline === state.deadline)) throw new Error('Budget control only permits an explicit increase; consumed requests are never reset');
          state.budgetChanges ??= [];
          state.budgetChanges.push({ ...value, at: Date.now(), consumed: state.requests });
          state.maxRequests = value.maxRequests; state.deadline = value.deadline;
        }, ctx);
        return { extended: true, ...(await this.snapshot()).state.workflow.budget };
      }
      case 'abandon-export': { const value = payload as { id: string; evidence: string }; requireKey(value.id); await this.ledger.abandon(value.id, value.evidence); return { abandoned: value.id }; }
      case 'reconcile': {
        const value = payload as { key: string; receipt: string; hash: string };
        await privateFile(value.receipt);
        if (fingerprint(await readFile(value.receipt, 'utf8')) !== value.hash) throw new Error('Reconciliation receipt hash does not match');
        await this.harness.commit(async tx => {
          const effect = (await tx.doc(State)).effects[value.key];
          if (!effect || effect.status !== 'uncertain') throw new Error('No unresolved effect with this identity');
          effect.status = 'verified'; effect.receipt = value.receipt;
        }, ctx); return { reconciled: value.key };
      }
      case 'export': { const value = payload as { id: string; event: string; run: string; detail: Record<string, Json> }; requireKey(value.id); requireKey(value.run); await this.ledger.export(value.id, value); return { exported: value.id }; }
      default: throw new Error(`Unknown control command ${request.command}`);
    }
  }
  async listen() {
    const path = join(this.dir, 'control.sock');
    this.owner.assert();
    await capability(this.dir);
    try { await unlink(path); } catch (error) { if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error; }
    this.#server = createServer(socket => {
      socket.setEncoding('utf8');
      this.#sockets.add(socket); socket.once('close', () => this.#sockets.delete(socket));
      let buffer = '';
      socket.on('data', bytes => {
        buffer += bytes.toString('utf8');
        if (buffer.length > 1024 * 1024) { socket.destroy(new Error('Control frame too large')); return; }
        const index = buffer.indexOf('\n');
        if (index < 0) return;
        const line = buffer.slice(0, index); buffer = '';
        const run = async () => {
          try {
            const request = JSON.parse(line) as Request & { capability: string };
            const expected = await capability(this.dir);
            if (typeof request.capability !== 'string' || request.capability.length !== expected.length || !timingSafeEqual(Buffer.from(request.capability), Buffer.from(expected))) throw new Error('Invalid local control capability');
            this.owner.assert();
            const result = await this.handle(request);
            socket.end(JSON.stringify({ ok: true, result }) + '\n');
          } catch (error) { socket.end(JSON.stringify({ ok: false, error: error instanceof Error ? error.message : 'Control command failed' }) + '\n'); }
        };
        this.#queue = this.#queue.then(run, run);
      });
      socket.on('error', () => {});
    });
    await new Promise<void>((resolve, reject) => { this.#server!.once('error', reject); this.#server!.listen(path, resolve); });
    await chmod(path, 0o600);
  }
  async close() {
    if (this.#closed) return; this.#closed = true;
    for (const socket of this.#sockets) socket.destroy();
    await this.harness.close(ctx);
    if (this.#server) await new Promise<void>(resolve => this.#server!.close(() => resolve()));
    this.owner.close();
  }
}
