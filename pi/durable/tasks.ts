import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { defineTask, AgentDoc, type ConversationId, type TaskId, type TaskRuntime, type Tx, type TaskOutcome, type Task } from '@earendil-works/pi-durable';
import type { Context } from '@earendil-works/chord';
import { BACKGROUND_CONTEXT } from '@earendil-works/chord/context';
import { State, Role, fingerprint, type Model, type Result, type MissionContext } from './state.ts';
import { commandGrant, commandEffect, effectKey, verifyInputs, publication } from './guards.ts';
import { command, commandReceipt, type CommandInput } from './commands.ts';
import { execute, ledgerEvents, ledgerHash, type Ledger } from './ledger.ts';
import { redact, redactedJson } from './egress.ts';
import type { ReviewInput, ReviewState } from './reviews.ts';
import { missionGate, mutationRun, recordMutation, executionMission, publicationMission } from './missions.ts';

export type AgentInput = { key: string; prompt: string; role: 'writer' | 'reviewer'; model: Model | null; files: Record<string, string>; review: boolean; reviewAxis?: 'logic' | 'spec' | 'adversary'; mission?: MissionContext | null };
export type AgentState = { phase: 'prepare' } | { phase: 'answer'; conversation: ConversationId; attempt: string };
export type CommandState = { phase: 'prepare' } | { phase: 'execute'; effect: string; validationStamp?: string | null };
export type WaitInput = { key: string; repo: string; pr: number; head: string; deadline: number; intervalMs: number; fixture: string | null };
export type WaitState = { phase: 'poll'; nextPoll: number; polls: number; last: string };
export type Checks = { head: string; checks: { name: string; state: string; head: string }[] };
export type Step = { name: string; dependsOn: string[] } & ({ kind: 'agent'; input: AgentInput } | { kind: 'command'; input: CommandInput } | { kind: 'wait'; input: WaitInput } | { kind: 'review'; input: ReviewInput });
export type GroupInput = { key: string; kind: 'tasks' | 'campaign' | 'mission'; route: 'goal' | 'plan-implement' | 'ship' | null; run: string | null; objective: string; steps: Step[]; maxAttempts: number; deadline: number };
type GroupProgress = { children: Record<string, TaskId<Result>>; results: Record<string, Result>; attempts: number; deadlineTask?: TaskId<Result> | null; lastEvidence?: string | null; nextEvidence?: number };
export type GroupState = GroupProgress & ({ phase: 'schedule' } | { phase: 'collect' } | { phase: 'evidence' });

export function taskResult(outcome: TaskOutcome<Result>): Result {
  if (outcome.status === 'completed') return outcome.result;
  if (outcome.status === 'aborted') return { status: 'cancelled', evidence: 'Native abort drained owned children' };
  return { status: 'failed', evidence: `Native task outcome: ${outcome.status}` };
}

async function finish<I, S extends { phase: string }>(runtime: TaskRuntime<I, S, Result, {}>, key: string, result: Result, context: Context) {
  await runtime.commit(async tx => {
    const state = await tx.doc(State);
    const work = state.work[key];
    if (work) { work.result = result; work.phase = result.status; }
    if (state.writerTaskId === runtime.taskId) state.writerTaskId = null;
    for (const attempt of Object.values(state.attempts)) if (attempt.taskId === runtime.taskId) attempt.status = result.status;
    return { status: 'terminal', outcome: { status: 'completed', result } };
  }, context);
}

function reviewAnswer(text: string, axis?: AgentInput['reviewAxis']): boolean {
  let result: unknown;
  try { result = JSON.parse(text.replace(/^```(?:json)?\s*|\s*```$/g, '')); } catch { return false; }
  if (!result || typeof result !== 'object' || !('verdict' in result) || !('findings' in result) || !Array.isArray(result.findings) || !['GO', 'GO WITH NOTES', 'BLOCK'].includes(String(result.verdict))) return false;
  if (result.findings.some(row => !row || typeof row !== 'object' || !['high', 'medium', 'low'].includes(row.severity) || !['file', 'issue', 'impact', 'review_comment', 'suggested_fix'].every(key => typeof row[key] === 'string' && row[key].trim()) || !Number.isInteger(row.line) || row.line < 1)) return false;
  if (axis === 'spec') return true;
  if (!('decidingCode' in result) || !Array.isArray(result.decidingCode) || !result.decidingCode.length || !result.decidingCode.every(row => row && typeof row === 'object' && typeof row.path === 'string' && Number.isInteger(row.line) && row.line > 0 && typeof row.decision === 'string' && row.decision.trim() && (!axis || (typeof row.behavior === 'string' && row.behavior.trim() && typeof row.resolver === 'string' && /:\d+/.test(row.resolver) && !/not run/i.test(row.decision))))) return false;
  if (axis !== 'logic') return true;
  const lenses = ['precedence', 'degraded modes', 'impossible states', 'prose vs machine-readable', 'exhaustive reachability', 'asymmetry', 'boundary drift', 'convention'];
  if (!('lenses' in result) || !Array.isArray(result.lenses)) return false;
  const table = result.lenses;
  return lenses.every(lens => table.some(row => row && typeof row === 'object' && row.lens === lens && typeof row.checked === 'string' && (/:\d+/.test(row.checked) || (lens === 'convention' && row.checked === 'deferred: Standards hunter') || (lens === 'prose vs machine-readable' && row.checked === 'absent')) && typeof row.found === 'string'));
}

export async function readChecks(input: WaitInput): Promise<Checks> {
  if (input.fixture) return JSON.parse(await readFile(input.fixture, 'utf8')) as Checks;
  const { stdout } = await execute('gh', ['pr', 'view', String(input.pr), '--repo', input.repo, '--json', 'headRefOid,statusCheckRollup'], { timeout: 30000 });
  const data = JSON.parse(stdout) as { headRefOid: string; statusCheckRollup: { name?: string; context?: string; status?: string; conclusion?: string; state?: string }[] };
  return { head: data.headRefOid, checks: data.statusCheckRollup.map(check => ({ name: check.name ?? check.context ?? 'check', state: check.conclusion || check.state || check.status || 'UNKNOWN', head: data.headRefOid })) };
}

export function definitions(options: { dir: string; cwd: string; ledger: () => Ledger; review: () => Task<ReviewInput, ReviewState, Result, {}> }) {
  const fresh = new Set<number>();
  const AgentTask = defineTask<AgentInput, AgentState, Result>({
    name: 'etabli.agent', version: 1, initial: () => ({ phase: 'prepare' }),
    phases: {
      prepare: async (task, runtime, context) => {
        await verifyInputs(options.cwd, task.input.files);
        await runtime.commit(async tx => {
          const state = await tx.doc(State);
          if (state.writerTaskId !== null && (await tx.task(state.writerTaskId as TaskId))?.state.status === 'terminal') state.writerTaskId = null;
          if (task.input.role === 'writer' && state.writerTaskId !== null && state.writerTaskId !== task.id) throw new Error('A mission already owns the writer; declare a dependency before starting another writer');
          const identity = fingerprint({ ...task.input, key: '' });
          const spent = Object.values(state.attempts).filter(a => a.kind === 'agent' && a.inputHash === identity).length;
          if (spent >= 2) throw new Error('Two attempts on this unchanged agent input are spent; change the hypothesis before retrying');
          const attempt = `agent:${task.id}`;
          state.attempts[attempt] = { taskId: task.id, kind: 'agent', inputHash: identity, requests: 0, resolvedRequests: 0, tokens: 0, cost: 0, status: 'running', responses: [], models: [] };
          if (task.input.role === 'writer') state.writerTaskId = task.id;
          const conversation = await tx.createConversation({ ownership: { kind: 'task', taskId: task.id } });
          const agent = await tx.doc(AgentDoc, conversation.id);
          agent.model = task.input.model ?? { provider: state.model.provider, modelId: state.model.modelId };
          agent.cwd = state.cwd;
          agent.tools = task.input.reviewAxis === 'spec' ? [] : task.input.role === 'reviewer' ? ['read'] : ['read', 'write', 'edit', 'run_granted_command'];
          const role = await tx.doc(Role, conversation.id);
          role.role = task.input.role; role.attempt = attempt; role.frozenInputs = task.input.files; role.mission = task.input.mission ?? null;
          if (state.work[task.input.key]) state.work[task.input.key].phase = 'answer';
          return { status: 'running', checkpoint: { phase: 'answer', conversation: conversation.id, attempt } };
        }, context);
      },
      answer: async (task, runtime, context) => {
        await verifyInputs(options.cwd, task.input.files);
        const conversation = await runtime.conversation(task.state.checkpoint.conversation, context);
        if (!conversation) throw new Error('Owned reviewer conversation is missing');
        const prompt = task.input.review ? `${task.input.prompt}\nReturn JSON only: {"verdict":"GO|GO WITH NOTES|BLOCK","findings":[{"severity":"high|medium|low","file":"file","line":1,"issue":"failure","impact":"effect","review_comment":"explanation","suggested_fix":"one sentence"}]${task.input.reviewAxis === 'spec' ? '' : ',"decidingCode":[{"behavior":"changed runtime behavior","path":"file","line":1,"resolver":"caller-or-sibling:line","decision":"verified branch"}]'}${task.input.reviewAxis === 'logic' ? ',"lenses":[{"lens":"each named lens","checked":"file:line","found":"none or issue"}]' : ''}}. Use empty findings for a clean pass. Never edit files.` : task.input.prompt;
        const submission = await conversation.submit({ type: 'input', content: prompt, requestId: `agent:${task.id}` }, context);
        const settled = await submission.wait(context);
        await verifyInputs(options.cwd, task.input.files);
        if (settled.status !== 'done' || settled.type !== 'input') return finish(runtime, task.input.key, { status: 'failed', evidence: 'Agent did not produce a complete native submission' }, context);
        const entry = (await runtime.context(conversation.id, context)).entries.find(entry => entry.id === settled.answer);
        const message = entry?.model?.find(message => message.role === 'assistant');
        const text = message?.role === 'assistant' ? message.content.flatMap(part => part.type === 'text' ? [part.text] : []).join('\n') : '';
        if (!text || (task.input.review && !reviewAnswer(text, task.input.reviewAxis))) return finish(runtime, task.input.key, { status: 'failed', evidence: 'Reviewer output is partial or lacks complete findings, lenses or deciding-code evidence' }, context);
        return finish(runtime, task.input.key, { status: 'passed', evidence: `conversation:${conversation.id}; submission:${submission.id}; input:${fingerprint(task.input)}; model:${message?.provider}/${message?.model}`, data: task.input.review ? redactedJson(JSON.parse(text.replace(/^```(?:json)?\s*|\s*```$/g, ''))) : redact(text) }, context);
      },
    },
    abort: (task, runtime, context) => finish(runtime, task.input.key, { status: 'cancelled', evidence: 'Agent and owned conversation drained' }, context),
  });
  const CommandTask = defineTask<CommandInput, CommandState, Result>({
    name: 'etabli.command', version: 1, initial: () => ({ phase: 'prepare' }),
    phases: {
      prepare: async (task, runtime, context) => {
        await verifyInputs(options.cwd, task.input.files);
        const effect = commandEffect(task.input.argv, options.cwd);
        await commandGate(task.input, task.id);
        const scope = (await runtime.snapshot(State, context))!.sessionId;
        const key = effectKey(effect.action, effect.target, scope);
        const role = await runtime.snapshot(Role, task.conversationId, context);
        const validationStamp = task.input.validation && task.input.run ? await mutationStamp(task.input.run) : null;
        await runtime.commit(async tx => {
          const state = await tx.doc(State);
          if (state.writerTaskId !== null && (await tx.task(state.writerTaskId as TaskId))?.state.status === 'terminal') state.writerTaskId = null;
          const writer = role?.attempt ? state.attempts[role.attempt]?.taskId : task.id;
          if (state.writerTaskId !== null && state.writerTaskId !== writer) throw new Error('Another owned writer is active; declare a dependency before executing a command');
          const grant = commandGrant(state, task.input.grantId, task.input.argv, options.cwd, Date.now(), task.input.consumer ?? task.input.key);
          if (grant.usedBy !== null && grant.usedBy !== task.id) throw new Error('This human grant was already consumed; authorize a distinct fresh attempt');
          if (state.effects[key]?.status === 'uncertain') throw new Error('An earlier equivalent command is unresolved; reconcile it before a new task or tool call');
          grant.usedBy = task.id;
          if (!task.input.validation) state.writerTaskId = writer ?? task.id;
          state.effects[key] = { ...effect, scope, taskId: task.id, status: 'uncertain', receipt: null };
          state.attempts[`command:${task.id}`] = { taskId: task.id, kind: 'command', inputHash: fingerprint(task.input), requests: 0, resolvedRequests: 0, tokens: 0, cost: 0, status: 'reserved', responses: [], models: [] };
          if (state.work[task.input.key]) state.work[task.input.key].phase = 'execute';
          return { status: 'running', checkpoint: { phase: 'execute', effect: key, validationStamp } };
        }, context);
        fresh.add(task.id);
      },
      execute: async (task, runtime, context) => {
        await verifyInputs(options.cwd, task.input.files);
        let receipt = await commandReceipt(options.dir, task.id, task.input);
        if (!receipt) {
          if (!fresh.delete(task.id)) return finish(runtime, task.input.key, { status: 'blocked', evidence: 'Interrupted unsafe execution has no valid receipt; inspect and reconcile this effect before a fresh attempt' }, context);
          let launching = false;
          try {
            commandGrant((await runtime.snapshot(State, context))!, task.input.grantId, task.input.argv, options.cwd, Date.now(), task.input.consumer ?? task.input.key);
            await commandGate(task.input, task.id);
            if (!task.input.validation && !publication(commandEffect(task.input.argv, options.cwd).action)) await recordMutation(options.ledger(), `mutation:command:${task.id}`, mutationRun(options.cwd, task.input.mission, task.input.run), '.', `Native command reserved before execution: ${task.input.argv.join(' ')}`);
            await commandGate(task.input, task.id);
            await verifyInputs(options.cwd, task.input.files);
            commandGrant((await runtime.snapshot(State, context))!, task.input.grantId, task.input.argv, options.cwd, Date.now(), task.input.consumer ?? task.input.key);
            receipt = await command(options.dir, options.cwd, task.id, task.input, runtime.signal, async () => {
              await commandGate(task.input, task.id);
              const current = (await runtime.snapshot(State, context))!;
              await verifyInputs(options.cwd, task.input.files);
              commandGrant(current, task.input.grantId, task.input.argv, options.cwd, Date.now(), task.input.consumer ?? task.input.key);
              launching = true;
            });
          } catch (error) {
            if (launching) throw error;
            await runtime.commit(async tx => {
              const effect = (await tx.doc(State)).effects[task.state.checkpoint.effect];
              effect.status = 'verified'; effect.receipt = `command:${task.id}:not-started`;
              return undefined;
            }, context);
            return finish(runtime, task.input.key, { status: 'failed', evidence: `Command refused before worker launch: ${redact(error instanceof Error ? error.message : String(error))}` }, context);
          }
        }
        await verifyInputs(options.cwd, task.input.files);
        await runtime.commit(async tx => {
          const effect = (await tx.doc(State)).effects[task.state.checkpoint.effect];
          if (!receipt.interrupted) effect.status = 'verified';
          effect.receipt = join(options.dir, `command-${task.id}.receipt.json`);
          return undefined;
        }, context);
        const passed = task.input.validation && task.input.run ? await validationProof(task.id, task.input, task.state.checkpoint.validationStamp, receipt, runtime, context) : receipt.exit === 0 && !receipt.interrupted;
        return finish(runtime, task.input.key, { status: passed ? 'passed' : 'failed', evidence: passed === null ? 'Canonical validation export exceeded its original deadline; retained intents require reconciliation, command was not repeated' : join(options.dir, `command-${task.id}.receipt.json`), data: redact(receipt.stdout + receipt.stderr) }, context);
      },
    },
    abort: (task, runtime, context) => finish(runtime, task.input.key, { status: 'cancelled', evidence: 'Command worker drained; retained effect/receipt requires reconciliation if interrupted' }, context),
  });

  async function mutationStamp(run: string) { return fingerprint((await ledgerEvents(options.cwd, run)).filter(event => event.event === 'file_changed')); }

  async function validationProof(id: number, input: CommandInput, stamp: string | null | undefined, receipt: Awaited<ReturnType<typeof command>>, runtime: TaskRuntime<CommandInput, CommandState, Result, {}>, context: Context): Promise<boolean | null> {
    const run = input.run!;
    const deadline = input.mission?.deadline ?? (await runtime.snapshot(State, context))!.deadline;
    const own = new RegExp(`^validation:${id}(?::[a-f0-9]{64})?$`);
    while (true) {
      const expected = await ledgerHash(options.cwd, run);
      const state = (await runtime.snapshot(State, context))!;
      for (const [key, item] of Object.entries(state.exports)) {
        if (!own.test(key) || item.run !== run || !['validation_run', 'validation_failed'].includes(item.event) || item.detail.command !== input.argv.join(' ')) continue;
        if (await options.ledger().hasReceipt(key)) { await options.ledger().flush(key); return item.event === 'validation_run'; }
      }
      if (runtime.now() >= deadline) return null;
      const changed = stamp !== await mutationStamp(run);
      const passed = receipt.exit === 0 && !receipt.interrupted && !changed;
      if (expected === await ledgerHash(options.cwd, run)) {
        try {
          await options.ledger().export(`validation:${id}:${expected}`, { event: passed ? 'validation_run' : 'validation_failed', run, detail: { command: input.argv.join(' '), exit: passed ? 0 : receipt.exit || 128, ...(passed ? {} : { failure: changed ? 'canonical files changed during validation; run a fresh check' : receipt.interrupted ? 'interrupted' : 'nonzero exit' }) } }, expected);
          return passed;
        } catch (error) { if (!(error instanceof Error) || !error.message.includes('ledger precondition changed')) throw error; }
      }
      await runtime.sleep(Math.min(runtime.now() + 20, deadline), context);
    }
  }

  async function commandGate(input: CommandInput, id: number) {
    const action = commandEffect(input.argv, options.cwd).action;
    const state = (await options.ledger().harness.snapshot(State, BACKGROUND_CONTEXT))!;
    const mission = publication(action) ? await publicationMission(options.ledger(), id, input) : await executionMission(options.cwd, input.mission, state.deadline, input.run);
    if (publication(action) && (input.toolSurface || !mission)) throw new Error('Publication requires a mission-bound manifest step; agent command tools cannot publish');
    if (mission) {
      mutationRun(options.cwd, mission);
      await missionGate(mission, { name: input.key, kind: 'command', input, dependsOn: [] }, options.cwd);
    }
  }
  const WaitTask = defineTask<WaitInput, WaitState, Result>({
    name: 'etabli.ci-wait', version: 1, initial: () => ({ phase: 'poll', nextPoll: 0, polls: 0, last: '' }),
    phases: {
      poll: async (task, runtime, context) => {
        await runtime.sleep(Math.min(task.state.checkpoint.nextPoll, task.input.deadline), context);
        let checks: Checks;
        try { checks = await readChecks(task.input); }
        catch {
          if (runtime.now() >= task.input.deadline) return finish(runtime, task.input.key, { status: 'failed', evidence: 'CI unavailable at the original deadline; target and checks remain unverified' }, context);
          await runtime.commit(() => ({ status: 'running', checkpoint: { phase: 'poll', nextPoll: Math.min(runtime.now() + task.input.intervalMs, task.input.deadline), polls: task.state.checkpoint.polls + 1, last: 'unavailable' } }), context);
          return;
        }
        if (typeof checks.head !== 'string' || !Array.isArray(checks.checks)) throw new Error('Invalid CI read response');
        if (runtime.now() >= task.input.deadline) return finish(runtime, task.input.key, { status: 'failed', evidence: `Original CI deadline expired; freshly read HEAD ${checks.head}`, data: JSON.stringify(checks) }, context);
        if (checks.head !== task.input.head || checks.checks.some(check => check.head !== task.input.head)) return finish(runtime, task.input.key, { status: 'blocked', evidence: `PR HEAD changed from ${task.input.head} to ${checks.head}; start a new target-bound wait` }, context);
        if (checks.checks.some(check => ['FAILURE', 'FAILED', 'ERROR', 'CANCELLED', 'TIMED_OUT', 'ACTION_REQUIRED'].includes(check.state))) return finish(runtime, task.input.key, { status: 'failed', evidence: 'Fresh CI checks contain a terminal failure', data: JSON.stringify(checks) }, context);
        if (checks.checks.length > 0 && checks.checks.every(check => ['SUCCESS', 'NEUTRAL', 'SKIPPED'].includes(check.state))) return finish(runtime, task.input.key, { status: 'passed', evidence: `Fresh PR HEAD ${checks.head} and ${checks.checks.length} checks`, data: JSON.stringify(checks) }, context);
        await runtime.commit(async tx => {
          const state = await tx.doc(State);
          if (state.work[task.input.key]) state.work[task.input.key].phase = `ci_wait:${task.input.deadline}`;
          return { status: 'running', checkpoint: { phase: 'poll', nextPoll: Math.min(runtime.now() + task.input.intervalMs, task.input.deadline), polls: task.state.checkpoint.polls + 1, last: fingerprint(checks) } };
        }, context);
      },
    },
    abort: (task, runtime, context) => finish(runtime, task.input.key, { status: 'cancelled', evidence: 'CI wait cancelled with its original deadline retained' }, context),
  });

  async function createStep(tx: Tx, step: Step, owner: TaskId) {
    const state = await tx.doc(State);
    const inputHash = fingerprint(step.input);
    const prior = state.work[step.input.key];
    if (prior) {
      if (prior.inputHash !== inputHash) throw new Error('Work key reused with different immutable inputs');
      const task = await tx.task(prior.taskId);
      if (task?.state.status !== 'terminal' && task?.owner !== owner) throw new Error('A different parent owns this live work key; join its parent or choose a new child identity');
      return prior.taskId;
    }
    const ownership = { kind: 'task' as const, taskId: owner };
    const taskId = step.kind === 'agent' ? await tx.createTask(AgentTask, step.input, { ownership }) : step.kind === 'command' ? await tx.createTask(CommandTask, step.input, { ownership }) : step.kind === 'review' ? await tx.createTask(options.review(), step.input, { ownership }) : await tx.createTask(WaitTask, step.input, { ownership });
    state.work[step.input.key] = { taskId, kind: step.kind, inputHash, phase: 'prepare', result: null, children: [] };
    return taskId;
  }

  return { AgentTask, CommandTask, WaitTask, createStep, finish };
}
