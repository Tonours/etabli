import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { BACKGROUND_CONTEXT as ctx } from '@earendil-works/chord/context';
import type { TaskId } from '@earendil-works/pi-durable';
import { fauxAssistantMessage, type FauxResponseFactory } from '@earendil-works/pi-ai/providers/faux';
import { Host } from '../host.ts';
import { workspace, fixtureModels, processHost, until } from './helpers.ts';
import { egress, assertReadable } from '../egress.ts';
import type { GroupInput } from '../tasks.ts';
import { commandReceipt, type CommandInput } from '../commands.ts';

test('native compaction task survives SIGKILL with one controller and conserved request reservations', async () => {
  const w = await workspace(); let p = await processHost(w, ['first response', 'second response', { text: 'summary', delayMs: 30000 }]);
  const binding = { session: p.ready.sessionId, conversation: p.ready.conversationId, deliverAs: null };
  for (let i = 0; i < 2; i++) {
    await p.rpc({ command: 'input', payload: { ...binding, id: `long-${i}`, text: 'context '.repeat(500) } });
    await until(() => p.rpc({ command: 'state' }), value => !(value as Awaited<ReturnType<Host['snapshot']>>).state.streaming);
  }
  const compact = await p.rpc({ command: 'compact', payload: { key: 'compact-1' } }) as { taskId: number };
  await until(() => p.rpc({ command: 'state' }), value => (value as Awaited<ReturnType<Host['snapshot']>>).state.workflow.budget.requests === 3);
  await p.kill(); p = await processHost(w, ['recovered summary']);
  try {
    const same = await p.rpc({ command: 'compact', payload: { key: 'compact-1' } }) as { taskId: number };
    assert.equal(same.taskId, compact.taskId);
    const task = await until(() => p.rpc({ command: 'task', payload: { id: compact.taskId } }), value => (value as { state: { status: string } }).state.status === 'terminal') as { state: { outcome: { status: string } } };
    assert.equal(task.state.outcome.status, 'completed');
    const view = await p.rpc({ command: 'handoff' }) as Awaited<ReturnType<Host['snapshot']>>;
    assert.equal(view.state.workflow.compactions.length, 1);
    assert.equal(view.state.workflow.budget.requests, 4);
    assert.equal(view.state.workflow.budget.unknownRequests, 1);
    assert.ok(view.messages.some(message => message.text.includes('recovered summary')));
  } finally { await p.kill('SIGTERM'); }
});

test('generation and compaction share provider policy and sensitive-text filtering', async () => {
  const w = await workspace(); const seen: string[] = [];
  const answer: FauxResponseFactory = async context => {
    seen.push(JSON.stringify(context.messages)); return fauxAssistantMessage('summary or answer');
  };
  const f = fixtureModels([answer, answer, answer]);
  const host = await Host.open({ dir: w.session, cwd: w.cwd, ...f });
  try {
    const state = await host.snapshot();
    for (let i = 0; i < 2; i++) { await host.admit(`sensitive-${i}`, { session: state.sessionId, conversation: host.root.id, text: 'sk-abcdefghijklmnopqrstuv ' + 'history '.repeat(300), deliverAs: null }); await host.root.waitForIdle(ctx); }
    const compact = await host.compact('filtered'); await host.harness.waitForTask(compact.taskId as TaskId, ctx);
    assert.equal(seen.length, 3);
    assert.ok(seen.every(request => !request.includes('sk-abcdefghijklmnopqrstuv')));
    assert.throws(() => egress('forbidden', ['faux'], []), /outside/);
    assert.throws(() => assertReadable(join(w.cwd, 'capability'), w.cwd), /Credential/);
  } finally { await host.close(); }
});

test('campaign cell receipts retain failed measurements and consumed population across restart', async () => {
  const w = await workspace(); let p = await processHost(w);
  const population = [0, 1].map(index => ({ key: `measure-${index}`, argv: [process.execPath, '-e', index === 0 ? 'process.stdout.write(JSON.stringify({score:3}))' : "require('node:fs').writeFileSync('measurement-started','once');setTimeout(()=>process.exit(2),30000)"], grantId: `grant-${index}`, timeoutMs: 60000, files: {}, validation: false, run: null }));
  for (const input of population) await p.rpc({ command: 'grant', payload: { key: input.grantId, argv: input.argv, expiresAt: Date.now() + 120000, evidence: 'authorized test measurement' } });
  const group: GroupInput = { key: 'population-1', kind: 'campaign', route: null, run: null, objective: 'two frozen measurements', maxAttempts: 2, deadline: Date.now() + 120000, steps: population.map((input, index) => ({ name: `cell-${index}`, dependsOn: index ? ['cell-0'] : [], kind: 'command', input })) };
  const started = await p.rpc({ command: 'campaign', payload: group }) as { taskId: number };
  await until(() => p.rpc({ command: 'state' }), value => {
    const view = value as Awaited<ReturnType<Host['snapshot']>>;
    return view.state.workflow.doNotRedo.includes('measure-0') && view.state.workflow.work.find(work => work.key === 'measure-1')?.phase === 'execute';
  });
  await until(async () => { try { return await readFile(join(w.cwd, 'measurement-started'), 'utf8'); } catch { return ''; } }, value => value === 'once');
  const before = await p.rpc({ command: 'state' }) as Awaited<ReturnType<Host['snapshot']>>;
  const cell = before.state.workflow.work.find(work => work.key === 'measure-1')!;
  const recorded = await p.rpc({ command: 'task', payload: { id: cell.taskId } }) as { input: CommandInput };
  await p.kill();
  const receipt = await until(() => commandReceipt(w.session, cell.taskId, recorded.input), Boolean);
  assert.equal(receipt!.interrupted, true, 'Restart fixture must await an actual interrupted worker receipt, not the earlier execute checkpoint');
  p = await processHost(w);
  try {
    await until(() => p.rpc({ command: 'task', payload: { id: started.taskId } }), value => (value as { state: { status: string } }).state.status === 'terminal');
    const parent = await p.rpc({ command: 'task', payload: { id: started.taskId } }) as { state: { checkpoint?: { attempts: number }; outcome: { result: { status: string; data: string } } } };
    assert.equal(parent.state.outcome.result.status, 'blocked');
    const results = JSON.parse(parent.state.outcome.result.data) as Record<string, { status: string; data?: string }>;
    assert.equal(results['cell-0'].status, 'passed');
    assert.match(results['cell-0'].data ?? '', /score/);
    assert.equal(results['cell-1'].status, 'failed');
    assert.equal((await p.rpc({ command: 'campaign', payload: group }) as { taskId: number }).taskId, started.taskId);
  } finally { await p.kill('SIGTERM'); }
});

test('fresh CI reads distinguish changed HEAD and unavailable checks at the retained deadline', async () => {
  const w = await workspace(); const host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  try {
    const path = join(w.cwd, 'checks'); await writeFile(path, JSON.stringify({ head: 'new', checks: [{ name: 'old checks', head: 'old', state: 'SUCCESS' }] }));
    const base = { key: 'changed', repo: 'a/b', pr: 1, head: 'old', deadline: Date.now() + 30000, intervalMs: 20, fixture: path };
    const changed = await host.harness.waitForTask((await host.start('wait', base)).taskId, ctx);
    assert.match(changed.state.outcome.status === 'completed' ? changed.state.outcome.result.evidence : '', /HEAD changed/);
    const unavailable = await host.harness.waitForTask((await host.start('wait', { ...base, key: 'unavailable', fixture: join(w.cwd, 'missing'), deadline: Date.now() - 1 })).taskId, ctx);
    assert.match(unavailable.state.outcome.status === 'completed' ? unavailable.state.outcome.result.evidence : '', /unavailable at the original deadline/);
  } finally { await host.close(); }
});
