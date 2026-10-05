import { test } from 'node:test';
import assert from 'node:assert/strict';
import { writeFile, readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { BACKGROUND_CONTEXT as ctx } from '@earendil-works/chord/context';
import { fauxAssistantMessage, fauxThinking, fauxText } from '@earendil-works/pi-ai/providers/faux';
import { Host } from '../host.ts';
import { State } from '../state.ts';
import { execute } from '../ledger.ts';
import { commandEffect } from '../guards.ts';
import { workspace, fixtureModels, processHost, until } from './helpers.ts';
import { InboxDoc } from '@earendil-works/pi-durable';

test('admitted busy messages retain the native steer and follow-up modes', async () => {
  const w = await workspace(); let release!: () => void;
  const barrier = new Promise<void>(resolve => { release = resolve; });
  const f = fixtureModels([async () => { await barrier; return fauxAssistantMessage('first'); }, fauxAssistantMessage('queued')]);
  const host = await Host.open({ dir: w.session, cwd: w.cwd, ...f });
  try {
    const view = await host.snapshot(); const binding = { session: view.sessionId, conversation: host.root.id };
    await host.admit('initial', { ...binding, text: 'initial', deliverAs: null });
    await until(() => host.snapshot(), snap => snap.state.workflow.budget.requests === 1);
    const steer = await host.admit('steer', { ...binding, text: 'steer exact', deliverAs: 'steer' });
    const follow = await host.admit('follow', { ...binding, text: 'follow exact', deliverAs: 'followUp' });
    const inbox = (await host.harness.snapshot(InboxDoc, host.root.id, ctx))!;
    assert.equal(inbox.items.find(item => item.id === steer.submissionId)?.mode, 'steer');
    assert.equal(inbox.items.find(item => item.id === follow.submissionId)?.mode, 'followUp');
    release(); await host.root.waitForIdle(ctx);
  } finally { release(); await host.close(); }
});

test('native admission preserves identity, exact text, usage and the public sequence after reopen', async () => {
  const w = await workspace(); const f = fixtureModels([fauxAssistantMessage([fauxThinking('private reasoning'), fauxText('visible')])]);
  let host = await Host.open({ dir: w.session, cwd: w.cwd, ...f });
  const state = (await host.harness.snapshot(State, ctx))!;
  const input = { session: state.sessionId, conversation: host.root.id, text: ' exact text ', deliverAs: null } as const;
  const first = await host.admit('stable-1', input);
  await host.root.waitForIdle(ctx);
  const before = await host.snapshot();
  assert.equal(before.state.workflow.budget.unknownRequests, 0);
  assert.equal(before.state.workflow.budget.requests, 1);
  assert.equal(JSON.stringify(before).includes('private reasoning'), false);
  await host.close();
  host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  try {
    const again = await host.admit('stable-1', input);
    assert.equal(again.submissionId, first.submissionId);
    assert.deepEqual(await host.snapshot(), before);
    await assert.rejects(host.admit('stable-1', { ...input, text: 'exact text' }), /reused/);
    await assert.rejects(host.admit('stable-1', { ...input, deliverAs: 'steer' }), /reused/);
    await assert.rejects(host.admit('stable-1', { ...input, conversation: 999 as typeof host.root.id }), /binding/);
  } finally { await host.close(); }
});

test('SIGKILL resumes a real SQLite owner with conserved unknown requests and no duplicated admission', async () => {
  const w = await workspace(); let p = await processHost(w, ['answer'], 30000);
  const input = { id: 'crash-input', session: p.ready.sessionId, conversation: p.ready.conversationId, text: 'resume me', deliverAs: null };
  const admitted = await p.rpc({ command: 'input', payload: input }) as { submissionId: number };
  await until(() => p.rpc({ command: 'state' }), value => (value as { state: { workflow: { budget: { requests: number } } } }).state.workflow.budget.requests === 1);
  await p.kill();
  p = await processHost(w);
  try {
    const again = await p.rpc({ command: 'input', payload: input }) as { submissionId: number };
    assert.equal(again.submissionId, admitted.submissionId);
    const view = await until(() => p.rpc({ command: 'state' }), value => !(value as { state: { streaming: boolean } }).state.streaming) as Awaited<ReturnType<Host['snapshot']>>;
    assert.equal(view.messages.filter(message => message.role === 'user').length, 1);
    assert.equal(view.state.workflow.budget.requests, 2);
    assert.equal(view.state.workflow.budget.unknownRequests, 1);
  } finally { await p.kill('SIGTERM'); }
});

test('kernel owner excludes a second host, recovers stale socket, and guardian loss fences the old host', async () => {
  const w = await workspace(); const first = await processHost(w);
  await assert.rejects(Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() }), /already has an owner/);
  const gone = new Promise<void>(resolve => first.child.once('exit', () => resolve()));
  process.kill(first.ready.guardianPid, 'SIGKILL'); await gone;
  assert.equal(first.child.exitCode, 74);
  const next = await processHost(w);
  await next.kill('SIGTERM');
});

test('native command receipts and absolute CI deadlines survive restart; completed cells are reused', async () => {
  const w = await workspace(); let host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  const argv = [process.execPath, '-e', 'process.stdout.write("measured")'];
  const effect = commandEffect(argv, w.cwd);
  await host.handle({ command: 'grant', payload: { key: 'measure', argv, expiresAt: Date.now() + 60000, evidence: 'local test authorization' } });
  const input = { key: 'cell-1', argv, grantId: 'measure', timeoutMs: 10000, files: {}, validation: false, run: null };
  const { taskId } = await host.start('command', input);
  const task = await host.harness.waitForTask(taskId, ctx);
  assert.equal(task.state.outcome.status, 'completed');
  assert.equal(task.state.outcome.status === 'completed' && task.state.outcome.result.status, 'passed');
  const checks = join(w.cwd, 'checks.json'); await writeFile(checks, JSON.stringify({ head: 'abc', checks: [] }));
  const wait = { key: 'ci', repo: 'fixture/repo', pr: 1, head: 'abc', deadline: Date.now() + 1000, intervalMs: 30000, fixture: checks };
  const pending = await host.start('wait', wait);
  await until(() => host.snapshot(), value => value.state.workflow.work.some(work => work.phase.startsWith('ci_wait:')));
  await host.close();
  await new Promise(resolve => setTimeout(resolve, 1100));
  await writeFile(checks, JSON.stringify({ head: 'abc', checks: [{ name: 'test', head: 'abc', state: 'SUCCESS' }] }));
  host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  try {
    assert.equal((await host.start('command', input)).taskId, taskId);
    const after = await host.harness.waitForTask(pending.taskId, ctx);
    assert.match(after.state.outcome.status === 'completed' ? after.state.outcome.result.evidence : '', /Original CI deadline/);
    const budget = (await host.harness.snapshot(State, ctx))!;
    assert.equal(Object.values(budget.attempts).filter(a => a.kind === 'command').length, 1);
    assert.equal(budget.grants.measure.action, effect.action);
    await assert.rejects(host.start('command', { ...input, argv: [process.execPath, '-e', '1'] }), /immutable/);
  } finally { await host.close(); }
});

test('canonical append-once returns the original terminal export and rejects changed payloads', async () => {
  const w = await workspace(); const host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  try {
    const event = { event: 'completed', run: 'receipt', detail: { summary: 'fixture complete' } };
    await host.ledger.export('same-terminal', event);
    await host.ledger.export('same-terminal', event);
    const text = await readFile(join(w.cwd, '.workflow/receipt/events.jsonl'), 'utf8');
    assert.equal(text.trim().split('\n').length, 1);
    await assert.rejects(host.ledger.export('same-terminal', { ...event, detail: { summary: 'different' } }), /collision/);
    await execute(join(host.ledger.repo, 'scripts/workflow-event'), ['--dir', join(w.cwd, '.workflow'), 'append', 'receipt', 'completed', JSON.stringify({ summary: 'fixture complete', export_id: 'same-terminal' })]);
    assert.equal((await readFile(join(w.cwd, '.workflow/receipt/events.jsonl'), 'utf8')).trim().split('\n').length, 1);
  } finally { await host.close(); }
});
