import { spawn } from 'node:child_process';
import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';
import { fingerprint, type MissionContext } from './state.ts';
import { privateFile } from './owner.ts';

export type CommandInput = { key: string; argv: string[]; grantId: string; timeoutMs: number; files: Record<string, string>; validation: boolean; run: string | null; mission?: MissionContext | null; toolSurface?: boolean; consumer?: string };
export type Receipt = { inputHash: string; taskId: number; exit: number; interrupted: boolean; stdout: string; stderr: string; finishedAt: number; argv: string[]; cwd: string; containment?: { scope: string; platform: string; trackingComplete: boolean } };

export async function commandReceipt(dir: string, taskId: number, input: CommandInput): Promise<Receipt | null> {
  const path = join(dir, `command-${taskId}.receipt.json`);
  try {
    await privateFile(path);
    const value = JSON.parse(await readFile(path, 'utf8')) as Receipt;
    if (value.inputHash !== fingerprint(input) || value.taskId !== taskId || !Number.isInteger(value.exit) || typeof value.interrupted !== 'boolean' || typeof value.stdout !== 'string' || typeof value.stderr !== 'string') throw new Error('Command receipt identity or outcome is invalid; preserve it for reconciliation');
    if (value.containment?.scope !== 'observed-birth-lineage' || typeof value.containment.trackingComplete !== 'boolean' || (!value.containment.trackingComplete && !value.interrupted)) throw new Error('Command receipt has no current containment proof; preserve it for human reconciliation');
    return value;
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') return null;
    throw error;
  }
}

export async function command(dir: string, cwd: string, taskId: number, input: CommandInput, signal: AbortSignal, beforeLaunch?: () => Promise<void>): Promise<Receipt> {
  const path = join(dir, `command-${taskId}.input.json`);
  await writeFile(path, JSON.stringify({ ...input, cwd, taskId, inputHash: fingerprint(input), receipt: join(dir, `command-${taskId}.receipt.json`) }), { mode: 0o600, flag: 'wx' });
  await beforeLaunch?.();
  const worker = spawn('python3', [fileURLToPath(new URL('./command-worker.py', import.meta.url)), path], { stdio: ['pipe', 'ignore', 'pipe'] });
  const stop = () => worker.stdin.end();
  signal.addEventListener('abort', stop, { once: true });
  if (signal.aborted) stop();
  try {
    await new Promise<void>((resolve, reject) => {
      worker.once('error', reject);
      worker.once('exit', code => code === 0 ? resolve() : reject(new Error(`Command worker exited ${code}; inspect its retained receipt before retry`)));
    });
  } finally {
    signal.removeEventListener('abort', stop);
    worker.stdin.end();
  }
  const receipt = await commandReceipt(dir, taskId, input);
  if (!receipt) throw new Error('Command ended without a valid receipt; reconcile the external effect');
  return receipt;
}
