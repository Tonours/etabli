import { test } from 'node:test';
import assert from 'node:assert/strict';
import { chmod, readFile, symlink, writeFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { join } from 'node:path';
import { BACKGROUND_CONTEXT as ctx } from '@earendil-works/chord/context';
import { fauxAssistantMessage, fauxToolCall } from '@earendil-works/pi-ai/providers/faux';
import { Host } from '../host.ts';
import { State } from '../state.ts';
import { egress } from '../egress.ts';
import { command } from '../commands.ts';
import { ledgerEvents } from '../ledger.ts';
import { missionComplete } from '../missions.ts';
import { workspacePath } from '../guards.ts';
import { fixtureModels, workspace, processHost, until } from './helpers.ts';
import type { GroupInput } from '../tasks.ts';
import { acknowledgeMessage, pendingMessage, savePendingMessage, type Store } from '../../../../pi-mobile/apps/mobile/outbox.ts';

test('a native write after validation invalidates goal completion', async () => {
  const w = await workspace();
  const f = fixtureModels([fauxAssistantMessage(fauxToolCall('write', { path: 'artifact.txt', content: 'changed' }), { stopReason: 'toolUse' }), fauxAssistantMessage('written')]);
  const host = await Host.open({ dir: w.session, cwd: w.cwd, ...f });
  try {
    const argv = [process.execPath, '-e', 'process.stdout.write("validated")'];
    await host.handle({ command: 'grant', payload: { key: 'validate', argv, expiresAt: Date.now() + 60000, evidence: 'regression fixture' } });
    const input: GroupInput = { key: 'goal', kind: 'mission', route: 'goal', run: 'goal-proof', objective: 'current validation only', maxAttempts: 2, deadline: Date.now() + 2500, steps: [
      { name: 'validate', kind: 'command', dependsOn: [], input: { key: 'validation', argv, grantId: 'validate', timeoutMs: 1000, files: {}, validation: true, run: 'goal-proof' } },
      { name: 'write', kind: 'agent', dependsOn: ['validate'], input: { key: 'writer', prompt: 'write artifact', role: 'writer', model: null, files: {}, review: false } },
    ] };
    const done = await host.harness.waitForTask((await host.start('group', input)).taskId, ctx);
    assert.notEqual(done.state.outcome.status === 'completed' && done.state.outcome.result.status, 'passed');
    const events = await ledgerEvents(w.cwd, 'goal-proof');
    assert.ok(events.some(event => event.event === 'file_changed'));
    assert.equal(events.some(event => event.event === 'completed'), false);
  } finally { await host.close(); }
});

test('root model tools cannot consume a publication grant for another work key', async () => {
  const w = await workspace(); const marker = join(w.cwd, 'published'); const executable = join(w.cwd, 'git');
  await writeFile(executable, `#!/bin/sh\nprintf published > '${marker}'\n`); await chmod(executable, 0o700);
  const f = fixtureModels([fauxAssistantMessage(fauxToolCall('run_granted_command', { grantId: 'publish' }), { stopReason: 'toolUse' }), fauxAssistantMessage('blocked')]);
  const host = await Host.open({ dir: w.session, cwd: w.cwd, ...f });
  try {
    await host.handle({ command: 'grant', payload: { key: 'publish', argv: [executable, '-c', 'color.ui=false', 'push', 'fixture'], consumer: 'manifest-publication', expiresAt: Date.now() + 60000, evidence: 'a grant for a particular reviewed step' } });
    const view = await host.snapshot();
    await host.admit('input', { session: view.sessionId, conversation: host.root.id, text: 'publish', deliverAs: null });
    await host.root.waitForIdle(ctx);
    await assert.rejects(readFile(marker), { code: 'ENOENT' });
    assert.equal((await host.harness.snapshot(State, ctx))!.grants.publish.usedBy, null);
  } finally { await host.close(); }
});

test('parent deadline cancels a running command before its late mutation', async () => {
  const w = await workspace(); const marker = join(w.cwd, 'late');
  const host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  try {
    const argv = [process.execPath, '-e', `setTimeout(()=>require('node:fs').writeFileSync(${JSON.stringify(marker)}, 'late'), 1200)`];
    await host.handle({ command: 'grant', payload: { key: 'late', argv, expiresAt: Date.now() + 60000, evidence: 'owned timeout fixture' } });
    const input: GroupInput = { key: 'parent', kind: 'tasks', route: null, run: null, objective: 'deadline', maxAttempts: 1, deadline: Date.now() + 300, steps: [{ name: 'late', kind: 'command', dependsOn: [], input: { key: 'late', argv, grantId: 'late', timeoutMs: 5000, files: {}, validation: false, run: null } }] };
    const started = Date.now();
    const done = await host.harness.waitForTask((await host.start('group', input)).taskId, ctx);
    assert.equal(done.state.outcome.status === 'completed' && done.state.outcome.result.status, 'blocked');
    assert.ok(Date.now() - started < 1100, 'deadline must interrupt the child, not wait for its own timeout');
    await assert.rejects(readFile(marker), { code: 'ENOENT' });
  } finally { await host.close(); }
});

test('command receipt drains trailing pipes and kills background descendants', async () => {
  const w = await workspace(); const marker = join(w.cwd, 'orphan');
  const pipe = `require('node:child_process').spawn(process.execPath,['-e','setTimeout(()=>process.stdout.write("trailing"),80)'],{stdio:['ignore',1,2]});process.exit(0)`;
  const receipt = await command(w.dir, w.cwd, 1, { key: 'pipes', argv: [process.execPath, '-e', pipe], grantId: 'fixture', timeoutMs: 1000, files: {}, validation: false, run: null }, new AbortController().signal);
  assert.ok(receipt.stdout.includes('trailing'));
  const background = `require('node:child_process').spawn(process.execPath,['-e',${JSON.stringify(`setTimeout(()=>require('node:fs').writeFileSync(${JSON.stringify(marker)}, 'orphan'),400)`)}],{stdio:'ignore'});process.exit(0)`;
  const ended = await command(w.dir, w.cwd, 2, { key: 'background', argv: [process.execPath, '-e', background], grantId: 'fixture', timeoutMs: 1000, files: {}, validation: false, run: null }, new AbortController().signal);
  assert.equal(ended.interrupted, true);
  await new Promise(resolve => setTimeout(resolve, 500));
  await assert.rejects(readFile(marker), { code: 'ENOENT' });
});

test('outbox ACK remains committed when chunk cleanup fails and ACK retry is idempotent', async () => {
  const values = new Map<string, string>();
  const store: Store = { async getItemAsync(key) { return values.get(key) ?? null; }, async setItemAsync(key, value) { values.set(key, value); }, async deleteItemAsync(key) { if (/\.0$/.test(key)) throw new Error('chunk cleanup failed'); values.delete(key); } };
  const message = { admissionId: randomUUID(), machine: 'host', sessionId: 'session', conversationId: 1, text: 'message', deliverAs: null };
  await savePendingMessage(store, 'test', message);
  await acknowledgeMessage(store, 'test', message.admissionId);
  assert.equal(await pendingMessage(store, 'test'), null);
  await acknowledgeMessage(store, 'test', message.admissionId);
  await savePendingMessage(store, 'test', { ...message, admissionId: randomUUID(), text: 'next' });
  assert.equal((await pendingMessage(store, 'test'))?.text, 'next');
});

test('terminal pending export is rejected when canonical evidence changes', async () => {
  const w = await workspace(); let host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  await host.ledger.export('route', { event: 'route_decided', run: 'proof', detail: { route: 'goal', reason: 'regression' } });
  const flush = host.ledger.flush;
  host.ledger.flush = async () => { throw new Error('interrupted before append'); };
  await assert.rejects(host.ledger.export('terminal', { event: 'completed', run: 'proof', detail: { summary: 'old evidence' } }), /interrupted/);
  host.ledger.flush = flush;
  await host.ledger.export('changed', { event: 'file_changed', run: 'proof', detail: { path: 'artifact', change: 'new input after pending terminal intent' } });
  await host.close(); host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  try {
    assert.equal((await ledgerEvents(w.cwd, 'proof')).some(event => event.event === 'completed'), false);
    assert.equal((await host.harness.snapshot(State, ctx))!.exports.terminal.acknowledged, false);
  } finally { await host.close(); }
});

test('egress redacts string values without breaking escaped JSON', () => {
  const text = 'password=abcdefghijk"quoted\\path; postgres://user:password@example.invalid/db';
  const messages = [{ role: 'user' as const, content: text, timestamp: 1 }];
  const filtered = egress('faux', ['faux'], messages);
  assert.equal(filtered[0].role, 'user');
  assert.ok(JSON.stringify(filtered).includes('[credential removed]'));
  assert.ok(JSON.stringify(filtered).includes('quoted'));
  assert.equal(JSON.stringify(filtered).includes('user:password@'), false);
});

test('known failed edit permits a corrected call and nonzero command permits a fresh grant', async () => {
  const w = await workspace(); await writeFile(join(w.cwd, 'artifact'), 'original');
  const f = fixtureModels([fauxAssistantMessage(fauxToolCall('edit', { path: 'artifact', oldText: 'absent', newText: 'wrong' }), { stopReason: 'toolUse' }), fauxAssistantMessage(fauxToolCall('edit', { path: 'artifact', oldText: 'original', newText: 'corrected' }), { stopReason: 'toolUse' }), fauxAssistantMessage('done')]);
  const host = await Host.open({ dir: w.session, cwd: w.cwd, ...f });
  try {
    const view = await host.snapshot();
    await host.admit('edit', { session: view.sessionId, conversation: host.root.id, text: 'correct', deliverAs: null });
    await host.root.waitForIdle(ctx);
    assert.equal(await readFile(join(w.cwd, 'artifact'), 'utf8'), 'corrected');
    const argv = [process.execPath, '-e', 'process.exit(1)'];
    for (const key of ['first', 'fresh']) {
      await host.handle({ command: 'grant', payload: { key, argv, expiresAt: Date.now() + 60000, evidence: 'known failed command, explicitly fresh attempt' } });
      const done = await host.harness.waitForTask((await host.start('command', { key, argv, grantId: key, timeoutMs: 1000, files: {}, validation: true, run: null })).taskId, ctx);
      assert.equal(done.state.outcome.status === 'completed' && done.state.outcome.result.status, 'failed');
    }
    assert.equal((await host.snapshot()).state.workflow.unresolvedEffects.length, 0);
  } finally { await host.close(); }
});

test('human budget extension preserves consumption and survives reopen', async () => {
  const w = await workspace(); let host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels(), maxRequests: 1 });
  try {
    const view = await host.snapshot();
    await host.admit('first', { session: view.sessionId, conversation: host.root.id, text: 'first', deliverAs: null }); await host.root.waitForIdle(ctx);
    const deadline = Date.now() + 10 * 3600000;
    await host.handle({ command: 'budget', payload: { maxRequests: 2, deadline, evidence: 'human continuation of the same run' } });
    assert.equal((await host.harness.snapshot(State, ctx))!.requests, 1);
    await assert.rejects(host.handle({ command: 'budget', payload: { maxRequests: 1, deadline, evidence: 'decrease' } }), /increase|decrease/);
    await host.close(); host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
    const state = (await host.harness.snapshot(State, ctx))!;
    assert.equal(state.maxRequests, 2); assert.equal(state.requests, 1); assert.equal(state.deadline, deadline);
    await host.admit('second', { session: view.sessionId, conversation: host.root.id, text: 'second', deliverAs: null }); await host.root.waitForIdle(ctx);
    assert.equal((await host.harness.snapshot(State, ctx))!.requests, 2);
  } finally { await host.close(); }
});

test('new nested file paths resolve through the nearest existing ancestor and reject escape', async () => {
  const w = await workspace();
  assert.equal(await workspacePath(w.cwd, 'new/nested/file.txt'), join(w.cwd, 'new/nested/file.txt'));
  await symlink(w.dir, join(w.cwd, 'outside'));
  await assert.rejects(workspacePath(w.cwd, 'outside/new/file.txt'), /outside/);
});

test('root writes and non-validation commands bind to the active canonical mission', async () => {
  const w = await workspace();
  const f = fixtureModels([fauxAssistantMessage(fauxToolCall('write', { path: 'nested/new/artifact', content: 'root mutation' }), { stopReason: 'toolUse' }), fauxAssistantMessage('done')]);
  const host = await Host.open({ dir: w.session, cwd: w.cwd, ...f });
  try {
    await host.ledger.export('route', { event: 'route_decided', run: 'goal-proof', detail: { route: 'goal', reason: 'root mutation regression' } });
    await host.ledger.export('validation', { event: 'validation_run', run: 'goal-proof', detail: { command: 'fixture validation', exit: 0 } });
    const view = await host.snapshot();
    await host.admit('write', { session: view.sessionId, conversation: host.root.id, text: 'write', deliverAs: null }); await host.root.waitForIdle(ctx);
    assert.equal(await readFile(join(w.cwd, 'nested/new/artifact'), 'utf8'), 'root mutation');
    const argv = [process.execPath, '-e', 'process.stdout.write("non-validation operation")'];
    await host.handle({ command: 'grant', payload: { key: 'mutation', argv, expiresAt: Date.now() + 60000, evidence: 'local mutation fixture' } });
    await host.harness.waitForTask((await host.start('command', { key: 'mutation', argv, grantId: 'mutation', timeoutMs: 1000, files: {}, validation: false, run: null })).taskId, ctx);
    const events = await ledgerEvents(w.cwd, 'goal-proof');
    assert.equal(events.filter(event => event.event === 'file_changed').length, 2);
    const mission: GroupInput = { key: 'goal', kind: 'mission', route: 'goal', run: 'goal-proof', objective: 'old validation must not complete', steps: [], maxAttempts: 0, deadline: Date.now() + 60000 };
    await assert.rejects(missionComplete(mission, host.ledger, 999), /current canonical validation/);
  } finally { await host.close(); }
});

test('owned deadline resumes after SIGKILL and drains a pending agent without extending time', async () => {
  const w = await workspace(); let p = await processHost(w, [{ text: 'late', delayMs: 5000 }]);
  const deadline = Date.now() + 1800;
  const input: GroupInput = { key: 'deadline-parent', kind: 'tasks', route: null, run: null, objective: 'persisted deadline', maxAttempts: 1, deadline, steps: [{ name: 'agent', kind: 'agent', dependsOn: [], input: { key: 'agent', prompt: 'slow fixture', role: 'reviewer', model: null, files: {}, review: false } }] };
  const parent = await p.rpc({ command: 'tasks', payload: input }) as { taskId: number };
  await until(() => p.rpc({ command: 'state' }), value => (value as Awaited<ReturnType<Host['snapshot']>>).state.workflow.budget.requests === 1);
  await p.kill(); p = await processHost(w, [{ text: 'late resumed', delayMs: 5000 }]);
  try {
    const task = await until(() => p.rpc({ command: 'task', payload: { id: parent.taskId } }), value => (value as { state: { status: string } }).state.status === 'terminal') as { state: { outcome: { result: { status: string } } } };
    assert.equal(task.state.outcome.result.status, 'blocked');
    assert.ok(Date.now() - deadline < 1000);
    const view = await p.rpc({ command: 'state' }) as Awaited<ReturnType<Host['snapshot']>>;
    assert.equal(view.state.workflow.tasks.filter(task => task.status !== 'terminal').length, 0);
    assert.ok(view.state.workflow.budget.requests >= 2);
  } finally { await p.kill('SIGTERM'); }
});

test('a nested command rechecks the current independent plan gate after model preparation', async () => {
  const w = await workspace(); let release!: () => void;
  const waiting = new Promise<void>(resolve => { release = resolve; });
  const f = fixtureModels([async () => { await waiting; return fauxAssistantMessage(fauxToolCall('run_granted_command', { grantId: 'nested' }), { stopReason: 'toolUse' }); }, fauxAssistantMessage('gate refused')]);
  const host = await Host.open({ dir: w.session, cwd: w.cwd, ...f });
  let id: number | undefined;
  try {
    await writeFile(join(w.cwd, 'PLAN.md'), ['# Plan', '- Status: READY', '## Goal', '- Prove current gates.', '## Acceptance Criteria', '- Recheck before effects.', '## Scope', '- Local fixtures.', '## Facts And Assumptions', '- Isolated workspace.', '## Requirement Trace', '- Request -> guarded command -> no gap -> refusal', '## Steps', '- Run the bounded fixture.', '## Checks', '- node --test', '## Risks', '- None.', '## Workflow Contract', '- Route: plan-implement', '- Role: implementer', '- Stop condition: tests pass', '- Required evidence: guard result', '## Open Questions', '- None'].join('\n'));
    const provenance = { requested: { family: 'anthropic', model: 'fixture', provider: 'faux', route: 'local-test' }, effective: { family: 'anthropic', model: 'fixture', provider: 'faux' }, runner: 'local-fixture', run_id: 'fixture-plan' };
    await host.ledger.export('plan-review', { event: 'adversary_completed', run: 'proof', detail: { mode: 'plan', verdict: 'READY', accepted_findings: [], rejected_findings: [], model_provenance: provenance } });
    const marker = join(w.cwd, 'nested-command');
    const argv = [process.execPath, '-e', `require('node:fs').writeFileSync(${JSON.stringify(marker)}, 'executed')`];
    const validation = [process.execPath, '-e', 'process.exit(0)'];
    await host.handle({ command: 'grant', payload: { key: 'nested', argv, consumer: 'writer', expiresAt: Date.now() + 60000, evidence: 'writer-bound local fixture' } });
    await host.handle({ command: 'grant', payload: { key: 'validation', argv: validation, expiresAt: Date.now() + 60000, evidence: 'local validation' } });
    const input: GroupInput = { key: 'parent', kind: 'mission', route: 'plan-implement', run: 'proof', objective: 'execution gate', maxAttempts: 2, deadline: Date.now() + 10000, steps: [
      { name: 'writer', kind: 'agent', dependsOn: [], input: { key: 'writer', role: 'writer', prompt: 'run granted command', model: null, files: {}, review: false } },
      { name: 'validate', kind: 'command', dependsOn: ['writer'], input: { key: 'validate', argv: validation, grantId: 'validation', timeoutMs: 1000, files: {}, validation: true, run: 'proof' } },
    ] };
    id = (await host.start('group', input)).taskId;
    await until(() => host.snapshot(), view => view.state.workflow.budget.requests === 1);
    await host.ledger.export('plan-revoked', { event: 'adversary_completed', run: 'proof', detail: { mode: 'plan', verdict: 'CHALLENGED', accepted_findings: [{ finding: 'fixture revocation', blocking: true }], rejected_findings: [], model_provenance: provenance } });
    release();
    await until(() => host.handoff(), view => view.recovery.work.some(work => work.key === 'writer' && work.result !== null));
    await assert.rejects(readFile(marker), { code: 'ENOENT' });
    assert.equal((await host.harness.snapshot(State, ctx))!.grants.nested.usedBy, null);
  } finally { release(); if (id) await host.handle({ command: 'cancel', payload: { id } }); await host.close(); }
});

test('a concurrent native mutation makes an in-flight validation stale', async () => {
  const w = await workspace(); const marker = join(w.cwd, 'check-started');
  const f = fixtureModels([fauxAssistantMessage(fauxToolCall('write', { path: 'artifact', content: 'changed during check' }), { stopReason: 'toolUse' }), fauxAssistantMessage('done')]);
  const host = await Host.open({ dir: w.session, cwd: w.cwd, ...f });
  try {
    await host.ledger.export('route', { event: 'route_decided', run: 'proof', detail: { route: 'goal', reason: 'validation concurrency fixture' } });
    const argv = [process.execPath, '-e', `require('node:fs').writeFileSync(${JSON.stringify(marker)}, 'started');setTimeout(()=>process.exit(0),1200)`];
    await host.handle({ command: 'grant', payload: { key: 'check', argv, expiresAt: Date.now() + 60000, evidence: 'local validation' } });
    const id = (await host.start('command', { key: 'check', argv, grantId: 'check', timeoutMs: 3000, files: {}, validation: true, run: 'proof' })).taskId;
    await until(async () => { try { return await readFile(marker, 'utf8'); } catch { return ''; } }, Boolean);
    const view = await host.snapshot(); await host.admit('write', { session: view.sessionId, conversation: host.root.id, text: 'write', deliverAs: null }); await host.root.waitForIdle(ctx);
    const task = await host.harness.waitForTask(id, ctx);
    assert.equal(task.state.outcome.status === 'completed' && task.state.outcome.result.status, 'failed');
    const validation = (await ledgerEvents(w.cwd, 'proof')).findLast(event => event.event.startsWith('validation_'));
    assert.equal(validation?.event, 'validation_failed');
    assert.match(String(validation?.detail.failure), /changed during validation/);
  } finally { await host.close(); }
});

test('shared idle projection does not emit a recursive commit stream', async () => {
  const w = await workspace(); const host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  try {
    const first = await host.snapshot(); let commits = 0;
    const remove = host.harness.subscribeCommits(() => { commits++; });
    for (let i = 0; i < 4; i++) assert.equal((await host.snapshot()).seq, first.seq);
    await new Promise(resolve => setTimeout(resolve, 120));
    remove(); assert.equal(commits, 0);
  } finally { await host.close(); }
});
