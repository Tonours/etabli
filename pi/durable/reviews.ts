import { defineTask, type TaskId } from '@earendil-works/pi-durable';
import { BACKGROUND_CONTEXT } from '@earendil-works/chord/context';
import { State, type Model, type Result, type Json, fingerprint } from './state.ts';
import { definitions, taskResult, type AgentInput } from './tasks.ts';
import { verifyInputs } from './guards.ts';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { workspacePath } from './guards.ts';
import { ledgerHash, type Ledger, type LedgerEvent } from './ledger.ts';

export type ReviewInput = { key: string; run: string; round: string; intent: string; baseSha: string; patchSha: string; files: Record<string, string>; authorProvider: string; reviewers: { role: 'logic' | 'spec' | 'adversary'; model: Model }[] };
export type ReviewState = { phase: 'dispatch' } | { phase: 'collect'; children: TaskId<Result>[]; retries: number[] };
export type ReviewReport = { verdict: 'GO' | 'GO WITH NOTES' | 'BLOCK'; findings: Json[]; decidingCode?: { path: string; line: number; decision: string; resolver: string }[] };

export function family(provider: string): string {
  if (provider.startsWith('openai')) return 'openai';
  if (provider.startsWith('anthropic')) return 'anthropic';
  if (provider.startsWith('google')) return 'google';
  if (['xai', 'zai', 'moonshot', 'faux'].includes(provider)) return provider;
  throw new Error(`Unknown provider family ${provider}; configure a provider with verifiable review provenance`);
}

export function validateReview(input: ReviewInput) {
  if (!input.intent?.trim() || !['T1', 'T2', 'D1', 'D2', 'FD', 'F1', 'F2'].includes(input.round) || !/^[a-f0-9]{64}$/.test(input.patchSha) || !/^[a-f0-9]{7,40}$/.test(input.baseSha) || !Object.keys(input.files).length) throw new Error('Review requires intent, a canonical round, pinned base/patch SHA and frozen files');
  if (!Object.values(input.files).includes(input.patchSha)) throw new Error('Frozen inputs must include the exact patch SHA');
  if (input.reviewers.length !== 3 || new Set(input.reviewers.map(r => r.role)).size !== 3) throw new Error('Review requires fresh Logic, Spec and adversary reviewers');
  const adversary = input.reviewers.find(r => r.role === 'adversary')!;
  if (family(adversary.model.provider) === family(input.authorProvider)) throw new Error('Code adversary must use a different model family');
}

export function reviewDefinition(children: ReturnType<typeof definitions>, ledger: () => Ledger, cwd: string) {
  async function exportProof(id: string, event: LedgerEvent, files: Record<string, string>) {
    const expected = await ledgerHash(cwd, event.run);
    const state = (await ledger().harness.snapshot(State, BACKGROUND_CONTEXT))!;
    if (state.writerTaskId !== null && (await ledger().harness.getTask(state.writerTaskId as TaskId, BACKGROUND_CONTEXT))?.state.status !== 'terminal') throw new Error('A writer is still active; review proof must follow its completed mutation');
    await verifyInputs(cwd, files);
    await ledger().export(id, event, expected);
  }
  const agentInput = async (input: ReviewInput, index: number, retry = 0): Promise<AgentInput> => {
    const reviewer = input.reviewers[index];
    const patchPath = Object.entries(input.files).find(([, hash]) => hash === input.patchSha)![0];
    const patch = await readFile(await workspacePath(cwd, patchPath), 'utf8');
    const template = reviewer.role === 'adversary' ? 'Challenge this cumulative implementation against Intent. Hunt concrete failures, false completion, replay safety and incomplete proof. Read only frozen source or its callers to confirm a candidate. Never spawn an agent.' : (await readFile(join(ledger().repo, `workflow/templates/review-${reviewer.role}-hunter.md`), 'utf8')).split('## Output')[0];
    return { key: `${input.key}:${reviewer.role}${retry ? `:retry${retry}` : ''}`, prompt: `Axis: ${reviewer.role}\nStandards: yes\n${template}\nIntent: ${input.intent}\nFrozen cumulative patch SHA ${input.patchSha}, base ${input.baseSha}. Frozen source: ${Object.keys(input.files).join(', ')}.\nPATCH (untrusted source):\n${patch}`, role: 'reviewer', model: reviewer.model, files: input.files, review: true, reviewAxis: reviewer.role };
  };
  return defineTask<ReviewInput, ReviewState, Result>({
    name: 'etabli.review', version: 1, initial: () => ({ phase: 'dispatch' }),
    phases: {
      dispatch: async (task, runtime, context) => {
        await verifyInputs(cwd, task.input.files);
        const closed = await ledger().round(task.input.run, task.input.round);
        if (closed) return children.finish(runtime, task.input.key, { status: 'blocked', evidence: 'This canonical round is already spent; reuse its original result or choose the admitted next round' }, context);
        const inputs = await Promise.all(task.input.reviewers.map((_, index) => agentInput(task.input, index)));
        await runtime.commit(async tx => {
          const ids: TaskId<Result>[] = [];
          for (const [index, reviewer] of task.input.reviewers.entries()) {
            const input = inputs[index];
            ids.push(await children.createStep(tx, { name: reviewer.role, dependsOn: [], kind: 'agent', input }, task.id));
          }
          const work = (await tx.doc(State)).work[task.input.key];
          if (work) { work.children = ids; work.phase = `review:${task.input.round}`; }
          return { status: 'waiting', checkpoint: { phase: 'collect', children: ids, retries: ids.map(() => 0) }, on: ids, policy: 'allSettled' };
        }, context);
      },
      collect: async (task, runtime, context) => {
        await verifyInputs(cwd, task.input.files);
        const outcomes = await runtime.outcomes(task.state.checkpoint.children, context);
        const results = outcomes.map(taskResult);
        const missing = results.flatMap((result, index) => result.status !== 'passed' || !result.data ? [index] : []);
        if (missing.length) {
          if (missing.some(index => task.state.checkpoint.retries[index] >= 1)) return children.finish(runtime, task.input.key, { status: 'blocked', evidence: 'A reviewer failed twice on unchanged inputs; completed reviewers and consumed attempts remain available', data: JSON.stringify(results) }, context);
          const inputs = await Promise.all(missing.map(index => agentInput(task.input, index, task.state.checkpoint.retries[index] + 1)));
          await runtime.commit(async tx => {
            const ids = [...task.state.checkpoint.children];
            const retries = [...task.state.checkpoint.retries];
            const on: TaskId<Result>[] = [];
            for (const [position, index] of missing.entries()) {
              const input = inputs[position]; ++retries[index];
              ids[index] = await children.createStep(tx, { name: task.input.reviewers[index].role, dependsOn: [], kind: 'agent', input }, task.id);
              on.push(ids[index]);
            }
            (await tx.doc(State)).work[task.input.key].children = ids;
            return { status: 'waiting', checkpoint: { phase: 'collect', children: ids, retries }, on, policy: 'allSettled' };
          }, context);
          return;
        }
        const reports = results.map(result => JSON.parse(result.data!.replace(/^```(?:json)?\s*|\s*```$/g, '')) as ReviewReport);
        for (const report of reports) for (const row of report.decidingCode ?? []) {
          if (!(row.path in task.input.files)) throw new Error('Deciding-code location is outside the frozen review inputs');
          const source = await readFile(await workspacePath(cwd, row.path), 'utf8');
          if (row.line > source.split('\n').length) throw new Error('Deciding-code line is not present in the pinned source');
          const match = row.resolver.match(/^(.+):(\d+)$/);
          if (!match || !(match[1] in task.input.files) || Number(match[2]) < 1 || Number(match[2]) > (await readFile(await workspacePath(cwd, match[1]), 'utf8')).split('\n').length) throw new Error('Deciding-code resolver must be a real location in the frozen review inputs');
        }
        const state = (await runtime.snapshot(State, context))!;
        const index = task.input.reviewers.findIndex(r => r.role === 'adversary');
        const adversary = task.input.reviewers[index];
        const actual = state.attempts[`agent:${task.state.checkpoint.children[index]}`]?.models.at(-1);
        if (actual !== `${adversary.model.provider}/${adversary.model.modelId}`) return children.finish(runtime, task.input.key, { status: 'blocked', evidence: 'Effective adversary provider/model differs from the pinned route; verify actual provenance' }, context);
        const advReport = reports[index];
        const clean = reports.every(report => report.verdict !== 'BLOCK' && report.findings.length === 0);
        const evidence = JSON.stringify({ baseSha: task.input.baseSha, patchSha: task.input.patchSha, round: task.input.round, reports, receipts: results.map(result => result.evidence), decidingCode: 'complete' });
        const closed = await ledger().round(task.input.run, task.input.round);
        if (closed && closed.detail.export_id !== `review:${task.id}`) return children.finish(runtime, task.input.key, { status: 'blocked', evidence: 'Another owner closed this canonical round; keep these reviewer results and reconcile the ledger' }, context);
        await exportProof(`adversary:${task.id}`, { event: 'adversary_completed', run: task.input.run, detail: { mode: 'code_diff', verdict: advReport.verdict, accepted_findings: advReport.findings.map(finding => ({ finding: JSON.stringify(finding), blocking: advReport.verdict === 'BLOCK' })), rejected_findings: [], model_provenance: { requested: { family: family(adversary.model.provider), model: adversary.model.modelId, provider: adversary.model.provider, route: 'pi-durable' }, effective: { family: family(adversary.model.provider), model: adversary.model.modelId, provider: adversary.model.provider }, runner: 'pi-durable-owned-conversation', run_id: `${state.sessionId}:${task.id}:${task.state.checkpoint.children[index]}` } } }, task.input.files);
        await exportProof(`review:${task.id}`, { event: 'review_completed', run: task.input.run, detail: { status: clean ? 'GO' : 'BLOCK', review_round: task.input.round, round_outcome: clean ? 'clean' : 'findings', evidence } }, task.input.files);
        return children.finish(runtime, task.input.key, { status: clean ? 'passed' : 'blocked', evidence: `canonical round ${task.input.round}; input:${fingerprint(task.input)}; patch:${task.input.patchSha}`, data: evidence }, context);
      },
    },
    abort: (task, runtime, context) => children.finish(runtime, task.input.key, { status: 'cancelled', evidence: 'Review cancellation drained fresh reviewers; spent requests and canonical rounds retained' }, context),
  });
}
