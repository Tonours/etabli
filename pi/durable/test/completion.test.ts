import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { spawn } from 'node:child_process';
import { BACKGROUND_CONTEXT as ctx } from '@earendil-works/chord/context';
import type { TaskId } from '@earendil-works/pi-durable';
import { Host } from '../host.ts';
import { State, type Result } from '../state.ts';
import { execute, ledgerEvents, ledgerHash, type LedgerEvent } from '../ledger.ts';
import { missionComplete } from '../missions.ts';
import type { GroupInput, GroupState } from '../tasks.ts';
import { control } from '../cli.ts';
import { workspace, fixtureModels, until } from './helpers.ts';

const mission = (run: string): GroupInput => ({ key: 'parent', kind: 'mission', route: 'goal', run, objective: 'current evidence completes once', steps: [], maxAttempts: 0, deadline: Date.now() + 60000 });
const validation = (run: string): LedgerEvent => ({ event: 'validation_run', run, detail: { command: 'completion fixture validation', exit: 0 } });

async function proof(host: Host, run: string) {
  await host.ledger.export('route', { event: 'route_decided', run, detail: { route: 'goal', reason: 'isolated completion regression' } });
  await host.ledger.export('validation', validation(run));
}

test('a receipt during completion evaluation is retried against fresh canonical bytes', async () => {
  const w = await workspace(); const host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  try {
    await proof(host, 'proof');
    const validate = host.ledger.validate.bind(host.ledger);
    let injected = false;
    host.ledger.validate = async run => {
      if (!injected) { injected = true; await host.ledger.export('late', validation(run)); }
      await validate(run);
    };
    await assert.rejects(missionComplete(mission('proof'), host.ledger, 91), /changed|precondition/);
    assert.equal(Object.keys((await host.harness.snapshot(State, ctx))!.exports).some(id => id.startsWith('completed:')), false, 'mixed evidence must not create a terminal intent');
    await missionComplete(mission('proof'), host.ledger, 91);
    assert.equal((await ledgerEvents(w.cwd, 'proof')).filter(event => event.event === 'completed').length, 1);
  } finally { await host.close(); }
});

async function planEvidence(host: Host, run: string) {
  const provenance = { requested: { family: 'anthropic', model: 'fixture', provider: 'faux' }, effective: { family: 'anthropic', model: 'fixture', provider: 'faux' }, runner: 'local-fixture', run_id: 'completion-plan-fixture' };
  const events: LedgerEvent[] = [
    { event: 'plan_created', run, detail: { path: 'PLAN.md', status: 'READY' } },
    { event: 'adversary_completed', run, detail: { mode: 'plan', verdict: 'READY', accepted_findings: [], rejected_findings: [], model_provenance: provenance } },
    { event: 'file_changed', run, detail: { path: 'fixture', change: 'isolated baseline' } },
    { event: 'simplification_completed', run, detail: { status: 'clean', evidence: 'fixture' } },
    { event: 'quality_completed', run, detail: { status: 'pass', evidence: 'fixture siblings' } },
    { event: 'adversary_completed', run, detail: { mode: 'code_diff', verdict: 'GO', accepted_findings: [], rejected_findings: [], model_provenance: provenance } },
    { event: 'review_completed', run, detail: { status: 'GO', evidence: 'isolated canonical profile fixture, no provider quality claim' } },
    { event: 'archive_written', run, detail: { path: 'docs/plan/fixture.md' } },
    { event: 'plan_removed', run, detail: { path: 'PLAN.md' } },
  ];
  for (const [index, event] of events.entries()) await host.ledger.export(`plan-proof:${index}`, event);
}

async function crashedGroup(route: 'goal' | 'plan-implement', window: 'stale' | 'ack') {
  const w = await workspace(); const marker = join(w.dir, 'before-crash.json');
  const argv = [process.execPath, '-e', 'process.stdout.write("completion validated")'];
  const input: GroupInput = { ...mission('proof'), route, deadline: Date.now() + 20000, maxAttempts: 2, steps: [
    { name: 'measure', kind: 'agent', dependsOn: [], input: { key: 'measure', prompt: 'record a result once', role: 'reviewer', model: null, files: {}, review: false } },
    { name: 'validate', kind: 'command', dependsOn: ['measure'], input: { key: 'validate', argv, grantId: 'validate', timeoutMs: 10000, files: {}, validation: true, run: 'proof' } },
  ] };
  if (route === 'plan-implement') {
    const setup = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
    await planEvidence(setup, 'proof'); await setup.close();
  }
  const worker = `
    import { Host } from ${JSON.stringify(new URL('../host.ts', import.meta.url).href)};
    import { fixtureModels } from ${JSON.stringify(new URL('./helpers.ts', import.meta.url).href)};
    import { State } from ${JSON.stringify(new URL('../state.ts', import.meta.url).href)};
    import { BACKGROUND_CONTEXT as ctx } from '@earendil-works/chord/context';
    import { writeFile, rename } from 'node:fs/promises';
    const host = await Host.open({dir:${JSON.stringify(w.session)},cwd:${JSON.stringify(w.cwd)},...fixtureModels()});
    await host.listen();
    await host.handle({command:'grant',payload:{key:'validate',argv:${JSON.stringify(argv)},expiresAt:Date.now()+60000,evidence:'isolated completion fixture'}});
    const flush = host.ledger.flush.bind(host.ledger);
    let injected = false;
    host.ledger.flush = async id => {
      if (!id.startsWith('completed:') || injected) return flush(id);
      injected = true;
      if (${JSON.stringify(window)} === 'stale') await host.ledger.export('concurrent',${JSON.stringify(validation('proof'))});
      let failure;
      try { await flush(id); } catch (error) { failure=error; }
      const task=await host.harness.getTask(Number(id.split(':')[1]),ctx);
      const state=await host.harness.snapshot(State,ctx);
      await writeFile(${JSON.stringify(marker + '.tmp')},JSON.stringify({taskId:task.id,checkpoint:task.state.checkpoint,inputDeadline:task.input.deadline,requests:state.requests,maxRequests:state.maxRequests,runtimeDeadline:state.deadline,exports:state.exports}));
      await rename(${JSON.stringify(marker + '.tmp')},${JSON.stringify(marker)});
      if (${JSON.stringify(window)} === 'ack') process.kill(process.pid,'SIGKILL');
      if (failure) throw failure;
    };
    await host.start('group',${JSON.stringify(input)});
  `;
  const child = spawn(process.execPath, ['--input-type=module', '-e', worker], { cwd: new URL('../', import.meta.url), stdio: ['ignore', 'ignore', 'pipe'] });
  let stderr = ''; child.stderr.on('data', bytes => { stderr += bytes; });
  const exited = new Promise<NodeJS.Signals | null>((resolve, reject) => { child.once('error', reject); child.once('exit', (_code, signal) => resolve(signal)); });
  let host: Host | undefined;
  try {
    const before = await until(async () => {
      try { return JSON.parse(await readFile(marker, 'utf8')) as { taskId: TaskId<Result>; checkpoint: GroupState; inputDeadline: number; requests: number; maxRequests: number; runtimeDeadline: number; exports: Record<string, { acknowledged: boolean; precondition: string }> }; }
      catch (error) { if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error; return null; }
    }, value => value !== null);
    assert.ok(before, stderr);
    if (window === 'stale') {
      await until(() => control(w.session, { command: 'state' }), value => (value as Awaited<ReturnType<Host['snapshot']>>).state.workflow.work.some(work => work.key === input.key && work.phase === 'awaiting_evidence'));
      child.kill('SIGKILL');
    }
    assert.equal(await exited, 'SIGKILL', stderr);
    host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
    const done = await host.harness.waitForTask(before.taskId, ctx);
    assert.equal(done.state.outcome.status === 'completed' && done.state.outcome.result.status, 'passed', JSON.stringify(done.state.outcome));
    const task = await host.harness.getTask(before.taskId, ctx);
    assert.equal((task!.input as GroupInput).deadline, before.inputDeadline);
    const state = (await host.harness.snapshot(State, ctx))!;
    assert.equal(state.requests, before.requests); assert.equal(state.requests, 1);
    assert.equal(state.maxRequests, before.maxRequests); assert.equal(state.deadline, before.runtimeDeadline);
    assert.equal(before.checkpoint.attempts, 2);
    for (const [name, id] of Object.entries(before.checkpoint.children)) {
      assert.equal(state.work[name].taskId, id); assert.equal(state.work[name].result?.status, 'passed');
      assert.deepEqual(state.work[name].result, before.checkpoint.results[name]);
    }
    assert.equal((await ledgerEvents(w.cwd, 'proof')).filter(event => event.event === 'completed').length, 1);
    const stale = Object.entries(before.exports).find(([id]) => id.startsWith('completed:'))!;
    if (window === 'stale') {
      assert.equal(state.exports[stale[0]].acknowledged, false);
      assert.equal(state.exports[stale[0]].precondition, stale[1].precondition);
      assert.ok(Object.entries(state.exports).some(([id, item]) => id !== stale[0] && item.event === 'completed' && item.acknowledged));
    } else assert.equal(state.exports[stale[0]].acknowledged, true);
  } finally {
    if (child.exitCode === null && child.signalCode === null) { child.kill('SIGKILL'); await exited; }
    await host?.close();
  }
}

test('a stale completion intent survives SIGKILL and fresh evidence finishes without replaying children', async () => {
  await crashedGroup('goal', 'stale');
});

test('goal and plan groups recover SIGKILL after ACK before their terminal commit', async () => {
  await crashedGroup('goal', 'ack');
  await crashedGroup('plan-implement', 'ack');
});

test('abandoned completion waits on unchanged evidence and permits a new hash after a receipt', async () => {
  const w = await workspace(); let host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  try {
    await proof(host, 'proof'); const hash = await ledgerHash(w.cwd, 'proof');
    const flush = host.ledger.flush.bind(host.ledger);
    host.ledger.flush = async () => { throw new Error('before append'); };
    await assert.rejects(missionComplete(mission('proof'), host.ledger, 91), /before append/);
    host.ledger.flush = flush;
    const id = Object.keys((await host.harness.snapshot(State, ctx))!.exports).find(id => id.startsWith('completed:'))!;
    await host.ledger.abandon(id, 'human abandoned this evaluated intent');
    await host.close(); host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
    await assert.rejects(missionComplete(mission('proof'), host.ledger, 91), /abandoned/);
    assert.equal((await ledgerEvents(w.cwd, 'proof')).some(event => event.event === 'completed'), false);
    assert.equal(await ledgerHash(w.cwd, 'proof'), hash);
    await host.ledger.export('new-evidence', validation('proof'));
    await missionComplete(mission('proof'), host.ledger, 91);
    const state = (await host.harness.snapshot(State, ctx))!;
    assert.ok(state.exports[id].abandoned); assert.equal(state.exports[id].acknowledged, false);
    assert.equal(Object.values(state.exports).filter(item => item.event === 'completed').length, 2);
  } finally { await host.close(); }
});

test('canonical legacy completion wins over lost ACK abandonment and task identity prefixes stay distinct', async () => {
  const w = await workspace(); const host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  try {
    await proof(host, 'proof');
    const flush = host.ledger.flush.bind(host.ledger);
    host.ledger.flush = async id => {
      const item = (await host.harness.snapshot(State, ctx))!.exports[id];
      await execute(join(host.ledger.repo, 'scripts/workflow-event'), ['--dir', join(w.cwd, '.workflow'), 'append', item.run, item.event, JSON.stringify(item.detail)]);
      throw new Error('lost ACK');
    };
    await assert.rejects(host.ledger.export('completed:12', { event: 'completed', run: 'proof', detail: { summary: mission('proof').objective } }), /lost ACK/);
    host.ledger.flush = flush;
    await host.ledger.abandon('completed:12', 'abandoned before observing the committed receipt');
    await assert.rejects(missionComplete(mission('proof'), host.ledger, 1), /terminal/);
    assert.equal((await host.harness.snapshot(State, ctx))!.exports['completed:12'].acknowledged, false);
    await missionComplete(mission('proof'), host.ledger, 12);
    const item = (await host.harness.snapshot(State, ctx))!.exports['completed:12'];
    assert.equal(item.acknowledged, true); assert.ok(item.abandoned);
    assert.equal((await ledgerEvents(w.cwd, 'proof')).filter(event => event.event === 'completed').length, 1);
  } finally { await host.close(); }
});

test('a matching committed receipt cannot bypass canonical ledger validation', async () => {
  const w = await workspace(); const host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  try {
    await proof(host, 'proof');
    const flush = host.ledger.flush.bind(host.ledger);
    host.ledger.flush = async id => {
      const item = (await host.harness.snapshot(State, ctx))!.exports[id];
      await execute(join(host.ledger.repo, 'scripts/workflow-event'), ['--dir', join(w.cwd, '.workflow'), 'append', item.run, item.event, JSON.stringify(item.detail)]);
      throw new Error('lost ACK');
    };
    await assert.rejects(missionComplete(mission('proof'), host.ledger, 91), /lost ACK/);
    host.ledger.flush = flush;
    const id = Object.keys((await host.harness.snapshot(State, ctx))!.exports).find(id => id.startsWith('completed:'))!;
    const path = join(w.cwd, '.workflow', 'proof', 'events.jsonl');
    const rows = (await readFile(path, 'utf8')).trim().split('\n').map(line => JSON.parse(line));
    rows[0].ts = 'invalid fixture timestamp';
    await writeFile(path, rows.map(row => JSON.stringify(row)).join('\n') + '\n');
    await assert.rejects(missionComplete(mission('proof'), host.ledger, 91), /invalid ledger/);
    assert.equal((await host.harness.snapshot(State, ctx))!.exports[id].acknowledged, false);
  } finally { await host.close(); }
});
