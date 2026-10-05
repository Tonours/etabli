import { test } from 'node:test';
import assert from 'node:assert/strict';
import { chmod, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { spawn } from 'node:child_process';
import { BACKGROUND_CONTEXT as ctx } from '@earendil-works/chord/context';
import type { TaskId } from '@earendil-works/pi-durable';
import { fauxAssistantMessage } from '@earendil-works/pi-ai/providers/faux';
import { Host } from '../host.ts';
import { State } from '../state.ts';
import { command } from '../commands.ts';
import { fixtureModels, workspace, until, processHost } from './helpers.ts';
import type { GroupInput } from '../tasks.ts';

test('quoted JSON credentials and bearer values are filtered for generation, compaction and phone state', async () => {
  const w = await workspace(); const seen: string[] = [];
  const secret = 'example-credential-without-a-prefix';
  const text = `config: ${JSON.stringify({ api_key: secret, nested: { password: secret + '"quoted\\' } })}\nserialized: ${JSON.stringify(JSON.stringify({ password: secret + '"quoted\\' }))}\nAuthorization: Bearer ${secret}; ${'history '.repeat(300)}`;
  const f = fixtureModels(Array.from({ length: 5 }, () => async request => { seen.push(JSON.stringify(request.messages)); return fauxAssistantMessage('filtered answer'); }));
  const host = await Host.open({ dir: w.session, cwd: w.cwd, ...f });
  try {
    const view = await host.snapshot();
    for (const id of ['first', 'second']) {
      await host.admit(id, { session: view.sessionId, conversation: host.root.id, text, deliverAs: null }); await host.root.waitForIdle(ctx);
    }
    const task = await host.handle({ command: 'compact', payload: { key: 'filtered' } }) as { taskId: TaskId };
    await host.harness.waitForTask(task.taskId, ctx);
    assert.ok(seen.length >= 3, 'generation and native compaction both ran');
    assert.equal(seen.some(request => request.includes(secret)), false);
    assert.equal(JSON.stringify(await host.snapshot()).includes(secret), false);
  } finally { await host.close(); }
});

test('standalone publication cannot borrow a ship run or forge its mission context', async () => {
  for (const forged of [false, true]) {
    const w = await workspace(); const marker = join(w.cwd, 'published'); const exe = join(w.cwd, 'git');
    await writeFile(exe, `#!${process.execPath}\nrequire('node:fs').writeFileSync(${JSON.stringify(marker)}, 'published');\n`); await chmod(exe, 0o700);
    const host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
    try {
      await host.ledger.export('route', { event: 'route_decided', run: 'ship-run', detail: { route: 'ship', reason: 'standalone bypass regression' } });
      await host.ledger.export('review', { event: 'review_completed', run: 'ship-run', detail: { status: 'GO', evidence: 'current fixture review' } });
      const argv = [exe, 'push', 'fixture'];
      await host.handle({ command: 'grant', payload: { key: 'publish', argv, consumer: 'publish', expiresAt: Date.now() + 60000, evidence: 'local exact command grant' } });
      const input = { key: 'publish', argv, grantId: 'publish', timeoutMs: 1000, files: {}, validation: false, run: 'ship-run', ...(forged ? { mission: { route: 'goal' as const, run: 'ship-run', deadline: Date.now() + 60000, waits: [] } } : {}) };
      let id: TaskId<{ status: string }> | undefined;
      try { id = (await host.start('command', input)).taskId; }
      catch (error) { assert.match(String(error), /mission|manifest|parent|standalone/i); }
      if (id) {
        const task = await host.harness.waitForTask(id, ctx);
        assert.notEqual(task.state.outcome.status === 'completed' && task.state.outcome.result.status, 'passed');
      }
      await assert.rejects(readFile(marker), { code: 'ENOENT' });
      assert.equal((await host.harness.snapshot(State, ctx))!.grants.publish.usedBy, null);
    } finally { await host.close(); }
  }
});

test('ship can publish before the CI wait that depends on that publication', async () => {
  const w = await workspace(); const checks = join(w.cwd, 'checks.json'); const marker = join(w.cwd, 'published'); const exe = join(w.cwd, 'git');
  await writeFile(checks, JSON.stringify({ head: 'head', checks: [] }));
  await writeFile(exe, `#!${process.execPath}\nconst fs=require('node:fs');fs.writeFileSync(${JSON.stringify(marker)}, 'published');fs.writeFileSync(${JSON.stringify(checks)}, ${JSON.stringify(JSON.stringify({ head: 'head', checks: [{ name: 'tests', head: 'head', state: 'SUCCESS' }] }))});\n`); await chmod(exe, 0o700);
  const host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  let parent: number | undefined;
  try {
    const argv = [exe, 'push', 'fixture']; const validation = [process.execPath, '-e', 'process.exit(0)'];
    await host.handle({ command: 'grant', payload: { key: 'publish', argv, consumer: 'publish', expiresAt: Date.now() + 60000, evidence: 'owned local publication fixture' } });
    await host.handle({ command: 'grant', payload: { key: 'validate', argv: validation, expiresAt: Date.now() + 60000, evidence: 'local validation fixture' } });
    await host.ledger.export('review', { event: 'review_completed', run: 'ship-run', detail: { status: 'GO', evidence: 'current fixture review' } });
    const input: GroupInput = { key: 'ship-parent', kind: 'mission', route: 'ship', run: 'ship-run', objective: 'publish then wait', maxAttempts: 3, deadline: Date.now() + 10000, steps: [
      { name: 'publish', kind: 'command', dependsOn: [], input: { key: 'publish', argv, grantId: 'publish', timeoutMs: 1000, files: {}, validation: false, run: 'ship-run' } },
      { name: 'ci', kind: 'wait', dependsOn: ['publish'], input: { key: 'ci', repo: 'fixture/repo', pr: 1, head: 'head', deadline: Date.now() + 9000, intervalMs: 20, fixture: checks } },
      { name: 'validate', kind: 'command', dependsOn: ['ci'], input: { key: 'validate', argv: validation, grantId: 'validate', timeoutMs: 1000, files: {}, validation: true, run: 'ship-run' } },
    ] };
    parent = (await host.start('group', input)).taskId;
    const view = await until(() => host.snapshot(), view => view.state.workflow.work.some(work => work.key === 'ship-parent' && (work.phase === 'awaiting_evidence' || work.result)));
    assert.equal(await readFile(marker, 'utf8'), 'published');
    assert.equal(view.state.workflow.work.find(work => work.key === 'publish')?.result, 'passed');
    assert.equal(view.state.workflow.work.find(work => work.key === 'ci')?.result, 'passed');
    assert.equal(view.state.workflow.work.find(work => work.key === 'ship-parent')?.phase, 'awaiting_evidence');
  } finally { if (parent) await host.handle({ command: 'cancel', payload: { id: parent } }); await host.close(); }
});

test('a detached command descendant is not accepted as an unqualified completed effect', async () => {
  const w = await workspace(); const marker = join(w.cwd, 'late'); const pidFile = join(w.cwd, 'descendant.pid');
  const child = `setTimeout(()=>require('node:fs').writeFileSync(${JSON.stringify(marker)},'late'),600)`;
  const script = `const p=require('node:child_process').spawn(process.execPath,['-e',${JSON.stringify(child)}],{detached:true,stdio:'ignore'});require('node:fs').writeFileSync(${JSON.stringify(pidFile)}, String(p.pid));p.unref();`;
  try {
    const receipt = await command(w.dir, w.cwd, 1, { key: 'detach', argv: [process.execPath, '-e', script], grantId: 'fixture', timeoutMs: 2000, files: {}, validation: false, run: null }, new AbortController().signal);
    assert.equal(receipt.interrupted, true);
    await new Promise(resolve => setTimeout(resolve, 700));
    await assert.rejects(readFile(marker), { code: 'ENOENT' });
  } finally {
    try { const pid = Number(await readFile(pidFile, 'utf8')); if (Number.isInteger(pid) && pid > 0) process.kill(pid, 'SIGKILL'); } catch (error) { if (!['ESRCH', 'ENOENT'].includes((error as NodeJS.ErrnoException).code ?? '')) throw error; }
  }
});

test('command supervision leaves an unrelated process alive and respects the recorded absolute deadline', async () => {
  const w = await workspace(); const marker = join(w.cwd, 'expired');
  const unrelated = spawn(process.execPath, ['-e', 'setInterval(()=>{},1000)'], { stdio: 'ignore' });
  try {
    const expired = await command(w.dir, w.cwd, 1, { key: 'expired', argv: [process.execPath, '-e', `require('node:fs').writeFileSync(${JSON.stringify(marker)},'expired')`], grantId: 'fixture', timeoutMs: 10000, files: {}, validation: false, run: null, mission: { route: 'goal', run: 'proof', deadline: Date.now() - 1000 } }, new AbortController().signal);
    assert.equal(expired.interrupted, true);
    await assert.rejects(readFile(marker), { code: 'ENOENT' });
    const finished = await command(w.dir, w.cwd, 2, { key: 'foreground', argv: [process.execPath, '-e', 'process.stdout.write("done")'], grantId: 'fixture', timeoutMs: 1000, files: {}, validation: false, run: null }, new AbortController().signal);
    assert.equal(finished.interrupted, false);
    assert.equal(finished.stdout, 'done');
    assert.equal(unrelated.exitCode, null); assert.equal(unrelated.signalCode, null);
    assert.equal(finished.containment?.scope, 'observed-birth-lineage');
  } finally { const exit = new Promise(resolve => unrelated.once('exit', resolve)); unrelated.kill('SIGKILL'); await exit; }
});

test('mission-bound command tool replay joins its immutable child after SIGKILL', async () => {
  const w = await workspace(); const marker = join(w.cwd, 'once');
  let p = await processHost(w, [{ tool: { name: 'run_granted_command', args: { grantId: 'nested' } } }, 'done']);
  const deadline = Date.now() + 60000;
  const argv = [process.execPath, '-e', `require('node:fs').appendFileSync(${JSON.stringify(marker)},'once');setTimeout(()=>{},10000)`];
  const validation = [process.execPath, '-e', 'process.exit(0)'];
  const input: GroupInput = { key: 'parent', kind: 'mission', route: 'goal', run: 'proof', objective: 'stable owned tool replay', maxAttempts: 2, deadline, steps: [
    { name: 'writer', kind: 'agent', dependsOn: [], input: { key: 'writer', prompt: 'run the granted command', role: 'writer', model: null, files: {}, review: false } },
    { name: 'validate', kind: 'command', dependsOn: ['writer'], input: { key: 'validate', argv: validation, grantId: 'validation', timeoutMs: 1000, files: {}, validation: true, run: 'proof' } },
  ] };
  try {
    await p.rpc({ command: 'grant', payload: { key: 'nested', argv, consumer: 'writer', expiresAt: Date.now() + 60000, evidence: 'recorded writer command fixture' } });
    await p.rpc({ command: 'grant', payload: { key: 'validation', argv: validation, expiresAt: Date.now() + 60000, evidence: 'validation fixture' } });
    await p.rpc({ command: 'goal', payload: input });
    await until(async () => { try { return await readFile(marker, 'utf8'); } catch { return ''; } }, value => value === 'once');
    const before = await p.rpc({ command: 'state' }) as Awaited<ReturnType<Host['snapshot']>>;
    const child = before.state.workflow.work.find(work => work.key.startsWith('tool-command:'))!;
    const toolId = Number(child.key.split(':')[1]);
    await p.kill();
    await until(async () => { try { return await readFile(join(w.session, `command-${child.taskId}.receipt.json`), 'utf8'); } catch { return ''; } }, Boolean);
    p = await processHost(w, ['resumed']);
    const tool = await until(() => p.rpc({ command: 'task', payload: { id: toolId } }), value => (value as { state: { status: string } }).state.status === 'terminal');
    assert.equal(JSON.stringify(tool).includes('Work key reused'), false);
    const after = await p.rpc({ command: 'state' }) as Awaited<ReturnType<Host['snapshot']>>;
    assert.equal(after.state.workflow.work.filter(work => work.key.startsWith('tool-command:')).length, 1);
    assert.equal(after.state.workflow.work.find(work => work.key === child.key)?.taskId, child.taskId);
    assert.equal(await readFile(marker, 'utf8'), 'once');
  } finally { await p.kill('SIGTERM'); }
});
