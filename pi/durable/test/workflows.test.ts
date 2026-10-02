import { test } from 'node:test';
import assert from 'node:assert/strict';
import { writeFile, readFile, stat } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { join } from 'node:path';
import { BACKGROUND_CONTEXT as ctx } from '@earendil-works/chord/context';
import { fauxAssistantMessage, fauxToolCall } from '@earendil-works/pi-ai/providers/faux';
import { AgentDoc } from '@earendil-works/pi-durable';
import { Host } from '../host.ts';
import { State, Role, type Result } from '../state.ts';
import { ledgerEvents } from '../ledger.ts';
import { workspace, fixtureModels, processHost, until, reviewReport } from './helpers.ts';
import type { GroupInput, AgentInput } from '../tasks.ts';

const hash = (value: string) => createHash('sha256').update(value).digest('hex');
const agent = (key: string): AgentInput => ({ key, prompt: 'Return a verified result', role: 'reviewer', model: null, files: {}, review: false });

test('native DAG restores parent phase, completed dependency, children and cancellation after SIGKILL', async () => {
  const w = await workspace(); let p = await processHost(w, ['first done', { text: 'second', delayMs: 30000 }]);
  const input: GroupInput = { key: 'mission-dag', kind: 'tasks', route: null, run: null, objective: 'join children', maxAttempts: 2, deadline: Date.now() + 60000, steps: [{ name: 'first', dependsOn: [], kind: 'agent', input: agent('first') }, { name: 'second', dependsOn: ['first'], kind: 'agent', input: agent('second') }] };
  const parent = await p.rpc({ command: 'tasks', payload: input }) as { taskId: number };
  await until(() => p.rpc({ command: 'state' }), value => {
    const s = value as Awaited<ReturnType<Host['snapshot']>>;
    return s.state.workflow.doNotRedo.includes('first') && s.state.workflow.budget.requests === 2;
  });
  await p.kill();
  p = await processHost(w, [{ text: 'second resumed', delayMs: 30000 }]);
  try {
    const restored = await p.rpc({ command: 'handoff' }) as Awaited<ReturnType<Host['snapshot']>>;
    assert.ok(restored.state.workflow.doNotRedo.includes('first'));
    assert.ok(restored.state.workflow.work.find(work => work.key === input.key)?.children.length === 2);
    await p.rpc({ command: 'cancel', payload: { id: parent.taskId } });
    const settled = await until(() => p.rpc({ command: 'task', payload: { id: parent.taskId } }), value => (value as { state: { status: string } }).state.status === 'terminal') as { state: { outcome: { result: Result } } };
    assert.equal(settled.state.outcome.result.status, 'cancelled');
    const view = await p.rpc({ command: 'state' }) as Awaited<ReturnType<Host['snapshot']>>;
    assert.equal(view.state.workflow.tasks.filter(task => task.status !== 'terminal').length, 0);
    assert.ok(view.state.workflow.budget.requests >= 2);
  } finally { await p.kill('SIGTERM'); }
});

test('review resumes missing owned reviewers without resetting requests or closing its round twice', async () => {
  const w = await workspace(); const source = 'export const value = 1;\n'; await writeFile(join(w.cwd, 'source.ts'), source);
  const report = reviewReport('source.ts');
  let p = await processHost(w, [report, { text: report, delayMs: 30000 }, { text: report, delayMs: 30000 }]);
  await p.rpc({ command: 'export', payload: { id: 'route', event: 'route_decided', run: 'review-run', detail: { route: 'plan-implement', reason: 'fixture' } } });
  const input = { key: 'review-t1', run: 'review-run', round: 'T1', intent: 'Review this fixture', baseSha: '123abcd', patchSha: hash(source), files: { 'source.ts': hash(source) }, authorProvider: 'openai', reviewers: ['logic', 'spec', 'adversary'].map(role => ({ role, model: { provider: 'faux', modelId: 'fixture' } })) };
  const review = await p.rpc({ command: 'review', payload: input }) as { taskId: number };
  await until(() => p.rpc({ command: 'state' }), value => {
    const view = value as Awaited<ReturnType<Host['snapshot']>>;
    return view.state.workflow.budget.requests === 3 && view.state.workflow.doNotRedo.length >= 1;
  });
  const before = await p.rpc({ command: 'state' }) as Awaited<ReturnType<Host['snapshot']>>;
  const done = before.state.workflow.work.find(work => work.result === 'passed')!.taskId;
  await p.kill(); p = await processHost(w, [report, report]);
  try {
    await until(() => p.rpc({ command: 'task', payload: { id: review.taskId } }), value => (value as { state: { status: string } }).state.status === 'terminal');
    const after = await p.rpc({ command: 'state' }) as Awaited<ReturnType<Host['snapshot']>>;
    assert.equal(after.state.workflow.work.find(work => work.taskId === done)?.result, 'passed');
    assert.equal(after.state.workflow.budget.requests, 5);
    assert.equal(after.state.workflow.budget.unknownRequests, 2);
    const events = await ledgerEvents(w.cwd, 'review-run');
    assert.equal(events.filter(event => event.event === 'review_completed').length, 1);
    assert.equal(events.at(-1)?.detail.review_round, 'T1');
    assert.equal((await p.rpc({ command: 'review', payload: input }) as { taskId: number }).taskId, review.taskId);
  } finally { await p.kill('SIGTERM'); }
});

test('a partial reviewer alone gets a fresh retry; completed reviewer results and failed costs stay recorded', async () => {
  const w = await workspace(); const source = 'value\n'; await writeFile(join(w.cwd, 'source'), source);
  const good = reviewReport('source');
  const f = fixtureModels([fauxAssistantMessage(good), fauxAssistantMessage('partial'), fauxAssistantMessage(good), fauxAssistantMessage(good)]);
  const host = await Host.open({ dir: w.session, cwd: w.cwd, ...f });
  try {
    await host.ledger.export('route', { event: 'route_decided', run: 'r', detail: { route: 'plan-implement', reason: 'fixture' } });
    const id = (await host.start('review', { key: 'r1', run: 'r', round: 'T1', intent: 'Review this fixture', baseSha: '123abcd', patchSha: hash(source), files: { source: hash(source) }, authorProvider: 'openai', reviewers: ['logic', 'spec', 'adversary'].map(role => ({ role: role as 'logic' | 'spec' | 'adversary', model: f.model })) })).taskId;
    const result = await host.harness.waitForTask(id, ctx);
    assert.equal(result.state.outcome.status === 'completed' && result.state.outcome.result.status, 'passed');
    const state = (await host.harness.snapshot(State, ctx))!;
    assert.equal(Object.values(state.attempts).filter(a => a.kind === 'agent').length, 4);
    assert.equal(Object.values(state.work).filter(work => work.result?.status === 'failed').length, 1);
    assert.equal(state.requests, 4);
  } finally { await host.close(); }
});

test('a native review is owned by its mission parent and preserves the canonical hunter briefs', async () => {
  const w = await workspace(); const source = 'fixture\n'; await writeFile(join(w.cwd, 'source'), source);
  const seen: string[] = [];
  const f = fixtureModels(Array.from({ length: 3 }, () => async request => { seen.push(JSON.stringify(request.messages)); return fauxAssistantMessage(reviewReport('source')); }));
  const host = await Host.open({ dir: w.session, cwd: w.cwd, ...f });
  try {
    const input: GroupInput = { key: 'review-parent', kind: 'tasks', route: null, run: null, objective: 'own a native review', maxAttempts: 1, deadline: Date.now() + 60000, steps: [{ name: 'review', dependsOn: [], kind: 'review', input: { key: 'owned-review', intent: 'Review this fixture', run: 'native-review', round: 'T1', baseSha: '123abcd', patchSha: hash(source), files: { source: hash(source) }, authorProvider: 'openai', reviewers: ['logic', 'spec', 'adversary'].map(role => ({ role: role as 'logic' | 'spec' | 'adversary', model: f.model })) } }] };
    const id = (await host.start('group', input)).taskId;
    const done = await host.harness.waitForTask(id, ctx);
    assert.equal(done.state.outcome.status === 'completed' && done.state.outcome.result.status, 'passed');
    const state = (await host.harness.snapshot(State, ctx))!;
    assert.equal((await host.harness.getTask(state.work['owned-review'].taskId, ctx))?.owner, id);
    const spec = seen.find(request => request.includes('Axis: spec'))!;
    const conversation = Number(state.work['owned-review:spec'].result!.evidence.match(/conversation:(\d+)/)![1]) as typeof host.root.id;
    assert.deepEqual((await host.harness.snapshot(AgentDoc, conversation, ctx))!.tools, []);
    assert.ok(spec.includes('Review this fixture'));
    assert.ok(seen.find(request => request.includes('Axis: logic'))!.includes('precedence'));
    assert.equal((await ledgerEvents(w.cwd, 'native-review')).at(-1)?.detail.review_round, 'T1');
  } finally { await host.close(); }
});

test('an interrupted command retains its receipt, reaps its worker and blocks equivalent new calls', async () => {
  const w = await workspace(); let p = await processHost(w);
  const marker = join(w.cwd, 'effect');
  const argv = [process.execPath, '-e', `const fs=require('node:fs'); fs.appendFileSync(${JSON.stringify(marker)}, 'fired'+String.fromCharCode(10)); setInterval(()=>{},1000)`];
  await p.rpc({ command: 'grant', payload: { key: 'initial', argv, expiresAt: Date.now() + 60000, evidence: 'test only local effect' } });
  const input = { key: 'unsafe', argv, grantId: 'initial', timeoutMs: 60000, files: {}, validation: false, run: null };
  const created = await p.rpc({ command: 'command', payload: input }) as { taskId: number };
  await until(async () => { try { return await readFile(marker, 'utf8'); } catch { return ''; } }, text => text === 'fired\n');
  await p.kill();
  await until(async () => { try { return await stat(join(w.session, `command-${created.taskId}.receipt.json`)); } catch { return null; } }, value => value !== null);
  p = await processHost(w);
  try {
    const resumed = await until(() => p.rpc({ command: 'task', payload: { id: created.taskId } }), value => (value as { state: { status: string } }).state.status === 'terminal') as { state: { outcome: { result: Result } } };
    assert.equal(resumed.state.outcome.result.status, 'failed');
    assert.equal((await p.rpc({ command: 'state' }) as Awaited<ReturnType<Host['snapshot']>>).state.workflow.unresolvedEffects.length, 1);
    await p.rpc({ command: 'grant', payload: { key: 'new-call', argv, expiresAt: Date.now() + 60000, evidence: 'test fresh call without reconciliation' } });
    const fresh = await p.rpc({ command: 'command', payload: { ...input, key: 'unsafe-new', grantId: 'new-call' } }) as { taskId: number };
    const blocked = await until(() => p.rpc({ command: 'task', payload: { id: fresh.taskId } }), value => (value as { state: { status: string } }).state.status === 'terminal') as { state: { outcome: { status: string } } };
    assert.equal(blocked.state.outcome.status, 'faulted');
    assert.equal(await readFile(marker, 'utf8'), 'fired\n');
  } finally { await p.kill('SIGTERM'); }
});

test('safe tool execution rechecks current role and credential targets after model preparation', async () => {
  const w = await workspace(); let release!: () => void;
  const wait = new Promise<void>(resolve => { release = resolve; });
  const f = fixtureModels([async () => { await wait; return fauxAssistantMessage(fauxToolCall('write', { path: 'changed.txt', content: 'changed' }), { stopReason: 'toolUse' }); }, fauxAssistantMessage('denied')]);
  const host = await Host.open({ dir: w.session, cwd: w.cwd, ...f });
  try {
    const snap = await host.snapshot();
    await host.admit('role-change', { session: snap.sessionId, conversation: host.root.id, text: 'try a write', deliverAs: null });
    await until(() => host.snapshot(), value => value.state.workflow.budget.requests === 1);
    await host.harness.commit(async tx => { (await tx.doc(Role, host.root.id)).role = 'reviewer'; }, ctx);
    release(); await host.root.waitForIdle(ctx);
    await assert.rejects(readFile(join(w.cwd, 'changed.txt')), /ENOENT/);
    f.faux.setResponses([fauxAssistantMessage(fauxToolCall('read', { path: 'auth.json' }), { stopReason: 'toolUse' }), fauxAssistantMessage('denied')]);
    await writeFile(join(w.cwd, 'auth.json'), 'do not read');
    await host.admit('credential', { session: snap.sessionId, conversation: host.root.id, text: 'try credential read', deliverAs: null });
    await host.root.waitForIdle(ctx);
    const raw = await host.root.context(ctx);
    assert.equal(raw.messages.some(message => message.role === 'toolResult' && JSON.stringify(message).includes('do not read')), false);
  } finally { await host.close(); }
});
