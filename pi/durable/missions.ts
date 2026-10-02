import { join } from 'node:path';
import { ledgerEvents, ledgerHash, execute, type Ledger } from './ledger.ts';
import { readChecks, type GroupInput, type Step } from './tasks.ts';
import { planReady, commandEffect } from './guards.ts';
import { selectActiveLedger } from '../../scripts/lib/ledger-integrity.mjs';
import { State, fingerprint, type MissionContext } from './state.ts';
import { BACKGROUND_CONTEXT } from '@earendil-works/chord/context';
import type { TaskId } from '@earendil-works/pi-durable';

export function stepMission(parent: number, input: GroupInput, step: Step): MissionContext | null {
  if (!input.route || !input.run) return null;
  const ancestors = new Set<string>();
  function visit(name: string) {
    if (ancestors.has(name)) return;
    ancestors.add(name);
    for (const dependency of input.steps.find(item => item.name === name)!.dependsOn) visit(dependency);
  }
  for (const dependency of step.dependsOn) visit(dependency);
  return { route: input.route, run: input.run, deadline: input.deadline, parent, step: step.name, waits: input.steps.flatMap(item => item.kind === 'wait' && ancestors.has(item.name) ? [item.input] : []) };
}

export async function publicationMission(ledger: Ledger, id: number, input: { key: string; run: string | null; mission?: MissionContext | null }) {
  const task = await ledger.harness.getTask(id as TaskId, BACKGROUND_CONTEXT);
  const parent = task?.owner ? await ledger.harness.getTask(task.owner, BACKGROUND_CONTEXT) : null;
  if (!parent || parent.kind !== 'etabli.group') throw new Error('Publication requires a recorded parent manifest step');
  const group = parent.input as GroupInput;
  const step = group.steps.find(item => item.kind === 'command' && item.input.key === input.key);
  const mission = step && stepMission(parent.id, group, step);
  if (!mission || input.run !== mission.run || fingerprint(input.mission) !== fingerprint(mission)) throw new Error('Publication mission differs from its recorded parent authority');
  return mission;
}

export function mutationRun(cwd: string, mission: MissionContext | null | undefined, run?: string | null) {
  if (mission) {
    if (Date.now() >= mission.deadline) throw new Error('Mission reached its original deadline before mutation');
    return mission.run;
  }
  if (run) return run;
  const selected = selectActiveLedger(cwd);
  if (selected.reason) throw new Error(`Cannot bind mutation to the canonical mission: ${selected.reason}`);
  return selected.ledger?.run ?? null;
}

export async function executionMission(cwd: string, mission: MissionContext | null | undefined, deadline: number, run?: string | null): Promise<MissionContext | null> {
  if (mission) { mutationRun(cwd, mission); return mission; }
  const selected = run ?? mutationRun(cwd, null);
  if (!selected) return null;
  const route = (await ledgerEvents(cwd, selected)).findLast(event => event.event === 'route_decided' && !(event.detail.route === 'review' && event.detail.contract_path === 'pi/durable' && event.detail.export_id === `review-route:${selected}`))?.detail.route;
  if (route === 'ship') throw new Error('Ship authority requires its recorded parent manifest, waits and original deadline');
  return ['goal', 'plan-implement', 'ship'].includes(String(route)) ? { route: route as MissionContext['route'], run: selected, deadline } : null;
}

export async function currentWaits(waits: NonNullable<MissionContext['waits']>) {
  for (const input of waits) {
    const checks = await readChecks(input);
    if (Date.now() >= input.deadline || checks.head !== input.head || !checks.checks.length || checks.checks.some(check => check.head !== input.head || !['SUCCESS', 'NEUTRAL', 'SKIPPED'].includes(check.state))) throw new Error('Decision requires current HEAD/checks within the original CI deadline');
  }
}

export async function recordMutation(ledger: Ledger, id: string, run: string | null, path: string, change: string) {
  if (run) await ledger.export(id, { event: 'file_changed', run, detail: { path, change } });
}

export function validateMission(input: GroupInput) {
  if (!input.route) return;
  if (!input.run || !input.objective?.trim()) throw new Error('Mission requires a canonical run and concrete objective');
  if (!input.steps.some(step => step.kind === 'command' && step.input.validation && step.input.run === input.run)) throw new Error('Mission requires a run-bound executable validation');
  if (input.route === 'ship' && !input.steps.some(step => step.kind === 'wait')) throw new Error('Ship requires a target-bound fresh PR/CI wait');
}

export async function missionGate(input: Pick<GroupInput, 'route' | 'run'> & { waits?: MissionContext['waits'] }, step: Step, cwd: string) {
  if (!input.route || !input.run) return;
  if (step.kind === 'command' && step.input.validation && step.input.run !== input.run) throw new Error('Validation targets a different canonical mission');
  if (input.route === 'plan-implement' && (step.name === 'implement' || (step.kind === 'agent' && step.input.role === 'writer') || (step.kind === 'command' && !step.input.validation))) {
    await planReady(cwd);
    const events = await ledgerEvents(cwd, input.run);
    const plan = events.findLast(event => event.event === 'adversary_completed' && event.detail.mode === 'plan');
    if (plan?.detail.verdict !== 'READY') throw new Error('Implementation requires the canonical independent plan adversary READY receipt');
  }
  if (step.name === 'publish' || step.name === 'ship' || (step.kind === 'command' && ['git.push', 'github.pr.create'].includes(commandEffect(step.input.argv, cwd).action))) {
    const events = await ledgerEvents(cwd, input.run);
    const review = events.findLast(event => event.event === 'review_completed');
    if (!['GO', 'GO WITH NOTES'].includes(String(review?.detail.status))) throw new Error('Publishing requires the latest canonical review to be non-blocking');
    const changed = events.findLastIndex(event => event.event === 'file_changed');
    const reviewed = events.findLastIndex(event => event.event === 'review_completed');
    if (reviewed <= changed) throw new Error('Publishing review predates the last canonical file change');
    if (input.waits) await currentWaits(input.waits);
  }
}

export async function missionComplete(input: GroupInput, ledger: Ledger, taskId: number) {
  if (!input.route || !input.run) return;
  if (input.route === 'ship') {
    await currentWaits(input.steps.flatMap(step => step.kind === 'wait' ? [step.input] : []));
    await execute(join(ledger.repo, 'scripts/workflow-event'), ['--dir', join(ledger.cwd, '.workflow'), 'validate', input.run, '--profile', 'ship-completed']);
    return;
  }
  const event = { event: 'completed', run: input.run, detail: { summary: input.objective } };
  const identity = new RegExp(`^completed:${taskId}(?::[a-f0-9]{64})?$`);
  const pending = Object.entries((await ledger.harness.snapshot(State, BACKGROUND_CONTEXT))?.exports ?? {}).filter(([id]) => identity.test(id));
  for (const [id, item] of pending) {
    if (fingerprint([item.event, item.run, item.detail]) !== fingerprint([event.event, event.run, { ...event.detail, export_id: id }])) throw new Error('Mission completion differs from its recorded export');
    if (await ledger.hasReceipt(id)) { await ledger.flush(id); return; }
  }
  for (const [id, item] of pending) if (!item.acknowledged && !item.abandoned) {
    try { await ledger.flush(id); return; }
    catch (error) { if (!(error instanceof Error) || !error.message.includes('ledger precondition changed')) throw error; }
  }
  const expected = await ledgerHash(ledger.cwd, input.run);
  if (input.route === 'plan-implement') {
    await execute(join(ledger.repo, 'scripts/workflow-event'), ['--dir', join(ledger.cwd, '.workflow'), 'check-completion', input.run, JSON.stringify({ summary: input.objective })], { cwd: ledger.cwd });
  } else {
    await ledger.validate(input.run);
    const events = await ledgerEvents(ledger.cwd, input.run);
    const changed = events.findLastIndex(event => event.event === 'file_changed');
    const validations = events.slice(changed + 1).filter(event => event.event === 'validation_run' || event.event === 'validation_failed');
    const latest = new Map(validations.map(event => [String(event.detail.command), event]));
    if (!latest.size || [...latest.values()].some(event => event.event !== 'validation_run' || event.detail.exit !== 0)) throw new Error('Goal success needs every current canonical validation to pass after the latest file change');
  }
  if (await ledgerHash(ledger.cwd, input.run) !== expected) throw new Error('Canonical evidence changed during completion evaluation; retry against current receipts');
  await ledger.export(`completed:${taskId}:${expected}`, event, expected);
}
