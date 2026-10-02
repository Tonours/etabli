import { test, mock } from 'node:test';
import assert from 'node:assert/strict';
import fs, { readFile, writeFile, symlink, unlink } from 'node:fs/promises';
import { syncBuiltinESMExports } from 'node:module';
import { createHash } from 'node:crypto';
import { join } from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { BACKGROUND_CONTEXT as ctx } from '@earendil-works/chord/context';
import { fauxAssistantMessage, fauxToolCall } from '@earendil-works/pi-ai/providers/faux';
import type { TaskId } from '@earendil-works/pi-durable';
import { Host } from '../host.ts';
import { State, Role } from '../state.ts';
import { fixtureModels, workspace, until } from './helpers.ts';
import { ledgerEvents } from '../ledger.ts';
import type { CommandInput } from '../commands.ts';
import type { GroupInput } from '../tasks.ts';

const readyPlan = ['# Plan', '- Status: READY', '## Goal', '- Verify current authority.', '## Acceptance Criteria', '- Refuse revoked writes.', '## Scope', '- Private fixtures.', '## Facts And Assumptions', '- Isolated workspace.', '## Requirement Trace', '- Current authority -> prior gate -> async revocation gap -> refuse stale mutation', '## Steps', '- Write under current permission.', '## Checks', '- node --test', '## Risks', '- None.', '## Workflow Contract', '- Route: plan-implement', '- Role: implementer', '- Stop condition: observed refusal', '- Required evidence: unchanged bytes', '## Open Questions', '- None'].join('\n');
const provenance = { requested: { family: 'anthropic', model: 'fixture', provider: 'faux' }, effective: { family: 'anthropic', model: 'fixture', provider: 'faux' }, runner: 'local-fixture', run_id: 'authority-fixture' };

for (const tool of ['write', 'edit'] as const) test(`${tool} rechecks current authority, inputs and target after the canonical export`, async () => {
  for (const changed of ['review', 'plan', 'frozen-input', 'bytes', 'run', 'symlink', 'role'] as const) {
    const w = await workspace(); const target = join(w.cwd, 'artifact');
    await writeFile(target, 'original'); await writeFile(join(w.cwd, 'input'), 'frozen input');
    await writeFile(join(w.cwd, 'PLAN.md'), readyPlan);
    const args: Record<string, string> = tool === 'write' ? { path: 'artifact', content: 'changed' } : { path: 'artifact', oldText: 'original', newText: 'changed' };
    const host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels([fauxAssistantMessage(fauxToolCall(tool, args), { stopReason: 'toolUse' }), fauxAssistantMessage('guard observed')]) });
    let release!: () => void; const paused = new Promise<void>(resolve => { release = resolve; }); let waiting = false;
    try {
      await host.harness.commit(async tx => { (await tx.doc(Role, host.root.id)).frozenInputs = { input: createHash('sha256').update('frozen input').digest('hex') }; }, ctx);
      await host.ledger.export('route', { event: 'route_decided', run: 'proof', detail: { route: 'plan-implement', reason: 'isolated authority regression' } });
      await host.ledger.export('ready', { event: 'adversary_completed', run: 'proof', detail: { mode: 'plan', verdict: 'READY', accepted_findings: [], rejected_findings: [], model_provenance: provenance } });
      const original = host.ledger.export.bind(host.ledger);
      host.ledger.export = async (id, event, expected) => {
        await original(id, event, expected);
        if (event.event === 'file_changed') { waiting = true; await paused; }
      };
      const view = await host.snapshot();
      await host.admit('write-fixture', { session: view.sessionId, conversation: host.root.id, text: 'mutate fixture', deliverAs: null });
      await until(async () => waiting, Boolean);
      let expected = 'original';
      if (changed === 'review') await host.ledger.export('revoked', { event: 'adversary_completed', run: 'proof', detail: { mode: 'plan', verdict: 'CHALLENGED', accepted_findings: [{ finding: 'fixture revocation', blocking: true }], rejected_findings: [], model_provenance: provenance } });
      if (changed === 'plan') await writeFile(join(w.cwd, 'PLAN.md'), readyPlan.replace('Status: READY', 'Status: CHALLENGED'));
      if (changed === 'frozen-input') await writeFile(join(w.cwd, 'input'), 'changed input');
      if (changed === 'bytes') { expected = 'human edit'; await writeFile(target, expected); }
      if (changed === 'run') await host.ledger.export('other-run', { event: 'route_decided', run: 'other', detail: { route: 'goal', reason: 'selected mission changed during export' } });
      if (changed === 'symlink') {
        expected = 'external target preserved'; const outside = join(w.dir, 'outside');
        await writeFile(outside, expected); await unlink(target); await symlink(outside, target);
      }
      if (changed === 'role') await host.harness.commit(async tx => { (await tx.doc(Role, host.root.id)).role = 'reviewer'; }, ctx);
      release(); await host.root.waitForIdle(ctx);
      assert.equal(await readFile(target, 'utf8'), expected, `${tool}: ${changed} must refuse the stale write`);
      const effects = Object.values((await host.harness.snapshot(State, ctx))!.effects);
      assert.equal(effects.length, 1);
      assert.equal(effects[0].status, ['bytes', 'symlink'].includes(changed) ? 'uncertain' : 'verified', `${tool}: ${changed} retains the truthful effect outcome`);
    } finally { release(); await host.close(); }
  }
});

for (const changed of ['expiry', 'frozen-input'] as const) test(`command refuses ${changed} after export without starting its worker`, async () => {
  const w = await workspace(); const marker = join(w.cwd, 'marker');
  await writeFile(join(w.cwd, 'PLAN.md'), readyPlan); await writeFile(join(w.cwd, 'input'), 'original');
  const host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  let release!: () => void; const paused = new Promise<void>(resolve => { release = resolve; }); let waiting = false;
  try {
    await host.ledger.export('route', { event: 'route_decided', run: 'proof', detail: { route: 'plan-implement', reason: 'isolated command authority regression' } });
    await host.ledger.export('ready', { event: 'adversary_completed', run: 'proof', detail: { mode: 'plan', verdict: 'READY', accepted_findings: [], rejected_findings: [], model_provenance: provenance } });
    const original = host.ledger.export.bind(host.ledger);
    host.ledger.export = async (id, event, expected) => { await original(id, event, expected); if (event.event === 'file_changed') { waiting = true; await paused; } };
    const argv = [process.execPath, '-e', "require('node:fs').writeFileSync('marker',require('node:fs').readFileSync('input'))"];
    const expiresAt = Date.now() + 5000;
    await host.handle({ command: 'grant', payload: { key: 'grant', argv, consumer: 'command', expiresAt, evidence: 'bounded local regression' } });
    const input: CommandInput = { key: 'command', argv, grantId: 'grant', timeoutMs: 10000, files: { input: createHash('sha256').update('original').digest('hex') }, validation: false, run: 'proof' };
    const { taskId } = await host.start('command', input);
    await until(async () => waiting, Boolean);
    const before = (await host.harness.snapshot(State, ctx))!;
    if (changed === 'expiry') await new Promise(resolve => setTimeout(resolve, Math.max(0, expiresAt - Date.now()) + 20));
    else await writeFile(join(w.cwd, 'input'), 'human change');
    release(); await until(() => host.harness.getTask(taskId, ctx), task => task?.state.status === 'terminal');
    await assert.rejects(readFile(marker), { code: 'ENOENT' });
    await assert.rejects(readFile(join(w.session, `command-${taskId}.input.json`)), { code: 'ENOENT' });
    await assert.rejects(readFile(join(w.session, `command-${taskId}.receipt.json`)), { code: 'ENOENT' });
    const state = (await host.harness.snapshot(State, ctx))!;
    assert.equal(state.grants.grant.usedBy, taskId);
    assert.equal(state.requests, before.requests);
    assert.equal(state.deadline, before.deadline);
    const effect = Object.values(state.effects)[0];
    assert.equal(effect.status, 'verified'); assert.equal(effect.receipt, `command:${taskId}:not-started`);
    assert.equal(state.work.command.result?.status, 'failed');
    assert.equal(state.attempts[`command:${taskId}`].requests, before.attempts[`command:${taskId}`].requests);
  } finally { release(); await host.close(); }
});

for (const changed of ['expiry', 'frozen-input'] as const) test(`command refuses ${changed} after its prepared input write without launching`, async () => {
  const w = await workspace(); await writeFile(join(w.cwd, 'PLAN.md'), readyPlan); await writeFile(join(w.cwd, 'input'), 'original');
  const host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  let release!: () => void; const paused = new Promise<void>(resolve => { release = resolve; }); let waiting = false;
  const original = fs.writeFile;
  const writer = mock.method(fs, 'writeFile', async (...args: Parameters<typeof writeFile>) => {
    await original(...args);
    if (String(args[0]).startsWith(w.session) && String(args[0]).endsWith('.input.json')) { waiting = true; await paused; }
  });
  syncBuiltinESMExports();
  try {
    await host.ledger.export('route', { event: 'route_decided', run: 'proof', detail: { route: 'plan-implement', reason: 'actual launcher boundary regression' } });
    await host.ledger.export('ready', { event: 'adversary_completed', run: 'proof', detail: { mode: 'plan', verdict: 'READY', accepted_findings: [], rejected_findings: [], model_provenance: provenance } });
    const argv = [process.execPath, '-e', "require('node:fs').writeFileSync('marker',require('node:fs').readFileSync('input'))"];
    const expiresAt = Date.now() + 3000;
    await host.handle({ command: 'grant', payload: { key: 'grant', argv, consumer: 'command', expiresAt, evidence: 'bounded actual launcher regression' } });
    const { taskId } = await host.start('command', { key: 'command', argv, grantId: 'grant', timeoutMs: 10000, files: { input: createHash('sha256').update('original').digest('hex') }, validation: false, run: 'proof' });
    await until(async () => waiting, Boolean);
    const before = (await host.harness.snapshot(State, ctx))!;
    if (changed === 'expiry') await new Promise(resolve => setTimeout(resolve, Math.max(0, expiresAt - Date.now()) + 20));
    else await writeFile(join(w.cwd, 'input'), 'human change');
    release(); await until(() => host.harness.getTask(taskId, ctx), task => task?.state.status === 'terminal');
    await assert.rejects(readFile(join(w.cwd, 'marker')), { code: 'ENOENT' });
    assert.ok(await readFile(join(w.session, `command-${taskId}.input.json`), 'utf8'));
    await assert.rejects(readFile(join(w.session, `command-${taskId}.receipt.json`)), { code: 'ENOENT' });
    const state = (await host.harness.snapshot(State, ctx))!;
    assert.equal(state.grants.grant.usedBy, taskId); assert.equal(state.requests, before.requests); assert.equal(state.deadline, before.deadline);
    assert.equal(state.work.command.result?.status, 'failed');
    const effect = Object.values(state.effects)[0];
    assert.equal(effect.status, 'verified'); assert.equal(effect.receipt, `command:${taskId}:not-started`);
  } finally { release(); writer.mock.restore(); syncBuiltinESMExports(); await host.close(); }
});

for (const role of ['root', 'writer'] as const) for (const boundary of ['export', 'prepared-input'] as const) for (const changed of [true, false]) test(`nested command ${role} ${changed ? 'refuses changed' : 'executes unchanged'} inputs after ${boundary} and preserves them on reopen`, async () => {
  const w = await workspace(); await writeFile(join(w.cwd, 'PLAN.md'), readyPlan); await writeFile(join(w.cwd, 'input'), 'original');
  const files = { input: createHash('sha256').update('original').digest('hex') };
  const models = fixtureModels([fauxAssistantMessage(fauxToolCall('run_granted_command', { grantId: 'nested' }), { stopReason: 'toolUse' }), fauxAssistantMessage('guard observed')]);
  let host = await Host.open({ dir: w.session, cwd: w.cwd, ...models });
  let release!: () => void; const paused = new Promise<void>(resolve => { release = resolve; }); let waiting = false;
  const originalWrite = fs.writeFile;
  const writer = boundary === 'prepared-input' ? mock.method(fs, 'writeFile', async (...args: Parameters<typeof writeFile>) => {
    await originalWrite(...args);
    if (String(args[0]).startsWith(w.session) && String(args[0]).endsWith('.input.json')) { waiting = true; await paused; }
  }) : null;
  syncBuiltinESMExports();
  try {
    await host.ledger.export('route', { event: 'route_decided', run: 'proof', detail: { route: 'plan-implement', reason: 'nested frozen-input launch boundary' } });
    await host.ledger.export('ready', { event: 'adversary_completed', run: 'proof', detail: { mode: 'plan', verdict: 'READY', accepted_findings: [], rejected_findings: [], model_provenance: provenance } });
    const originalExport = host.ledger.export.bind(host.ledger);
    if (boundary === 'export') host.ledger.export = async (id, event, expected) => { await originalExport(id, event, expected); if (event.event === 'file_changed') { waiting = true; await paused; } };
    const argv = [process.execPath, '-e', "require('node:fs').appendFileSync('marker',require('node:fs').readFileSync('input'))"];
    await host.handle({ command: 'grant', payload: { key: 'nested', argv, consumer: role === 'writer' ? 'writer' : `root:${host.root.id}`, expiresAt: Date.now() + 30000, evidence: 'nested launch fixture' } });
    if (role === 'writer') await host.start('agent', { key: 'writer', prompt: 'run granted command', role: 'writer', model: null, files, review: false });
    else {
      await host.harness.commit(async tx => { (await tx.doc(Role, host.root.id)).frozenInputs = files; }, ctx);
      const view = await host.snapshot();
      await host.admit('nested-root', { session: view.sessionId, conversation: host.root.id, text: 'run granted command', deliverAs: null });
    }
    await until(async () => waiting, Boolean);
    const before = (await host.harness.snapshot(State, ctx))!;
    const id = before.grants.nested.usedBy as TaskId | null; assert.ok(id);
    if (changed) await writeFile(join(w.cwd, 'input'), 'human change');
    release();
    await until(() => host.harness.getTask(id, ctx), task => task?.state.status === 'terminal');
    if (role === 'root') await host.root.waitForIdle(ctx);
    else await until(() => host.handoff(), view => view.recovery.work.some(work => work.key === 'writer' && work.result !== null));
    if (changed) {
      await assert.rejects(readFile(join(w.cwd, 'marker')), { code: 'ENOENT' });
      await assert.rejects(readFile(join(w.session, `command-${id}.receipt.json`)), { code: 'ENOENT' });
    } else assert.equal(await readFile(join(w.cwd, 'marker'), 'utf8'), 'original');
    const child = (await host.harness.getTask(id, ctx))!;
    assert.deepEqual((child.input as CommandInput).files, files);
    await host.handoff();
    const settled = (await host.harness.snapshot(State, ctx))!;
    assert.equal(settled.grants.nested.usedBy, id); assert.equal(settled.deadline, before.deadline);
    assert.equal(settled.attempts[`command:${id}`].requests, before.attempts[`command:${id}`].requests);
    const effect = Object.values(settled.effects).find(effect => effect.taskId === id)!;
    assert.equal(effect.status, 'verified');
    if (changed) assert.equal(effect.receipt, `command:${id}:not-started`);
    writer?.mock.restore(); syncBuiltinESMExports();
    await host.close(); host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
    const restored = (await host.harness.snapshot(State, ctx))!;
    assert.deepEqual((await host.harness.getTask(id, ctx))!.input, child.input);
    assert.deepEqual([restored.requests, restored.maxRequests, restored.deadline, restored.attempts, restored.budgetChanges, restored.grants.nested], [settled.requests, settled.maxRequests, settled.deadline, settled.attempts, settled.budgetChanges, settled.grants.nested]);
    if (!changed) assert.equal(await readFile(join(w.cwd, 'marker'), 'utf8'), 'original');
  } finally { release(); writer?.mock.restore(); syncBuiltinESMExports(); await host.close(); }
});

for (const mutation of [false, true]) test(`parallel validation exports preserve cells and ${mutation ? 'refuse changed canonical inputs' : 'retry unrelated appends'}`, async () => {
  const w = await workspace(); const host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  const deadline = Date.now() + 30000;
  let release!: () => void; const paused = new Promise<void>(resolve => { release = resolve; }); let waiting = 0;
  try {
    await host.ledger.export('route', { event: 'route_decided', run: 'proof', detail: { route: 'goal', reason: 'parallel validation regression' } });
    const original = host.ledger.export.bind(host.ledger);
    host.ledger.export = async (id, event, expected) => {
      if ((event.event === 'validation_run' || event.event === 'validation_failed') && waiting < 3) { waiting++; await paused; }
      await original(id, event, expected);
    };
    const steps: GroupInput['steps'] = [];
    for (let i = 0; i < 3; i++) {
      const key = `check-${i}`; const argv = [process.execPath, '-e', `require('node:fs').appendFileSync('${key}', 'once')`];
      await host.handle({ command: 'grant', payload: { key, argv, consumer: key, expiresAt: deadline, evidence: 'bounded local validation' } });
      steps.push({ name: key, kind: 'command', dependsOn: [], input: { key, argv, grantId: key, timeoutMs: 10000, files: {}, validation: true, run: 'proof' } });
    }
    const { taskId } = await host.start('group', { key: 'parallel', kind: 'tasks', route: null, run: null, objective: 'parallel validation evidence', maxAttempts: 3, deadline, steps });
    await until(async () => waiting, value => value === 3);
    if (mutation) await host.ledger.export('late-change', { event: 'file_changed', run: 'proof', detail: { path: 'fixture', change: 'late canonical mutation before validation append' } });
    release(); await until(() => host.handoff(), view => view.recovery.work.some(work => work.key === 'parallel' && work.result !== null));
    for (const step of steps) assert.equal(await readFile(join(w.cwd, step.name), 'utf8'), 'once');
    const state = (await host.harness.snapshot(State, ctx))!;
    const result = state.work.parallel.result!;
    assert.equal(result.status, mutation ? 'blocked' : 'passed');
    const events = (await ledgerEvents(w.cwd, 'proof')).filter(event => event.event === 'validation_run' || event.event === 'validation_failed');
    assert.equal(events.length, 3);
    assert.ok(events.every(event => event.event === (mutation ? 'validation_failed' : 'validation_run')));
    const parent = await host.harness.getTask(taskId, ctx); assert.ok(parent);
    assert.equal(state.requests, 0); assert.equal((parent.input as GroupInput).deadline, deadline);
    assert.equal(Object.values(state.attempts).filter(attempt => attempt.kind === 'command').length, 3);
    assert.equal((await host.harness.getTask(taskId, ctx))?.state.status, 'terminal');
  } finally { release(); await host.close(); }
});

test('a mutation between the validation hash and stamp cannot mint a passing intent', async () => {
  const w = await workspace(); const host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() }); let injected = false;
  try {
    await host.ledger.export('route', { event: 'route_decided', run: 'proof', detail: { route: 'goal', reason: 'hash/stamp boundary regression' } });
    const argv = [process.execPath, '-e', "const fs=require('node:fs');fs.appendFileSync('marker','once');const timer=setInterval(()=>{if(fs.existsSync('release'))clearInterval(timer)},10)"];
    await host.handle({ command: 'grant', payload: { key: 'check', argv, expiresAt: Date.now() + 30000, evidence: 'bounded boundary fixture' } });
    const input: CommandInput = { key: 'check', argv, grantId: 'check', timeoutMs: 10000, files: {}, validation: true, run: 'proof' };
    const { taskId } = await host.start('command', input);
    await until(async () => { try { return await readFile(join(w.cwd, 'marker'), 'utf8'); } catch { return ''; } }, value => value === 'once');
    const key = `validation:${taskId}`;
    await host.harness.commit(async tx => { (await tx.doc(State)).exports[key] = { event: 'validation_run', run: 'proof', detail: { command: argv.join(' '), exit: 0, export_id: key }, acknowledged: false, precondition: '0'.repeat(64), error: 'retained prior precondition' }; }, ctx);
    const original = host.ledger.hasReceipt.bind(host.ledger);
    host.ledger.hasReceipt = async id => {
      if (id === key && !injected) { injected = true; await host.ledger.export('between-hash-stamp', { event: 'file_changed', run: 'proof', detail: { path: 'fixture', change: 'mutation between hash and stamp reads' } }); }
      return original(id);
    };
    await writeFile(join(w.cwd, 'release'), 'release');
    await until(() => host.handoff(), view => view.recovery.work.some(work => work.key === 'check' && work.result !== null));
    assert.equal(injected, true); assert.equal(await readFile(join(w.cwd, 'marker'), 'utf8'), 'once');
    const validations = (await ledgerEvents(w.cwd, 'proof')).filter(event => event.event === 'validation_run' || event.event === 'validation_failed');
    assert.equal(validations.length, 1); assert.equal(validations[0].event, 'validation_failed');
    assert.equal((await host.harness.snapshot(State, ctx))!.exports[key].precondition, '0'.repeat(64));
  } finally { await writeFile(join(w.cwd, 'release'), 'release'); await host.close(); }
});

test('a committed validation wins over lost ACK, abandonment and later mutations without a second export', async () => {
  const w = await workspace(); const host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() }); let injected = false;
  try {
    await host.ledger.export('route', { event: 'route_decided', run: 'proof', detail: { route: 'goal', reason: 'validation ACK recovery regression' } });
    const original = host.ledger.export.bind(host.ledger);
    host.ledger.export = async (id, event, expected) => {
      await original(id, event, expected);
      if (event.event === 'validation_run' && !injected) {
        injected = true;
        await host.harness.commit(async tx => { const item = (await tx.doc(State)).exports[id]; item.acknowledged = false; item.abandoned = 'abandoned before observing committed receipt'; }, ctx);
        await original('later-mutation', { event: 'file_changed', run: 'proof', detail: { path: 'fixture', change: 'later mutation after committed validation' } });
        throw new Error('ledger precondition changed: interrupted acknowledgement fixture');
      }
    };
    const argv = [process.execPath, '-e', "require('node:fs').appendFileSync('marker','once')"];
    await host.handle({ command: 'grant', payload: { key: 'check', argv, expiresAt: Date.now() + 30000, evidence: 'bounded ACK fixture' } });
    const { taskId } = await host.start('command', { key: 'check', argv, grantId: 'check', timeoutMs: 10000, files: {}, validation: true, run: 'proof' });
    await until(() => host.handoff(), view => view.recovery.work.some(work => work.key === 'check' && work.result !== null));
    assert.equal(await readFile(join(w.cwd, 'marker'), 'utf8'), 'once');
    const state = (await host.harness.snapshot(State, ctx))!;
    assert.equal(state.work.check.result?.status, 'passed'); assert.equal(state.requests, 0);
    const own = Object.entries(state.exports).filter(([id]) => id.startsWith(`validation:${taskId}:`));
    assert.equal(own.length, 1); assert.equal(own[0][1].acknowledged, true); assert.ok(own[0][1].abandoned);
    assert.equal((await ledgerEvents(w.cwd, 'proof')).filter(event => event.event === 'validation_run' || event.event === 'validation_failed').length, 1);
  } finally { await host.close(); }
});

test('validation resumes after actual SIGKILL following ACK without repeating the command or export', async () => {
  const w = await workspace(); const marker = join(w.dir, 'validation-crash.json');
  const argv = [process.execPath, '-e', "require('node:fs').appendFileSync('marker','once')"];
  const worker = `
    import { Host } from ${JSON.stringify(new URL('../host.ts', import.meta.url).href)};
    import { fixtureModels } from ${JSON.stringify(new URL('./helpers.ts', import.meta.url).href)};
    import { State } from ${JSON.stringify(new URL('../state.ts', import.meta.url).href)};
    import { BACKGROUND_CONTEXT as ctx } from '@earendil-works/chord/context';
    import { writeFile } from 'node:fs/promises';
    const host = await Host.open({dir:${JSON.stringify(w.session)},cwd:${JSON.stringify(w.cwd)},...fixtureModels()});
    await host.listen();
    await host.ledger.export('route',{event:'route_decided',run:'proof',detail:{route:'goal',reason:'actual validation crash fixture'}});
    await host.handle({command:'grant',payload:{key:'check',argv:${JSON.stringify(argv)},expiresAt:Date.now()+60000,evidence:'bounded validation fixture'}});
    const flush = host.ledger.flush.bind(host.ledger);
    host.ledger.flush = async id => {
      await flush(id);
      if (id.startsWith('validation:')) {
        const state = await host.harness.snapshot(State,ctx);
        await writeFile(${JSON.stringify(marker)},JSON.stringify({deadline:state.deadline,requests:state.requests,taskId:state.work.check.taskId}));
        process.kill(process.pid,'SIGKILL');
      }
    };
    await host.start('command',{key:'check',argv:${JSON.stringify(argv)},grantId:'check',timeoutMs:10000,files:{},validation:true,run:'proof'});
    await new Promise(()=>{});
  `;
  const child = spawn(process.execPath, ['--input-type=module', '--eval', worker], { cwd: fileURLToPath(new URL('..', import.meta.url)), stdio: ['ignore', 'ignore', 'pipe'] });
  let stderr = ''; child.stderr.on('data', bytes => { stderr += bytes; });
  const exit = new Promise<string | null>(resolve => child.once('exit', (_code, signal) => resolve(signal)));
  let host: Host | undefined;
  try {
    const before = await until(async () => { try { return JSON.parse(await readFile(marker, 'utf8')) as { deadline: number; requests: number; taskId: number }; } catch { if (child.exitCode !== null) throw new Error(stderr); return null; } }, value => value !== null);
    assert.ok(before); assert.equal(await exit, 'SIGKILL');
    host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
    await until(() => host!.handoff(), view => view.recovery.work.some(work => work.key === 'check' && work.result !== null));
    const state = (await host.harness.snapshot(State, ctx))!;
    assert.equal(state.work.check.taskId, before.taskId); assert.equal(state.work.check.result?.status, 'passed');
    assert.equal(state.requests, before.requests); assert.equal(state.deadline, before.deadline);
    assert.equal(await readFile(join(w.cwd, 'marker'), 'utf8'), 'once');
    assert.equal((await ledgerEvents(w.cwd, 'proof')).filter(event => event.event === 'validation_run' || event.event === 'validation_failed').length, 1);
  } finally { if (child.exitCode === null && child.signalCode === null) { child.kill('SIGKILL'); await exit; } await host?.close(); }
});
