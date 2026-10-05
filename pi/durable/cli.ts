import { readFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { createConnection } from 'node:net';
import { homedir } from 'node:os';
import { parseArgs } from 'node:util';
import { Host, type Request } from './host.ts';
import { capability, privateDirectory } from './owner.ts';
import { MobileBridge } from './mobile.ts';
import { ModelRuntime } from '@earendil-works/pi-coding-agent';

export async function control(dir: string, request: Request): Promise<unknown> {
  await privateDirectory(dir);
  const token = await capability(dir);
  return new Promise((resolve, reject) => {
    const socket = createConnection(join(dir, 'control.sock'));
    socket.setEncoding('utf8');
    let text = '';
    socket.setTimeout(120000, () => socket.destroy(new Error('Control request timed out; retry with the same admission/work identity')));
    socket.once('connect', () => socket.write(JSON.stringify({ ...request, capability: token }) + '\n'));
    socket.on('data', bytes => { text += bytes; });
    socket.once('error', reject);
    socket.once('end', () => {
      try {
        const response = JSON.parse(text) as { ok: boolean; result?: unknown; error?: string };
        if (!response.ok) reject(new Error(response.error)); else resolve(response.result);
      } catch (error) { reject(error); }
    });
  });
}

async function main() {
  const { values, positionals } = parseArgs({ allowPositionals: true, options: { session: { type: 'string' }, cwd: { type: 'string' }, provider: { type: 'string' }, model: { type: 'string' }, providers: { type: 'string' }, fixture: { type: 'string' }, file: { type: 'string' }, 'max-requests': { type: 'string' }, deadline: { type: 'string' }, 'mobile-socket': { type: 'string' }, help: { type: 'boolean' } } });
  const command = positionals[0] ?? 'help';
  if (values.help || command === 'help') {
    process.stdout.write('pi-durable models [--provider PROVIDER]\npi-durable start|resume --session DIR --cwd REPO [--provider PROVIDER --model ID --providers LIST]\npi-durable state|handoff|input|agent|command|review|tasks|goal|plan-implement|ship|wait|campaign|compact|task|cancel|grant|budget|reconcile|export|abandon-export --session DIR [--file JSON]\nUse docs/pi-durable.md for manifests, grants and recovery. start is a separate native profile.\n');
    return;
  }
  const dir = resolve(values.session ?? join(homedir(), '.pi/durable/default'));
  if (command === 'models') {
    const runtime = await ModelRuntime.create({ allowModelNetwork: false });
    const models = await runtime.getAvailable();
    process.stdout.write(JSON.stringify(models.filter(model => !values.provider || model.provider === values.provider).map(model => ({ provider: model.provider, modelId: model.id, name: model.name })), null, 2) + '\n');
    return;
  }
  if (command === 'start' || command === 'resume') {
    const host = await Host.open({ dir, cwd: values.cwd ?? process.cwd(), ...(values.provider && values.model ? { model: { provider: values.provider, modelId: values.model } } : {}), ...(values.providers ? { providers: values.providers.split(',') } : {}), ...(values.fixture ? { fixture: values.fixture } : {}), ...(values['max-requests'] ? { maxRequests: Number(values['max-requests']) } : {}), ...(values.deadline ? { deadline: Number(values.deadline) } : {}) });
    await host.listen();
    const mobile = values['mobile-socket'] ? new MobileBridge(host, resolve(values['mobile-socket'])) : null;
    await mobile?.start();
    process.stdout.write(JSON.stringify({ listening: join(dir, 'control.sock'), guardianPid: host.owner.guardian.pid, ...(await host.snapshot()) }) + '\n');
    let closing = false;
    const stop = async () => { if (closing) return; closing = true; mobile?.close(); await host.close(); process.exit(0); };
    process.on('SIGTERM', stop); process.on('SIGINT', stop);
    return;
  }
  const payload = values.file ? JSON.parse(await readFile(resolve(values.file), 'utf8')) : positionals[1] ? JSON.parse(positionals[1]) : undefined;
  process.stdout.write(JSON.stringify(await control(dir, { command, payload }), null, 2) + '\n');
}

if (import.meta.main || process.argv[1]?.endsWith('/cli.ts')) {
  main().catch(error => { process.stderr.write(`${error instanceof Error ? error.message : 'Durable command failed'}\n`); process.exitCode = 1; });
}
