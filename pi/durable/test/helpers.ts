import { mkdtemp, realpath, mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { createModels } from '@earendil-works/pi-ai/models';
import { fauxProvider, fauxAssistantMessage, type FauxResponseStep } from '@earendil-works/pi-ai/providers/faux';
import { control } from '../cli.ts';
import { after } from 'node:test';
import type { Request } from '../host.ts';
import type { Json } from '../state.ts';

const ownedProcesses = new Set<ReturnType<typeof spawn>>();
after(async () => {
  for (const child of ownedProcesses) if (child.exitCode === null && child.signalCode === null) { child.kill('SIGKILL'); await new Promise<void>(resolve => child.once('exit', () => resolve())); }
});

export async function workspace() {
  const dir = await realpath(await mkdtemp('/tmp/etabli-durable-test-'));
  const cwd = join(dir, 'repo'); await mkdir(cwd);
  return { dir, cwd, session: join(dir, 'session') };
}

export function fixtureModels(responses: FauxResponseStep[] = [fauxAssistantMessage('complete')], modelId = 'faux-1') {
  const faux = fauxProvider({ models: [{ id: modelId, contextWindow: 100000, maxTokens: 4000 }] });
  faux.setResponses(responses);
  const models = createModels(); models.setProvider(faux.provider);
  return { models, faux, model: { provider: 'faux', modelId } };
}

export function reviewReport(path: string) {
  return JSON.stringify({ verdict: 'GO', findings: [], decidingCode: [{ behavior: 'fixture branch', path, line: 1, resolver: `${path}:1`, decision: 'checked the pinned branch' }], lenses: ['precedence', 'degraded modes', 'impossible states', 'prose vs machine-readable', 'exhaustive reachability', 'asymmetry', 'boundary drift', 'convention'].map(lens => ({ lens, checked: `${path}:1`, found: 'none' })) });
}

export async function until<T>(read: () => Promise<T>, accept: (value: T) => boolean, timeoutMs = 10000): Promise<T> {
  const end = Date.now() + timeoutMs;
  while (Date.now() < end) {
    const value = await read();
    if (accept(value)) return value;
    await new Promise(resolve => setTimeout(resolve, 20));
  }
  throw new Error('Expected durable evidence was not observed before the test deadline');
}

export async function processHost(where: Awaited<ReturnType<typeof workspace>>, responses: (string | { text: string; delayMs?: number } | { tool: { name: string; args: Record<string, Json> }; delayMs?: number })[] = ['answer'], delayMs = 0) {
  const fixture = join(where.dir, 'fixture.json');
  await writeFile(fixture, JSON.stringify({ responses, delayMs }));
  const child = spawn(process.execPath, [fileURLToPath(new URL('../cli.ts', import.meta.url)), 'start', '--session', where.session, '--cwd', where.cwd, '--provider', 'faux', '--model', 'fixture', '--fixture', fixture], { stdio: ['ignore', 'pipe', 'pipe'] });
  ownedProcesses.add(child);
  let stderr = ''; child.stderr.on('data', bytes => { stderr += bytes; });
  const ready = await new Promise<{ sessionId: string; conversationId: number; guardianPid: number }>((resolve, reject) => {
    let stdout = '';
    child.stdout.on('data', bytes => { stdout += bytes; if (stdout.includes('\n')) { try { resolve(JSON.parse(stdout.split('\n')[0])); } catch (error) { reject(error); } } });
    child.once('exit', code => reject(new Error(`Host ended ${code}: ${stderr}`)));
    child.once('error', reject);
  });
  return { child, ready, rpc: (request: Request) => control(where.session, request), async kill(signal: NodeJS.Signals = 'SIGKILL') { const exit = new Promise<void>(resolve => child.once('exit', () => resolve())); child.kill(signal); await exit; } };
}
