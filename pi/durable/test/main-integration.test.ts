import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { BACKGROUND_CONTEXT as ctx } from '@earendil-works/chord/context';
import { Host } from '../host.ts';
import { execute, ledgerEvents, type LedgerEvent } from '../ledger.ts';
import { State } from '../state.ts';
import { fixtureModels, workspace } from './helpers.ts';

const plan = '# Plan\n- Status: READY\n## Product Verification\n- Required: no\n';

test('enriched export recovers a lost ACK without changing intent or consumed budgets', async () => {
  const w = await workspace(); await writeFile(join(w.cwd, 'PLAN.md'), plan);
  let host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  const event: LedgerEvent = { event: 'plan_created', run: 'main-replay', detail: { path: 'PLAN.md', status: 'READY' } };
  try {
    const flush = host.ledger.flush.bind(host.ledger);
    host.ledger.flush = async id => {
      const item = (await host.harness.snapshot(State, ctx))!.exports[id];
      await execute(join(host.ledger.repo, 'scripts/workflow-event'), ['--dir', join(w.cwd, '.workflow'), 'append', item.run, item.event, JSON.stringify(item.detail)], { cwd: w.cwd });
      throw new Error('lost enriched ACK');
    };
    await assert.rejects(host.ledger.export('main-replay', event), /lost enriched ACK/);
    host.ledger.flush = flush;
    const before = (await host.harness.snapshot(State, ctx))!;
    assert.equal(before.exports['main-replay'].acknowledged, false);
    await host.close();
    host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
    assert.equal(await host.ledger.hasReceipt('main-replay'), true);
    await host.ledger.export('main-replay', event);
    const after = (await host.harness.snapshot(State, ctx))!;
    assert.equal(after.exports['main-replay'].acknowledged, true);
    assert.deepEqual(after.exports['main-replay'].detail, before.exports['main-replay'].detail);
    assert.deepEqual([after.requests, after.maxRequests, after.deadline, after.attempts, after.budgetChanges], [before.requests, before.maxRequests, before.deadline, before.attempts, before.budgetChanges]);
    const rows = await ledgerEvents(w.cwd, event.run);
    assert.equal(rows.length, 1);
    assert.equal(rows[0].detail.product_verification_required, false);
    assert.deepEqual(rows[0].detail.export_source_detail, before.exports['main-replay'].detail);
    await assert.rejects(host.ledger.export('main-replay', { ...event, detail: { ...event.detail, path: 'other.md' } }), /identity collision/);
  } finally { await host.close(); }
});

test('original explicit product fields remain part of exact request identity', async () => {
  const w = await workspace(); await writeFile(join(w.cwd, 'PLAN.md'), plan);
  const host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  const original = { path: 'PLAN.md', status: 'READY', product_verification_required: true, export_id: 'explicit' };
  const args = ['--dir', join(w.cwd, '.workflow'), 'append', 'explicit', 'plan_created'];
  try {
    await execute(join(host.ledger.repo, 'scripts/workflow-event'), [...args, JSON.stringify(original)], { cwd: w.cwd });
    await execute(join(host.ledger.repo, 'scripts/workflow-event'), [...args, JSON.stringify(original)], { cwd: w.cwd });
    await assert.rejects(execute(join(host.ledger.repo, 'scripts/workflow-event'), [...args, JSON.stringify({ ...original, product_verification_required: false })], { cwd: w.cwd }), /export_id collision/);
    const rows = await ledgerEvents(w.cwd, 'explicit');
    assert.equal(rows.length, 1);
    assert.equal(rows[0].detail.product_verification_required, false, 'current plan remains authoritative');
    assert.deepEqual(rows[0].detail.export_source_detail, original);
  } finally { await host.close(); }
});

test('canonical request binding refuses marker injection, redundant markers and tampered targets', async () => {
  const w = await workspace(); await writeFile(join(w.cwd, 'PLAN.md'), plan);
  const host = await Host.open({ dir: w.session, cwd: w.cwd, ...fixtureModels() });
  try {
    await host.ledger.export('binding', { event: 'plan_created', run: 'binding', detail: { path: 'PLAN.md', status: 'READY' } });
    const file = join(w.cwd, '.workflow', 'binding', 'events.jsonl'); const bytes = await readFile(file, 'utf8');
    const row = JSON.parse(bytes) as LedgerEvent;
    await assert.rejects(execute(join(host.ledger.repo, 'scripts/workflow-event'), ['--dir', join(w.cwd, '.workflow'), 'append', 'injection', 'plan_created', JSON.stringify(row.detail)], { cwd: w.cwd }), /invalid json detail|reserved/);
    const source = row.detail.export_source_detail;
    const { export_source_detail: _marker, ...actual } = row.detail;
    const variants = [
      { ...row.detail, export_source_detail: [] },
      { ...row.detail, export_source_detail: { ...(source as Record<string, unknown>), export_id: 'other' } },
      { ...row.detail, export_source_detail: { ...(source as Record<string, unknown>), export_source_detail: source } },
      { ...row.detail, export_source_detail: actual },
      { ...row.detail, path: 'changed-target.md' },
    ];
    for (const detail of variants) {
      await writeFile(file, JSON.stringify({ ...row, detail }) + '\n');
      await assert.rejects(host.ledger.validate('binding'), /invalid detail/);
    }
    await writeFile(file, bytes);
    await host.ledger.validate('binding');
    assert.equal(await host.ledger.hasReceipt('binding'), true);
  } finally { await host.close(); }
});
