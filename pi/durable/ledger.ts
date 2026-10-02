import { execFile } from 'node:child_process';
import { createHash } from 'node:crypto';
import { promisify } from 'node:util';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import type { Harness } from '@earendil-works/pi-durable';
import { BACKGROUND_CONTEXT as ctx } from '@earendil-works/chord/context';
import { State, fingerprint, type Json } from './state.ts';
import { redact } from './egress.ts';

export const execute = promisify(execFile);
export type LedgerEvent = { event: string; run: string; schema_version?: number; detail: Record<string, Json> };

export async function ledgerHash(cwd: string, run: string) {
  let bytes: Buffer;
  try { bytes = await readFile(join(cwd, '.workflow', run, 'events.jsonl')); }
  catch (error) { if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error; bytes = Buffer.alloc(0); }
  return createHash('sha256').update(bytes).digest('hex');
}

export async function ledgerEvents(cwd: string, run: string): Promise<LedgerEvent[]> {
  try {
    const text = await readFile(join(cwd, '.workflow', run, 'events.jsonl'), 'utf8');
    return text.trim().split('\n').filter(Boolean).map(line => JSON.parse(line) as LedgerEvent);
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') return [];
    throw error;
  }
}

export class Ledger {
  readonly harness: Harness;
  readonly repo: string;
  readonly cwd: string;
  constructor(harness: Harness, repo: string, cwd: string) { this.harness = harness; this.repo = repo; this.cwd = cwd; }
  async validate(run: string) {
    await execute(join(this.repo, 'scripts/workflow-event'), ['--dir', join(this.cwd, '.workflow'), 'validate', run], { cwd: this.cwd });
  }
  async export(id: string, event: LedgerEvent, expected?: string) {
    const detail = { ...event.detail, export_id: id };
    const precondition = expected ?? (['completed', 'blocked', 'ship_completed'].includes(event.event) ? await ledgerHash(this.cwd, event.run) : null);
    await this.harness.commit(async tx => {
      const state = await tx.doc(State);
      const prior = state.exports[id];
      if (prior && fingerprint([prior.event, prior.run, prior.detail]) !== fingerprint([event.event, event.run, detail])) throw new Error('Pending ledger export identity collision');
      if (!prior) state.exports[id] = { event: event.event, run: event.run, detail, acknowledged: false, precondition };
    }, ctx);
    await this.flush(id);
  }
  async hasReceipt(id: string) {
    const item = (await this.harness.snapshot(State, ctx))?.exports[id];
    if (!item) return false;
    const recorded = (await ledgerEvents(this.cwd, item.run)).find(event => event.detail.export_id === id);
    if (!recorded) return false;
    const enriched = Object.hasOwn(recorded.detail, 'export_source_detail');
    if (enriched) await this.validate(item.run);
    const sourceDetail = enriched ? recorded.detail.export_source_detail : recorded.detail;
    if (fingerprint([recorded.event, recorded.run, sourceDetail]) !== fingerprint([item.event, item.run, item.detail])) throw new Error('Recorded ledger export identity collision');
    return true;
  }
  async flush(id: string) {
    const item = (await this.harness.snapshot(State, ctx))?.exports[id];
    if (!item) throw new Error('Missing pending ledger export');
    if (item.abandoned && !await this.hasReceipt(id)) throw new Error('Pending export was abandoned by the human; use a fresh evaluated intent');
    const terminal = ['completed', 'blocked', 'ship_completed'].includes(item.event);
    try {
      // Old terminal intents cannot gain new authority on reopen. An already appended ID still ACKs.
      const expected = item.precondition ?? (terminal ? '0'.repeat(64) : null);
      await execute(join(this.repo, 'scripts/workflow-event'), ['--dir', join(this.cwd, '.workflow'), ...(expected ? ['--expected-ledger-sha256', expected] : []), 'append', item.run, item.event, JSON.stringify(item.detail)], { cwd: this.cwd });
    } catch (error) {
      await this.harness.commit(async tx => { (await tx.doc(State)).exports[id].error = redact(error instanceof Error ? error.message : 'Canonical export refused'); }, ctx);
      throw error;
    }
    await this.harness.commit(async tx => { const item = (await tx.doc(State)).exports[id]; item.acknowledged = true; item.error = null; }, ctx);
  }
  async reconcile() {
    const state = await this.harness.snapshot(State, ctx);
    for (const [id, item] of Object.entries(state?.exports ?? {})) if (!item.acknowledged) {
      try { if (!item.abandoned || await this.hasReceipt(id)) await this.flush(id); }
      catch { process.stderr.write(`Durable: canonical export ${id} blocked; inspect private handoff and repair its prerequisites\n`); }
    }
  }
  async abandon(id: string, evidence: string) {
    if (!evidence.trim()) throw new Error('Abandoning a pending export requires human evidence');
    await this.harness.commit(async tx => {
      const item = (await tx.doc(State)).exports[id];
      if (!item || item.acknowledged) throw new Error('No pending export with this identity');
      item.abandoned = evidence;
    }, ctx);
  }
  async round(run: string, round: string) {
    let events = await ledgerEvents(this.cwd, run);
    if (!events.some(event => event.event === 'route_decided' && (event.detail.route === 'plan-implement' || (event.detail.route === 'review' && event.detail.contract_path === 'pi/durable')))) {
      await this.export(`review-route:${run}`, { event: 'route_decided', run, detail: { route: 'review', contract_path: 'pi/durable', provenance: 'repo', reason: 'Native Durable review uses the canonical T/D/F budget' } });
    }
    await this.validate(run);
    events = await ledgerEvents(this.cwd, run);
    const closed = events.find(e => e.event === 'review_completed' && e.detail.review_round === round);
    if (closed) return closed;
    const candidate = { schema_version: 2, event: 'review_completed', detail: { review_round: round, round_outcome: 'findings', status: 'GO' } };
    const probe = [...events, { schema_version: 2, event: 'adversary_completed', detail: { mode: 'code_diff', verdict: 'GO', accepted_findings: [] } }, candidate];
    const rules = (await readFile(join(this.repo, 'scripts/lib/review-rounds.jq'), 'utf8')).replace(/\nenvelope_error \/\/ round_error \/\/ empty\s*$/, '\n');
    const { stdout } = await execute('jq', ['-n', '--argjson', 'events', JSON.stringify(probe), `${rules}\n$events | round_error // empty`]);
    if (stdout.trim()) throw new Error(stdout.trim());
    return null;
  }
}
