import { execFile } from "node:child_process";
import { promisify } from "node:util";

export async function notify(argv: readonly string[], run: { id: string; status: string; reason: string; url: string }): Promise<void> {
  if (!argv.length) return;
  await promisify(execFile)(argv[0], [...argv.slice(1), run.id, run.status, run.reason, run.url], { timeout: 15_000, maxBuffer: 16_384, encoding: "utf8" }).catch(() => { throw new Error("Notification command failed"); });
}
