import { chmod, mkdir, readdir, rename, unlink, link, stat } from "node:fs/promises";
import { join } from "node:path";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { randomUUID } from "node:crypto";

async function snapshot(state: string, target: string, immutable = false): Promise<void> {
  const temporary = `${target}.${randomUUID()}.tmp`;
  try {
    await promisify(execFile)("sqlite3", ["-readonly", join(state, "store.sqlite"), ".timeout 10000", `.backup ${JSON.stringify(temporary)}`], { timeout: 30_000 });
    await chmod(temporary, immutable ? 0o400 : 0o600);
    if (immutable) await link(temporary, target).catch((error: NodeJS.ErrnoException) => { if (error.code !== "EEXIST") throw error; });
    else await rename(temporary, target);
  } finally { await unlink(temporary).catch(() => undefined); }
}

export async function finalSnapshot(state: string, runId: string, generation = ""): Promise<string> {
  if (!/^[0-9a-f-]{36}$/.test(runId)) throw new Error("Invalid final snapshot run id");
  if (generation && !/^ci-(?:[1-9][0-9]*|exhausted)$/.test(generation)) throw new Error("Invalid final snapshot generation");
  const directory = join(state, "final");
  await mkdir(directory, { recursive: true, mode: 0o700 });
  const target = join(directory, `${runId}${generation ? `.${generation}` : ""}.sqlite`);
  if (!await stat(target).then(() => true, () => false)) await snapshot(state, target, true);
  return target;
}

export async function backup(state: string, now = new Date()): Promise<string> {
  const directory = join(state, "backups");
  await mkdir(directory, { recursive: true, mode: 0o700 });
  await chmod(directory, 0o700);
  const stamp = now.toISOString().replaceAll(/[-:.]/g, "");
  const target = join(directory, `store-${stamp}.sqlite`);
  await snapshot(state, target);
  const snapshots = (await readdir(directory)).filter((file) => /^store-\d{8}T\d{9}Z\.sqlite$/.test(file)).sort();
  for (const file of snapshots.slice(0, -14)) await unlink(join(directory, file));
  return target;
}
