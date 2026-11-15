import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";

export async function writerLock(path: string, lost: () => void = () => process.exit(1)): Promise<() => Promise<void>> {
  const child: ChildProcessWithoutNullStreams = spawn("flock", ["--nonblock", path, "sh", "-c", "printf 'locked\\n'; cat >/dev/null"], { stdio: ["pipe", "pipe", "pipe"] });
  await new Promise<void>((resolve, reject) => {
    child.once("error", () => reject(new Error("Daemon requires flock for process exclusivity")));
    child.once("exit", () => reject(new Error("A daemon already owns this state directory")));
    child.stdout.once("data", () => resolve());
  });
  let closing = false;
  child.once("exit", () => { if (!closing) lost(); });
  return async () => {
    closing = true;
    if (child.exitCode !== null || child.signalCode !== null) return;
    const ended = new Promise<void>((resolve) => child.once("exit", () => resolve()));
    child.stdin.end();
    await ended;
  };
}
