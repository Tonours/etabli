import { mkdtemp, writeFile, rm, mkdir } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { execFileSync } from "node:child_process";
import { createModels, type CredentialStore } from "@earendil-works/pi-ai";
import { fauxProvider } from "@earendil-works/pi-ai/providers/faux";
import { openCore } from "../src/daemon.ts";
import { OwnerPolicy } from "../src/policy.ts";
import { Repositories } from "../src/repositories.ts";
import type { runCliReview } from "../src/review-cli.ts";
import type { Command } from "../src/publish.ts";

export async function localRepo(root: string): Promise<string> {
  const path = join(root, "source");
  await mkdir(path, { recursive: true });
  const run = (args: string[]) => execFileSync("git", ["-C", path, ...args], { stdio: "ignore" });
  run(["init", "-b", "main"]);
  run(["config", "user.email", "fixture@example.invalid"]);
  run(["config", "user.name", "Fixture"]);
  await writeFile(join(path, "check.sh"), "test -f result.txt\n");
  run(["add", "."]);
  run(["commit", "-m", "init fixture"]);
  return path;
}

export async function fixture(options: { wallMs?: number; maxTurns?: number; now?: () => number; notifyArgv?: string[]; credentials?: CredentialStore; workflow?: boolean; subagentModel?: Parameters<typeof openCore>[0]["subagentModel"]; mcpServers?: Record<string, unknown>; reviewCli?: typeof runCliReview; publishCommand?: Command; ciCommand?: Command; web?: Parameters<typeof openCore>[0]["web"] } = {}) {
  const root = await mkdtemp(join(tmpdir(), "etabli-durable-test-"));
  const source = await localRepo(root);
  const state = join(root, "state");
  const policy = new OwnerPolicy(["ForestAdmin", "Galaxies-dev"]);
  const faux = fauxProvider({ provider: options.workflow ? "zai" : "fixture", models: [{ id: options.workflow ? "glm-5.3" : "fixture" }] });
  const planner = fauxProvider({ provider: "openai-codex", models: [{ id: "gpt-6.1-sol" }, { id: "gpt-6-astra" }] });
  const models = createModels({ credentials: options.credentials });
  models.setProvider(faux.provider);
  if (options.workflow) models.setProvider(planner.provider);
  const create = () => openCore({ state, policy, models, model: async () => ({ provider: faux.getModel().provider, modelId: faux.getModel().id }), repositories: new Repositories(state, policy, () => source, async (repo) => repo), ...options });
  let core = await create();
  return { root, source, state, policy, models, faux, planner, get core() { return core; }, async reopen() { await core.close(); core = await create(); return core; }, async cleanup() { await core.close(); await rm(root, { recursive: true, force: true }); } };
}

export async function until(fn: () => Promise<boolean>, timeout = 10_000): Promise<void> {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    if (await fn()) return;
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  throw new Error("Timed out waiting for fixture state");
}
