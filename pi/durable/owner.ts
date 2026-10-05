import { spawn, type ChildProcessWithoutNullStreams } from 'node:child_process';
import { lstat, mkdir, readFile, writeFile } from 'node:fs/promises';
import { randomBytes } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

export async function privateDirectory(path: string) {
  await mkdir(path, { recursive: true, mode: 0o700 });
  const stat = await lstat(path);
  if (!stat.isDirectory() || stat.isSymbolicLink() || stat.uid !== process.getuid?.() || (stat.mode & 0o777) !== 0o700) {
    throw new Error(`Private directory must be owned by this user, mode 0700, without a symlink: ${path}`);
  }
}

export async function privateFile(path: string) {
  const stat = await lstat(path);
  if (!stat.isFile() || stat.isSymbolicLink() || stat.uid !== process.getuid?.() || (stat.mode & 0o777) !== 0o600) {
    throw new Error(`Private file must be owned by this user, mode 0600, without a symlink: ${path}`);
  }
}

export class Owner {
  #alive = true;
  #closing = false;
  readonly guardian: ChildProcessWithoutNullStreams;
  constructor(guardian: ChildProcessWithoutNullStreams) {
    this.guardian = guardian;
    guardian.on('exit', () => {
      this.#alive = false;
      if (!this.#closing) process.exit(74);
    });
    guardian.stdout.on('end', () => {
      this.#alive = false;
      if (!this.#closing) process.exit(74);
    });
  }
  assert() {
    if (!this.#alive || this.guardian.exitCode !== null || this.guardian.signalCode !== null) {
      throw new Error('Owner lock lost; stop this host and reopen before writing');
    }
  }
  close() {
    this.#closing = true;
    this.#alive = false;
    this.guardian.stdin.end();
  }
}

export async function acquireOwner(dir: string): Promise<Owner> {
  await privateDirectory(dir);
  const guardian = spawn(process.env.ETABLI_DURABLE_PYTHON ?? 'python3', [fileURLToPath(new URL('./owner.py', import.meta.url)), join(dir, 'owner.lock')], { stdio: 'pipe' });
  await new Promise<void>((resolve, reject) => {
    guardian.once('error', reject);
    guardian.stdout.once('data', data => {
      if (String(data).trim() === 'OWNED') resolve();
      else reject(new Error('This session already has an owner; connect to it or stop it before reopening'));
    });
    guardian.once('exit', code => reject(new Error(`Owner guardian unavailable (${code}); verify python3 and flock support`)));
  });
  return new Owner(guardian);
}

export async function capability(dir: string): Promise<string> {
  const path = join(dir, 'capability');
  try {
    await writeFile(path, randomBytes(32).toString('hex'), { mode: 0o600, flag: 'wx' });
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== 'EEXIST') throw error;
  }
  await privateFile(path);
  const value = await readFile(path, 'utf8');
  if (!/^[a-f0-9]{64}$/.test(value)) throw new Error('Invalid local capability; restore its private file before starting');
  return value;
}
