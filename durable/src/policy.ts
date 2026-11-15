import { readFile } from "node:fs/promises";
import { execFileSync } from "node:child_process";

export function githubRepo(value: string): string | undefined {
  const short = /^(?:github\.com\/)?([a-zA-Z0-9-]+)\/([a-zA-Z0-9_.-]+?)(?:\.git)?\/?$/.exec(value);
  const remote = /^(?:git@github\.com:|(?:https|ssh|git):\/\/(?:git@)?github\.com(?::22)?\/)([a-zA-Z0-9-]+)\/([a-zA-Z0-9_.-]+?)(?:\.git)?\/?$/.exec(value);
  const match = short ?? remote;
  return match ? `${match[1]}/${match[2]}` : undefined;
}

export class OwnerPolicy {
  readonly workOrgs: Set<string>;

  constructor(workOrgs: readonly string[]) {
    if (!workOrgs.length || workOrgs.some((org) => !/^[A-Za-z0-9][A-Za-z0-9-]{0,38}$/.test(org))) throw new Error("Invalid work-org deny list; configure a nonempty list");
    this.workOrgs = new Set(workOrgs.map((org) => org.toLowerCase()));
  }

  static async load(host: string, scopePath: string, workOrgsPath: string): Promise<OwnerPolicy> {
    if (host !== "gromarchy") throw new Error("Durable runs require host gromarchy");
    if ((await readFile(scopePath, "utf8").catch(() => "")).trim() !== "personal") throw new Error("Durable runs require explicit personal scope");
    const text = await readFile(workOrgsPath, "utf8").catch(() => "");
    return new OwnerPolicy(text.split(/\r?\n/).map((line) => line.trim()).filter((line) => line && !line.startsWith("#")));
  }

  allow(value: string): string {
    const repo = githubRepo(value);
    const owner = repo?.split("/")[0].toLowerCase();
    if (!repo || !owner || !["tonours", "tonours-dev"].includes(owner) || this.workOrgs.has(owner)) throw new Error("Repository owner refused or unresolved; use Tonours or tonours-dev outside work-orgs");
    return repo;
  }
}

export function git(cwd: string, args: readonly string[]): string {
  return execFileSync("git", ["-C", cwd, ...args], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"], timeout: 2000 }).trim();
}
