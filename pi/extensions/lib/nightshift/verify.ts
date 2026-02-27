import { execSync } from "node:child_process";

export interface VerifyResult {
  status: "ok" | "failed";
  failedCommand?: string;
}

export async function runVerify(workDir: string, commands: string[]): Promise<VerifyResult> {
  for (const cmd of commands) {
    if (!cmd.trim()) continue;

    try {
      execSync(cmd, { cwd: workDir, stdio: "ignore", shell: "/bin/bash" });
    } catch {
      return { status: "failed", failedCommand: cmd };
    }
  }

  return { status: "ok" };
}
