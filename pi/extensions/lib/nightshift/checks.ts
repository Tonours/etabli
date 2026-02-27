import { execFileSync } from "node:child_process";

export function checkBinaries(names: string[]): { missing: string[] } {
  const missing: string[] = [];

  for (const name of names) {
    try {
      execFileSync("which", [name], { stdio: "ignore" });
    } catch {
      missing.push(name);
    }
  }

  return { missing };
}
