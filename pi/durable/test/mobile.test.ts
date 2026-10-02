import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn, type ChildProcess } from 'node:child_process';
import { createServer } from 'node:net';
import { randomBytes, randomUUID } from 'node:crypto';
import { writeFile, mkdir, readFile } from 'node:fs/promises';
import { runInNewContext } from 'node:vm';
import ts from 'typescript';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { BACKGROUND_CONTEXT as ctx } from '@earendil-works/chord/context';
import { Host } from '../host.ts';
import { MobileBridge } from '../mobile.ts';
import { State } from '../state.ts';
import { fixtureModels, workspace, until } from './helpers.ts';
import { pendingMessage, savePendingMessage, acknowledgeMessage, prepareMessage, recordedTarget, type Store, type SendTarget } from '../../../../pi-mobile/apps/mobile/outbox.ts';
import type { PhoneSnapshot } from '../../../../pi-mobile/packages/protocol/src/index.ts';

test('phone outbox commits exact Unicode content before admission and keeps one identity after app reload', async () => {
  const values = new Map<string, string>();
  const store: Store = { async getItemAsync(key) { return values.get(key) ?? null; }, async setItemAsync(key, value) { assert.ok(Buffer.byteLength(value) <= 1024); values.set(key, value); }, async deleteItemAsync(key) { values.delete(key); } };
  const message = { admissionId: randomUUID(), machine: 'host-A', sessionId: 'session-A', conversationId: 1, text: '🙂é exact text\n'.repeat(1000), deliverAs: 'steer' as const };
  await savePendingMessage(store, 'target', message);
  assert.deepEqual(await pendingMessage({ ...store }, 'target'), message);
  await assert.rejects(savePendingMessage(store, 'target', { ...message, text: message.text.trim() }), /Retry the saved/);
  await assert.rejects(acknowledgeMessage(store, 'target', randomUUID()), /does not match/);
  await acknowledgeMessage(store, 'target', message.admissionId);
  assert.equal(await pendingMessage(store, 'target'), null);
  const failing = { ...store, async setItemAsync(key: string, value: string) { if (key === 'pi-mobile.outbox.incomplete') throw new Error('crash before head commit'); await store.setItemAsync(key, value); } };
  await assert.rejects(savePendingMessage(failing, 'incomplete', { ...message, admissionId: randomUUID() }), /crash/);
  assert.equal(await pendingMessage(store, 'incomplete'), null);
});

test('the actual App HTTP snapshot callback preserves independent WebSocket admission metadata', async () => {
  const source = await readFile(new URL('../../../../pi-mobile/apps/mobile/App.tsx', import.meta.url), 'utf8');
  const parsed = ts.createSourceFile('App.tsx', source, ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);
  let callback: ts.Expression | undefined;
  const visit = (node: ts.Node) => {
    if (ts.isVariableDeclaration(node) && node.name.getText(parsed) === 'snapshot' && node.initializer && ts.isCallExpression(node.initializer) && node.initializer.expression.getText(parsed) === 'useCallback') callback = node.initializer.arguments[0];
    ts.forEachChild(node, visit);
  };
  visit(parsed); assert.ok(callback);
  let header: SendTarget = { sessionId: 'target', conversationId: 1, durableAdmission: true, streaming: false };
  let received: PhoneSnapshot | null = null;
  const http: PhoneSnapshot = { sessionId: 'target', seq: 1, conversationId: 1, leafId: null, messages: [], state: { streaming: false, model: null, sessionFile: null, sessionName: null, cwd: '/fixture' } };
  const context = { module: { exports: null }, api: async () => http, machine: {}, sessionId: 'target', fetchingRef: { current: false }, lastSeqRef: { current: 0 }, bufferedRef: { current: [] }, setReloading() {}, setListMessages() {}, setWorkflow() {}, setLiveMessages() {}, setError() {}, setEnded() {}, setSendSnapshot(value: PhoneSnapshot) { received = value; }, setHeader(update: (previous: SendTarget) => SendTarget) { header = update(header); } };
  runInNewContext(ts.transpileModule(`module.exports = ${callback.getText(parsed)}`, { compilerOptions: { target: ts.ScriptTarget.ES2022 } }).outputText, context);
  await (context.module.exports as unknown as () => Promise<void>)();
  assert.equal(header.durableAdmission, true); assert.equal(header.conversationId, 1);
  const target = recordedTarget(header, received); assert.equal(target, null);
  let posts = 0;
  const store: Store = { async getItemAsync() { return null; }, async setItemAsync() {}, async deleteItemAsync() {} };
  await assert.rejects(async () => { await prepareMessage(store, 'target', target, { machine: 'host', sessionId: 'target', text: 'exact', deliverAs: null }, randomUUID); posts++; }, /context.*unknown/i);
  assert.equal(posts, 0);
});

async function connector(config: string, cwd: string) {
  const child = spawn(process.execPath, ['src/index.ts'], { cwd, env: { ...process.env, PI_MOBILE_CONFIG: config }, stdio: ['ignore', 'pipe', 'pipe'] });
  let stderr = '';
  child.stderr.on('data', bytes => { stderr += bytes; });
  await new Promise<void>((resolve, reject) => { child.stdout.on('data', bytes => { if (String(bytes).includes('ready')) resolve(); }); child.once('error', reject); child.once('exit', code => reject(new Error(`Connector stopped ${code}: ${stderr}`))); });
  return child;
}

async function stop(child: ChildProcess) {
  const exited = new Promise<void>(resolve => child.once('exit', () => resolve()));
  child.kill('SIGKILL'); await exited;
}

test('real connector HTTP and terminal share committed state; retries survive connector and host restarts', async () => {
  const w = await workspace();
  const config = join(w.dir, 'connector'); await mkdir(config, { mode: 0o700 });
  const portServer = createServer(); await new Promise<void>(resolve => portServer.listen(0, '127.0.0.1', resolve));
  const address = portServer.address(); assert.ok(address && typeof address === 'object'); const port = address.port;
  await new Promise<void>(resolve => portServer.close(() => resolve()));
  const token = randomBytes(32).toString('hex');
  const socket = join(config, 'bridge.sock');
  await writeFile(join(config, 'connector.json'), JSON.stringify({ token, bridgeSocket: socket, httpPort: port, workspaces: [w.cwd] }), { mode: 0o600 });
  const connectorCwd = fileURLToPath(new URL('../../../../pi-mobile/apps/connector', import.meta.url));
  let peer = await connector(config, connectorCwd);
  let host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  let bridge = new MobileBridge(host, socket); await bridge.start();
  let posts = 0;
  const api = async <T = Record<string, unknown>>(method: string, path: string, body?: unknown) => {
    if (method === 'POST') posts++;
    const response = await fetch(`http://127.0.0.1:${port}${path}`, { method, headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' }, ...(body ? { body: JSON.stringify(body) } : {}) });
    return { status: response.status, body: await response.json() as T };
  };
  const id = (await host.snapshot()).sessionId;
  const register = () => until(async () => { try { return await api('GET', '/sessions'); } catch { return null; } }, value => Boolean((value?.body.sessions as { sessionId: string }[] | undefined)?.some(session => session.sessionId === id)));
  try {
    await register();
    const values = new Map<string, string>();
    const store: Store = { async getItemAsync(key) { return values.get(key) ?? null; }, async setItemAsync(key, value) { values.set(key, value); }, async deleteItemAsync(key) { values.delete(key); } };
    const outgoing = { machine: `http://127.0.0.1:${port}`, sessionId: id, text: 'phone message 🙂', deliverAs: 'followUp' as const };
    const prepare = (target: SendTarget | null) => prepareMessage(store, 'phone', target, outgoing, randomUUID);
    const send = async (target: SendTarget | null) => {
      const saved = await prepare(target);
      return api('POST', `/sessions/${id}/send`, saved ? { admissionId: saved.admissionId, conversationId: saved.conversationId, text: saved.text, deliverAs: saved.deliverAs } : { text: outgoing.text });
    };
    await assert.rejects(send(null), /context.*unknown/i);
    await assert.rejects(send({ sessionId: id, durableAdmission: true, streaming: false }), /incomplete/i);
    const initial = (await api<PhoneSnapshot>('GET', `/sessions/${id}`)).body;
    await assert.rejects(send(recordedTarget({ sessionId: id, durableAdmission: false, streaming: false }, initial)), /context.*unknown/i);
    assert.equal(posts, 0); assert.equal((await host.snapshot()).messages.filter(message => message.role === 'user').length, 0);
    const saved = await prepare(recordedTarget(null, initial)); assert.ok(saved);
    await assert.rejects(prepare(recordedTarget(null, { sessionId: id, state: { streaming: false } })), /Saved message/);
    assert.deepEqual(await pendingMessage(store, 'phone'), saved);
    const message = { admissionId: saved.admissionId, conversationId: saved.conversationId, text: saved.text, deliverAs: saved.deliverAs };
    const first = await api('POST', `/sessions/${id}/send`, message);
    assert.equal(first.body.durableAdmission, true);
    await host.root.waitForIdle(ctx);
    const terminal = await host.snapshot();
    assert.deepEqual((await api('GET', `/sessions/${id}`)).body, terminal);
    const before = (await host.harness.snapshot(State, ctx))!.requests;
    await stop(peer);
    bridge.close(); await host.close();
    peer = await connector(config, connectorCwd);
    host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
    bridge = new MobileBridge(host, socket); await bridge.start();
    await register();
    const fresh = (await api<PhoneSnapshot>('GET', `/sessions/${id}`)).body;
    assert.deepEqual(await prepare(recordedTarget(null, fresh)), saved);
    const retry = await api('POST', `/sessions/${id}/send`, message);
    assert.equal(retry.body.admissionId, message.admissionId);
    assert.equal((await host.harness.snapshot(State, ctx))!.requests, before);
    assert.equal((await host.snapshot()).messages.filter(message => message.role === 'user').length, 1);
    await acknowledgeMessage(store, 'phone', message.admissionId);
    assert.equal(await pendingMessage(store, 'phone'), null);
    assert.equal((await api('POST', `/sessions/${id}/send`, { ...message, text: 'changed' })).body.status, 'failed');
    assert.equal((await api('POST', `/sessions/${id}/send`, { ...message, conversationId: 2 })).status, 409);
    assert.equal(await prepare(recordedTarget(null, { sessionId: id, state: { streaming: false } })), null);
    const oldPhone = await api('POST', `/sessions/${id}/send`, { text: 'older client' });
    assert.equal(oldPhone.body.durableAdmission, false);
  } finally { bridge.close(); await host.close(); await stop(peer); }
});
