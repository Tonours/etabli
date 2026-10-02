import { test, mock } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { BACKGROUND_CONTEXT as ctx } from '@earendil-works/chord/context';
import { Host } from '../host.ts';
import { State } from '../state.ts';
import { executionMission } from '../missions.ts';
import { workspace, fixtureModels, until } from './helpers.ts';

test('handoff captures public progress and private recovery in one native transaction', async () => {
  const w = await workspace(); const host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  let reader: ReturnType<typeof mock.method> | undefined;
  try {
    const initial = await host.snapshot();
    await host.admit('handoff-budget', { session: initial.sessionId, conversation: host.root.id, text: 'Count this consumed request', deliverAs: null });
    await host.root.waitForIdle(ctx);
    await host.ledger.export('private-export-marker', { event: 'file_changed', run: 'handoff-proof', detail: { path: 'private-marker', change: 'isolated fixture' } });
    const argv = [process.execPath, '-e', "const fs=require('node:fs');fs.writeFileSync('started','once');const timer=setInterval(()=>{if(fs.existsSync('release'))clearInterval(timer)},10)"];
    await host.handle({ command: 'grant', payload: { key: 'handoff-grant', argv, consumer: 'handoff-cell', expiresAt: Date.now() + 30000, evidence: 'isolated handoff race fixture' } });
    const { taskId } = await host.start('command', { key: 'handoff-cell', argv, grantId: 'handoff-grant', timeoutMs: 20000, files: {}, validation: false, run: null });
    await until(async () => { try { return await readFile(join(w.cwd, 'started'), 'utf8'); } catch { return ''; } }, value => value === 'once');
    const read = host.harness.snapshot.bind(host.harness); let armed = true;
    reader = mock.method(host.harness, 'snapshot', async (...args: Parameters<typeof read>) => {
      const stored = await read(...args);
      if (Object.is(args[0], State) && armed) {
        armed = false;
        await writeFile(join(w.cwd, 'release'), 'release');
        await host.harness.waitForTask(taskId, ctx);
      }
      return stored;
    });
    const handoff = await host.handoff();
    const work = handoff.recovery.work.find(row => row.key === 'handoff-cell')!;
    assert.equal(work.result?.status ?? null, handoff.state.workflow.work.find(row => row.key === work.key)?.result ?? null, 'A task completed between reads: capture both views from the same transaction');
    const attempts = Object.values(handoff.recovery.attempts);
    assert.equal(handoff.state.workflow.budget.requests, 1);
    assert.equal(handoff.state.workflow.budget.tokens, attempts.reduce((n, attempt) => n + attempt.tokens, 0));
    assert.equal(handoff.state.workflow.budget.cost, attempts.reduce((n, attempt) => n + attempt.cost, 0));
    assert.equal(handoff.state.workflow.budget.unknownRequests, attempts.reduce((n, attempt) => n + attempt.requests - attempt.resolvedRequests, 0));
    assert.deepEqual(handoff.state.workflow.unresolvedEffects, Object.values(handoff.recovery.effects).filter(effect => effect.status === 'uncertain').map(effect => ({ taskId: effect.taskId, action: effect.action })));
    assert.equal(handoff.recovery.exports['private-export-marker'].acknowledged, true);
    assert.equal(handoff.state.workflow.doNotRedo.includes(work.key), work.result?.status === 'passed');
    reader.mock.restore(); reader = undefined;
    const publicView = await host.snapshot();
    assert.equal('recovery' in publicView, false);
    assert.equal(JSON.stringify(publicView).includes('private-export-marker'), false);
    await writeFile(join(w.cwd, 'release'), 'release');
    await host.harness.waitForTask(taskId, ctx);
  } finally {
    reader?.mock.restore();
    await writeFile(join(w.cwd, 'release'), 'release');
    await host.close();
  }
});

test('native review route retains the latest actual mission authority', async () => {
  const w = await workspace(); const host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  const deadline = Date.now() + 30000;
  try {
    for (const route of ['ship', 'goal', 'plan-implement'] as const) {
      const run = `route-${route}`;
      await host.ledger.export(`route:${route}`, { event: 'route_decided', run, detail: { route, reason: 'isolated mission authority fixture' } });
      if (route === 'ship') await assert.rejects(executionMission(w.cwd, null, deadline, run), /recorded parent manifest/);
      await host.ledger.round(run, 'T1');
      if (route === 'ship') await assert.rejects(executionMission(w.cwd, null, deadline, run), /recorded parent manifest/, 'Native review must preserve ship parent authority');
      else assert.deepEqual(await executionMission(w.cwd, null, deadline, run), { route, run, deadline });
      await host.ledger.export(`real-reroute:${route}`, { event: 'route_decided', run, detail: { route: 'review', contract_path: 'pi/durable', reason: 'a genuine later route change' } });
      assert.equal(await executionMission(w.cwd, null, deadline, run), null, 'Only the native review issuer is ignored');
    }
  } finally { await host.close(); }
});

test('group cancellation during the old private read retains coherent results and budgets', async () => {
  const w = await workspace(); const host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  let reader: ReturnType<typeof mock.method> | undefined;
  try {
    const checks = join(w.cwd, 'checks'); await writeFile(checks, JSON.stringify({ head: 'abc', checks: [] }));
    const deadline = Date.now() + 30000;
    const { taskId } = await host.start('group', { key: 'cancel-parent', kind: 'campaign', route: null, run: null, objective: "fixture", maxAttempts: 1, deadline, steps: [
      { name: 'wait', kind: 'wait', dependsOn: [], input: { key: 'cancel-wait', repo: 'fixture/repo', pr: 1, head: 'abc', deadline, intervalMs: 100, fixture: checks } },
    ] });
    await until(() => host.snapshot(), view => view.state.workflow.work.some(work => work.key === 'cancel-wait' && work.phase.startsWith('ci_wait:')));
    const before = await host.snapshot(); const read = host.harness.snapshot.bind(host.harness); let armed = true;
    reader = mock.method(host.harness, 'snapshot', async (...args: Parameters<typeof read>) => {
      const stored = await read(...args);
      if (Object.is(args[0], State) && armed) { armed = false; await host.harness.abortTask(taskId, ctx); await host.harness.waitForTask(taskId, ctx); }
      return stored;
    });
    const handoff = await host.handoff();
    for (const work of handoff.recovery.work) assert.equal(work.result?.status ?? null, handoff.state.workflow.work.find(row => row.key === work.key)?.result ?? null, 'Cancellation must not mix private pending and public cancelled');
    assert.deepEqual(handoff.state.workflow.budget, before.state.workflow.budget);
    reader.mock.restore(); reader = undefined;
    await host.harness.abortTask(taskId, ctx); await host.harness.waitForTask(taskId, ctx);
    const cancelled = await host.handoff();
    assert.equal(cancelled.recovery.work.find(work => work.key === 'cancel-parent')?.result?.status, 'cancelled');
    assert.equal(cancelled.state.workflow.doNotRedo.includes('cancel-parent'), false);
    assert.equal((await host.snapshot()).seq, cancelled.seq, 'Private recovery must not change the public sequence');
    assert.deepEqual(cancelled.state.workflow.budget, before.state.workflow.budget);
  } finally { reader?.mock.restore(); await host.close(); }
});

test('native terminal failure after reconciliation is reconciled in the handoff transaction', async () => {
  const w = await workspace(); const host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels(), resume: false });
  const pause = mock.method(host.harness, 'resume', () => {});
  let writer: ReturnType<typeof mock.method> | undefined;
  try {
    const { taskId } = await host.start('group', { key: 'failed-parent', kind: 'campaign', route: null, run: null, objective: "fixture", maxAttempts: 1, deadline: Date.now() + 30000, steps: [
      { name: 'invalid-input', kind: 'agent', dependsOn: [], input: { key: 'failed-cell', prompt: 'Never run', role: 'reviewer', model: null, files: { missing: 'a'.repeat(64) }, review: false } },
    ] });
    const commit = host.harness.commit.bind(host.harness); let armed = true;
    writer = mock.method(host.harness, 'commit', async (...args: Parameters<typeof commit>) => {
      const result = await commit(...args);
      if (armed) { armed = false; pause.mock.restore(); host.harness.resume(); await host.harness.waitForTask(taskId, ctx); }
      return result;
    });
    const handoff = await host.handoff();
    assert.equal(handoff.recovery.work.find(work => work.key === 'failed-parent')?.result?.status ?? null, handoff.state.workflow.work.find(work => work.key === 'failed-parent')?.result ?? null, 'Reconcile terminal failures inside the shared transaction');
    writer.mock.restore(); writer = undefined;
    const failed = await host.handoff();
    assert.equal(failed.recovery.work.find(work => work.key === 'failed-parent')?.result?.status, 'failed');
    assert.equal(failed.state.workflow.work.find(work => work.key === 'failed-parent')?.result, 'failed');
    assert.equal(failed.state.workflow.budget.requests, 0);
    assert.equal(Object.keys(failed.recovery.attempts).length, 0);
    assert.equal(failed.state.workflow.doNotRedo.includes('failed-parent'), false);
  } finally { writer?.mock.restore(); pause.mock.restore(); await host.close(); }
});
