import { test } from 'node:test';
import assert from 'node:assert/strict';
import { writeFile, readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { spawn } from 'node:child_process';
import { BACKGROUND_CONTEXT as ctx } from '@earendil-works/chord/context';
import { fauxAssistantMessage, fauxToolCall } from '@earendil-works/pi-ai/providers/faux';
import { Host } from '../host.ts';
import { State, fingerprint } from '../state.ts';
import { execute, ledgerEvents } from '../ledger.ts';
import { missionGate, missionComplete } from '../missions.ts';
import { commandGrant } from '../guards.ts';
import { workspace, fixtureModels, processHost, until } from './helpers.ts';
import type { GroupInput, AgentInput } from '../tasks.ts';

test('goal receives dependency evidence and retains current validated completion after reopen', async () => {
  const w = await workspace(); const seen: string[] = [];
  const f = fixtureModels([fauxAssistantMessage('measured score 42'), async request => { seen.push(JSON.stringify(request.messages)); return fauxAssistantMessage('synthesized evidence'); }]);
  let host = await Host.open({ dir: w.session, cwd: w.cwd, ...f });
  const argv = [process.execPath, '-e', 'process.stdout.write("goal verified")'];
  await host.handle({ command: 'grant', payload: { key: 'validate', argv, expiresAt: Date.now() + 60000, evidence: 'local goal fixture' } });
  const agent = (key: string): AgentInput => ({ key, prompt: 'Use recorded evidence', role: 'reviewer', model: null, files: {}, review: false });
  const input: GroupInput = { key: 'goal-parent', kind: 'mission', route: 'goal', run: 'goal-proof', objective: 'verified goal', maxAttempts: 3, deadline: Date.now() + 60000, steps: [
    { name: 'measure', dependsOn: [], kind: 'agent', input: agent('measure') },
    { name: 'synthesize', dependsOn: ['measure'], kind: 'agent', input: agent('synthesize') },
    { name: 'validate', dependsOn: ['synthesize'], kind: 'command', input: { key: 'goal-validation', argv, grantId: 'validate', timeoutMs: 10000, files: {}, validation: true, run: 'goal-proof' } },
  ] };
  const id = (await host.start('group', input)).taskId;
  const done = await host.harness.waitForTask(id, ctx);
  assert.equal(done.state.outcome.status === 'completed' && done.state.outcome.result.status, 'passed');
  assert.ok(seen[0].includes('measured score 42'));
  assert.equal((await ledgerEvents(w.cwd, 'goal-proof')).filter(e => e.event === 'completed').length, 1);
  await host.close(); host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  try {
    assert.equal((await host.start('group', input)).taskId, id);
    const view = await host.snapshot();
    assert.equal(view.state.workflow.budget.requests, 2);
    assert.ok(view.state.workflow.doNotRedo.includes('goal-parent'));
  } finally { await host.close(); }
});

test('plan missions enforce actual READY and independent evidence even when the write step is renamed', async () => {
  const w = await workspace(); let host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  const step = { name: 'renamed-write', dependsOn: [], kind: 'agent' as const, input: { key: 'writer', prompt: 'write', role: 'writer' as const, model: null, files: {}, review: false } };
  const mission: GroupInput = { key: 'plan', kind: 'mission', route: 'plan-implement', run: 'plan-proof', objective: 'gate proof', steps: [step], maxAttempts: 1, deadline: Date.now() + 60000 };
  try {
    await writeFile(join(w.cwd, 'PLAN.md'), '# Plan\n- Status: DRAFT\n');
    await assert.rejects(missionGate(mission, step, w.cwd), /READY|plan/i);
    await writeFile(join(w.cwd, 'PLAN.md'), ['# Plan', '- Status: READY', '## Goal', '- Prove guards.', '## Acceptance Criteria', '- Guards refuse missing evidence.', '## Scope', '- Local fixtures only.', '## Facts And Assumptions', '- Isolated workspace.', '## Requirement Trace', '- Request -> fixture state -> no material gap -> guard output', '## Steps', '- Verify the named guard.', '## Checks', '- node --test', '## Risks', '- None.', '## Workflow Contract', '- Route: plan-implement', '- Role: implementer', '- Stop condition: tests pass', '- Required evidence: guard result', '## Open Questions', '- None'].join('\n'));
    await assert.rejects(missionGate(mission, step, w.cwd), /adversary/);
    await host.ledger.export('route', { event: 'route_decided', run: 'plan-proof', detail: { route: 'plan-implement', reason: 'fixture' } });
    const provenance = { requested: { family: 'anthropic', model: 'fixture', provider: 'faux', route: 'local-test' }, effective: { family: 'anthropic', model: 'fixture', provider: 'faux' }, runner: 'local-fixture', run_id: 'fixture-plan' };
    await host.ledger.export('plan-review', { event: 'adversary_completed', run: 'plan-proof', detail: { mode: 'plan', verdict: 'READY', accepted_findings: [], rejected_findings: [], model_provenance: provenance } });
    await missionGate(mission, step, w.cwd);
    await assert.rejects(missionComplete(mission, host.ledger, 1), /profile|missing/i);
    await host.close(); host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
    assert.equal(Object.keys((await host.handoff()).recovery.exports).some(id => /^completed:1(?::[a-f0-9]{64})?$/.test(id)), false, 'unmet completion prerequisites do not create an obsolete terminal export');
  } finally { await host.close(); }
});

test('a ship restores CI and missing-evidence phases and accepts a later canonical receipt', async () => {
  const w = await workspace(); const checks = join(w.cwd, 'checks');
  await writeFile(checks, JSON.stringify({ head: 'abc', checks: [] }));
  let p = await processHost(w);
  await p.rpc({ command: 'export', payload: { id: 'change', event: 'file_changed', run: 'ship-proof', detail: { path: 'fixture', change: 'fixture shipping input' } } });
  const argv = [process.execPath, '-e', 'process.stdout.write("passed")'];
  await p.rpc({ command: 'grant', payload: { key: 'validate', argv, expiresAt: Date.now() + 60000, evidence: 'local ship fixture' } });
  const input: GroupInput = { key: 'ship-parent', kind: 'mission', route: 'ship', run: 'ship-proof', objective: 'ship proof', maxAttempts: 2, deadline: Date.now() + 60000, steps: [
    { name: 'validate', dependsOn: [], kind: 'command', input: { key: 'ship-validation', argv, grantId: 'validate', timeoutMs: 10000, files: {}, validation: true, run: 'ship-proof' } },
    { name: 'ci', dependsOn: ['validate'], kind: 'wait', input: { key: 'ship-ci', repo: 'a/b', pr: 1, head: 'abc', deadline: Date.now() + 60000, intervalMs: 100, fixture: checks } },
  ] };
  const parent = await p.rpc({ command: 'ship', payload: input }) as { taskId: number };
  await until(() => p.rpc({ command: 'state' }), value => (value as Awaited<ReturnType<Host['snapshot']>>).state.workflow.work.some(work => work.key === 'ship-ci' && work.phase.startsWith('ci_wait:')));
  await p.kill(); p = await processHost(w);
  try {
    const view = await p.rpc({ command: 'handoff' }) as Awaited<ReturnType<Host['snapshot']>>;
    assert.ok(view.state.workflow.doNotRedo.includes('ship-validation'));
    assert.equal(view.state.workflow.work.find(work => work.key === 'ship-parent')?.phase, 'ci');
    await writeFile(checks, JSON.stringify({ head: 'abc', checks: [{ name: 'build', head: 'abc', state: 'SUCCESS' }] }));
    await until(() => p.rpc({ command: 'state' }), value => (value as Awaited<ReturnType<Host['snapshot']>>).state.workflow.work.some(work => work.key === 'ship-parent' && work.phase === 'awaiting_evidence'));
    assert.equal((await ledgerEvents(w.cwd, 'ship-proof')).some(event => event.event === 'ship_completed'), false);
    await p.kill(); p = await processHost(w);
    const restored = await p.rpc({ command: 'handoff' }) as Awaited<ReturnType<Host['snapshot']>>;
    assert.equal(restored.state.workflow.work.find(work => work.key === 'ship-parent')?.phase, 'awaiting_evidence');
    await p.rpc({ command: 'export', payload: { id: 'ship-receipt', event: 'ship_completed', run: 'ship-proof', detail: { cumulative_review: 'fixture...HEAD @ abc', thermo_nuclear: 'clean', pr_body_style: 'plain', delta_rereview: 'n/a', deciding_code: 'complete', escaped_defects_recorded: 0, pr_url: 'https://example.invalid/pr/1', ci_state: 'green' } } });
    const ended = await until(() => p.rpc({ command: 'task', payload: { id: parent.taskId } }), value => (value as { state: { status: string } }).state.status === 'terminal') as { state: { outcome: { status: string; result: { status: string } } } };
    assert.equal(ended.state.outcome.status === 'completed' && ended.state.outcome.result.status, 'passed');
  } finally { await p.kill('SIGTERM'); }
});

test('pending canonical exports recover both SIGKILL windows with exactly one append', async () => {
  for (const appendFirst of [false, true]) {
    const w = await workspace();
    const worker = `
      import { Host } from ${JSON.stringify(new URL('../host.ts', import.meta.url).href)};
      import { fixtureModels } from ${JSON.stringify(new URL('./helpers.ts', import.meta.url).href)};
      import { State } from ${JSON.stringify(new URL('../state.ts', import.meta.url).href)};
      import { execute } from ${JSON.stringify(new URL('../ledger.ts', import.meta.url).href)};
      import { BACKGROUND_CONTEXT as ctx } from '@earendil-works/chord/context';
      const host = await Host.open({dir:${JSON.stringify(w.session)},cwd:${JSON.stringify(w.cwd)},...fixtureModels()});
      host.ledger.flush = async id => {
        const item = (await host.harness.snapshot(State, ctx)).exports[id];
        if (${appendFirst}) await execute(host.ledger.repo + '/scripts/workflow-event', ['--dir', ${JSON.stringify(join(w.cwd, '.workflow'))}, 'append', item.run, item.event, JSON.stringify(item.detail)], {cwd:${JSON.stringify(w.cwd)}});
        process.kill(process.pid, 'SIGKILL');
      };
      await host.ledger.export('crash-export', {event:'completed',run:'export-proof',detail:{summary:'crash proof'}});
    `;
    const child = spawn(process.execPath, ['--input-type=module', '-e', worker], { cwd: new URL('../', import.meta.url), stdio: ['ignore', 'ignore', 'pipe'] });
    let stderr = ''; child.stderr.on('data', bytes => { stderr += bytes; });
    const signal = await new Promise<string | null>((resolve, reject) => { child.once('error', reject); child.once('exit', (_code, signal) => resolve(signal)); });
    assert.equal(signal, 'SIGKILL', stderr);
    const host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
    try {
      assert.equal((await ledgerEvents(w.cwd, 'export-proof')).length, 1);
      assert.equal((await host.harness.snapshot(State, ctx))!.exports['crash-export'].acknowledged, true);
    } finally { await host.close(); }
  }
});

test('local bare Git effects retain exact grants and require reconciliation for an incomplete process trace', async () => {
  const w = await workspace(); const remote = join(w.dir, 'remote.git');
  await execute('git', ['init', '--bare', remote]);
  await execute('git', ['init', '-b', 'main', w.cwd]);
  await execute('git', ['config', 'user.name', 'Durable Fixture'], { cwd: w.cwd });
  await execute('git', ['config', 'user.email', 'fixture@example.invalid'], { cwd: w.cwd });
  await writeFile(join(w.cwd, 'tracked'), 'fixture\n');
  await execute('git', ['add', 'tracked'], { cwd: w.cwd });
  await execute('git', ['commit', '-m', 'Fixture baseline'], { cwd: w.cwd });
  const host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  try {
    const argv = ['git', 'push', remote, 'HEAD:refs/heads/main'];
    await host.handle({ command: 'grant', payload: { key: 'push-local', argv, consumer: 'local-push', expiresAt: Date.now() + 60000, evidence: 'isolated bare local remote fixture' } });
    await host.ledger.export('review', { event: 'review_completed', run: 'push-proof', detail: { status: 'GO', evidence: ['isolated bare remote fixture has a current reviewed baseline'] } });
    const state = (await host.harness.snapshot(State, ctx))!;
    for (const field of ['action', 'target', 'cwd'] as const) assert.throws(() => commandGrant({ ...state, grants: { ...state.grants, 'push-local': { ...state.grants['push-local'], [field]: 'changed' } } }, 'push-local', argv, w.cwd, Date.now()), /exact argv/);
    assert.throws(() => commandGrant(state, 'push-local', ['git', 'push', remote, 'HEAD:refs/heads/other'], w.cwd, Date.now()), /exact argv/);
    const validation = [process.execPath, '-e', 'process.exit(0)'];
    await host.handle({ command: 'grant', payload: { key: 'validate', argv: validation, expiresAt: Date.now() + 60000, evidence: 'local validation fixture' } });
    const input: GroupInput = { key: 'publication-parent', kind: 'mission', route: 'goal', run: 'push-proof', objective: 'publish and validate local fixture', maxAttempts: 2, deadline: Date.now() + 60000, steps: [
      { name: 'publish', kind: 'command', dependsOn: [], input: { key: 'local-push', argv, grantId: 'push-local', timeoutMs: 10000, files: {}, validation: false, run: 'push-proof' } },
      { name: 'validate', kind: 'command', dependsOn: ['publish'], input: { key: 'validate', argv: validation, grantId: 'validate', timeoutMs: 1000, files: {}, validation: true, run: 'push-proof' } },
    ] };
    const task = await host.harness.waitForTask((await host.start('group', input)).taskId, ctx);
    const local = (await execute('git', ['rev-parse', 'HEAD'], { cwd: w.cwd })).stdout.trim();
    const distant = (await execute('git', ['ls-remote', remote, 'refs/heads/main'])).stdout.split(/\s/)[0];
    assert.equal(local, distant);
    const after = (await host.harness.snapshot(State, ctx))!;
    const publish = after.work['local-push'];
    const receipt = JSON.parse(await readFile(join(w.session, `command-${publish.taskId}.receipt.json`), 'utf8'));
    assert.equal(receipt.exit, 0);
    assert.equal(after.grants['push-local'].usedBy, publish.taskId);
    if (receipt.interrupted) {
      assert.equal(task.state.outcome.status === 'completed' && task.state.outcome.result.status, 'blocked');
      const [key, effect] = Object.entries(after.effects).find(([, effect]) => effect.taskId === publish.taskId)!;
      assert.equal(effect.status, 'uncertain');
      assert.equal(after.work.validate, undefined, 'uncertain publication cannot authorize its successor');
      assert.equal(Object.values(after.attempts).filter(attempt => attempt.kind === 'command').length, 1, 'no command is replayed or advanced after an attribution gap');
      const file = join(w.session, 'human-publication-check.json');
      const evidence = JSON.stringify({ taskId: publish.taskId, argv, localHead: local, remoteHead: distant });
      await writeFile(file, evidence, { mode: 0o600 });
      await host.handle({ command: 'reconcile', payload: { key, receipt: file, hash: fingerprint(evidence) } });
      const reconciled = (await host.harness.snapshot(State, ctx))!;
      assert.equal(reconciled.effects[key].status, 'verified');
      assert.equal(reconciled.work['local-push'].result?.status, 'failed', 'reconciliation preserves the recorded task outcome');
      assert.equal(reconciled.requests, after.requests);
    } else {
      assert.equal(task.state.outcome.status === 'completed' && task.state.outcome.result.status, 'passed');
    }
  } finally { await host.close(); }
});

test('a model reissuing an unresolved command through its tool surface cannot repeat the effect', async () => {
  const w = await workspace(); let p = await processHost(w);
  const marker = join(w.cwd, 'marker');
  const argv = [process.execPath, '-e', `require('node:fs').appendFileSync(${JSON.stringify(marker)}, 'once');setInterval(()=>{},1000)`];
  await p.rpc({ command: 'grant', payload: { key: 'initial', argv, expiresAt: Date.now() + 60000, evidence: 'local fixture' } });
  const task = await p.rpc({ command: 'command', payload: { key: 'original', argv, grantId: 'initial', timeoutMs: 60000, files: {}, validation: false, run: null } }) as { taskId: number };
  await until(async () => { try { return await readFile(marker, 'utf8'); } catch { return ''; } }, value => value === 'once');
  await p.kill();
  await until(async () => { try { return await readFile(join(w.session, `command-${task.taskId}.receipt.json`), 'utf8'); } catch { return ''; } }, Boolean);
  const f = fixtureModels([fauxAssistantMessage(fauxToolCall('run_granted_command', { grantId: 'reissued' }), { stopReason: 'toolUse' }), fauxAssistantMessage('reconciliation required')], 'fixture');
  const host = await Host.open({ dir: w.session, cwd: w.cwd, ...f });
  try {
    await host.handle({ command: 'grant', payload: { key: 'reissued', argv, expiresAt: Date.now() + 60000, evidence: 'new identity cannot remove uncertainty' } });
    const view = await host.snapshot();
    await host.admit('reissued-call', { session: view.sessionId, conversation: host.root.id, text: 'retry granted command', deliverAs: null });
    await host.root.waitForIdle(ctx);
    assert.equal(await readFile(marker, 'utf8'), 'once');
    assert.equal((await host.snapshot()).state.workflow.unresolvedEffects.length, 1);
  } finally { await host.close(); }
});
