import { chmod, mkdir, readdir, rename, unlink } from "node:fs/promises";
import { join } from "node:path";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { randomUUID } from "node:crypto";

export async function backup(state: string, now = new Date()): Promise<string> {
  const directory = join(state, "backups");
  await mkdir(directory, { recursive: true, mode: 0o700 });
  await chmod(directory, 0o700);
  const stamp = now.toISOString().replaceAll(/[-:.]/g, "");
  const target = join(directory, `store-${stamp}.sqlite`);
  const temporary = `${target}.${randomUUID()}.tmp`;
  try {
    await promisify(execFile)("sqlite3", ["-readonly", join(state, "store.sqlite"), ".timeout 10000", `.backup ${JSON.stringify(temporary)}`], { timeout: 30_000 });
    await chmod(temporary, 0o600);
    await rename(temporary, target);
    const snapshots = (await readdir(directory)).filter((file) => /^store-\d{8}T\d{9}Z\.sqlite$/.test(file)).sort();
    for (const file of snapshots.slice(0, -14)) await unlink(join(directory, file));
    return target;
  } finally {
    await unlink(temporary).catch(() => undefined);
  }
}
