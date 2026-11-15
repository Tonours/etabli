import { expect, test } from "bun:test";
import { mkdtemp, mkdir, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { execFileSync } from "node:child_process";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { AgentDoc, configure } from "@earendil-works/pi-durable";
import { fauxAssistantMessage, fauxToolCall } from "@earendil-works/pi-ai/providers/faux";
import { OwnerPolicy } from "../src/policy.ts";
import { invocationGuard, guardedAgent, createGuards, remoteDefaultBranch } from "../src/guards.ts";
import { fixture, localRepo } from "./helpers.ts";

test("host, explicit personal scope and work-owner denial fail closed", async () => {
  const root = await mkdtemp(join(tmpdir(), "durable-policy-"));
  try {
    const scope = join(root, "scope");
    const orgs = join(root, "orgs");
    await expect(OwnerPolicy.load("elsewhere", scope, orgs)).rejects.toThrow("gromarchy");
    await expect(OwnerPolicy.load("gromarchy", scope, orgs)).rejects.toThrow("personal");
    await writeFile(scope, "personal\n");
    await expect(OwnerPolicy.load("gromarchy", scope, orgs)).rejects.toThrow("deny list");
    await writeFile(orgs, "ForestAdmin\ninvalid/org\n");
    await expect(OwnerPolicy.load("gromarchy", scope, orgs)).rejects.toThrow("deny list");
    await writeFile(orgs, "# Work organizations\n\nForestAdmin\nTonours-dev\n");
    const policy = await OwnerPolicy.load("gromarchy", scope, orgs);
    expect(policy.allow("git@github.com:Tonours/etabli.git")).toBe("Tonours/etabli");
    for (const repo of ["ForestAdmin/a", "tonours-dev/a", "https://github.com.evil/Tonours/x", "https://github.com/Tonours/x?y"]) expect(() => policy.allow(repo)).toThrow();
  } finally { await rm(root, { recursive: true, force: true }); }
});

test("direct publication invocations resolve cwd, flags, URLs, refspecs and ambiguous neighbors", async () => {
  const root = await mkdtemp(join(tmpdir(), "durable-guards-"));
  try {
    const safe = await localRepo(root);
    const foreign = join(root, "foreign");
    await mkdir(foreign);
    const run = (cwd: string, args: string[]) => execFileSync("git", ["-C", cwd, ...args], { stdio: "ignore" });
    run(safe, ["remote", "add", "origin", "git@github.com:Tonours/fixture.git"]);
    run(safe, ["symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main"]);
    run(foreign, ["init"]);
    run(foreign, ["remote", "add", "origin", "https://github.com/ForestAdmin/fixture.git"]);
    expect(remoteDefaultBranch(safe, safe)).toBe("main");
    const policy = new OwnerPolicy(["ForestAdmin"]);
    const check = (command: string) => invocationGuard(command, safe, policy, () => "main");
    for (const command of [
      "git push origin HEAD:feature", "git push -u origin durable/a", "git push https://github.com/Tonours/fixture.git HEAD:feature", "git push git@github.com:Tonours/fixture.git HEAD:refs/heads/feature",
      "gh pr view 1", "gh pr create --repo Tonours/fixture", "gh -RTonours/fixture pr view", "gh api repos/Tonours/fixture/pulls", "gh repo view Tonours/fixture", "gh pr view https://github.com/Tonours/fixture/pull/1", "echo plain && git status", `cd '${safe}' && gh pr view 1`,
    ]) expect(check(command), command).toBeUndefined();
    for (const command of [
      "git push origin HEAD:main", "git pu\\\nsh origin HEAD:main", "git push origin HEAD:refs/heads/main", "git push origin main", "git push origin", "git push --all origin", "git push --mirror origin", "git push --delete origin feature", "git push origin :feature", "git push origin 'refs/heads/*:refs/heads/*'", "git push -o test origin HEAD:feature", "git -c remote.origin.url=https://github.com/ForestAdmin/f push origin HEAD:feature",
      "git push https://github.com/ForestAdmin/fixture.git HEAD:feature", "git push unknown HEAD:feature", "gh pr merge 1", "gh --repo Tonours/fixture pr merge 1", "gh pr view -R ForestAdmin/fixture", "gh pr view --repo=ForestAdmin/fixture", "gh pr view https://github.com/ForestAdmin/fixture/pull/1", "GH_REPO=ForestAdmin/fixture gh pr view", "env GH_REPO=ForestAdmin/fixture gh pr view", "gh api repos/ForestAdmin/fixture/issues", "gh api user", `cd '${foreign}' && gh pr view 1`, `git -C '${foreign}' push origin HEAD:feature`, `cd '${safe}' || gh pr view 1`, "gh pr view --repo '$TARGET'",
      "GIT_CONFIG_GLOBAL=/tmp/other git push origin HEAD:feature", "GH_HOST=work.example gh pr create", "gh api --hostname work.example repos/Tonours/fixture/issues", "gh repo create ForestAdmin/new", "gh auth token", "git remote set-url origin https://github.com/ForestAdmin/fixture.git",
    ]) expect(check(command), command).toContain("guard");
    run(safe, ["config", "--add", "remote.origin.pushurl", "https://github.com/Tonours/fixture.git"]);
    run(safe, ["config", "--add", "remote.origin.pushurl", "https://github.com/ForestAdmin/fixture.git"]);
    expect(check("git push origin HEAD:feature")).toContain("guard");
  } finally { await rm(root, { recursive: true, force: true }); }
});

test("native shared guards block comments, edit comments and commit attribution; raw children inherit controls", async () => {
  const f = await fixture();
  try {
    const run = await f.core.runs.submit("Tonours/fixture", "guards", "guards");
    f.faux.setResponses([
      fauxAssistantMessage([
        fauxToolCall("write", { path: "guard.ts", content: "const value = 1;\n// forbidden\n" }),
        fauxToolCall("bash", { command: "git commit -m 'fix fixture' --trailer 'Co-authored-by: Claude <fixture@example.invalid>'" }),
        fauxToolCall("bash", { command: "gh pr merge 1" }),
        fauxToolCall("write", { path: "plain.ts", content: "export const value = 1;\n" }),
      ], { stopReason: "toolUse" }),
      fauxAssistantMessage(fauxToolCall("edit", { path: "plain.ts", edits: [{ oldText: "export const value = 1;", newText: "// rejected\nexport const value = 2;" }] }), { stopReason: "toolUse" }),
      fauxAssistantMessage("done"),
    ]);
    await f.core.runs.tick();
    await f.core.harness.waitForIdle(context);
    const conversation = await f.core.harness.conversation(run.conversationId, context);
    const transcript = JSON.stringify((await conversation!.entries({ order: "ascending" }, 100, undefined, context)).items);
    expect(transcript).toContain("no-comments:");
    expect(transcript).toContain("Commit message refused");
    expect(transcript).toContain("PR merge is forbidden");
    const child = await f.core.harness.commit(async (tx) => {
      const record = await tx.createConversation({ ownership: { kind: "ownerless" } });
      await configure(tx, record.id, { cwd: run.worktree, model: { provider: "fixture", modelId: "fixture" } });
      return record;
    }, context);
    const state = await f.core.harness.snapshot(AgentDoc, child.id, context);
    expect(JSON.stringify(state?.extensions)).toContain("etabli-guards");
    f.faux.setResponses([fauxAssistantMessage(fauxToolCall("bash", { command: "gh pr merge 1" }), { stopReason: "toolUse" }), fauxAssistantMessage("done")]);
    const raw = await f.core.harness.conversation(child.id, context);
    await raw!.submit({ type: "input", content: "child", requestId: "raw-child" }, context);
    await raw!.waitForIdle(context);
    expect(JSON.stringify((await raw!.entries({}, 100, undefined, context)).items)).toContain("PR merge is forbidden");
    expect(() => guardedAgent({ extensions: [] }, createGuards(rootPath(), f.policy))).toThrow("owned by the daemon");
  } finally { await f.cleanup(); }
});

function rootPath(): string { return join(import.meta.dirname, "../.."); }


test("admission verifies canonical owner and rejects changed cache push targets before creating a run", async () => {
  const f = await fixture();
  try {
    Object.assign(f.core.runs.repositories, { identity: async () => "ForestAdmin/moved" });
    await expect(f.core.runs.submit("Tonours/fixture", "moved", "moved")).rejects.toThrow("owner refused");
    expect(await f.core.runs.list()).toEqual([]);
    Object.assign(f.core.runs.repositories, { identity: async (repo: string) => repo });
    f.faux.setResponses([fauxAssistantMessage("done")]);
    const run = await f.core.runs.submit("Tonours/fixture", "first", "first");
    await f.core.runs.tick();
    await f.core.harness.waitForIdle(context);
    execFileSync("git", ["-C", run.worktree, "config", "remote.origin.pushurl", "https://github.com/ForestAdmin/fixture.git"]);
    await expect(f.core.runs.submit("Tonours/fixture", "second", "second")).rejects.toThrow("remote changed");
    expect((await f.core.runs.list()).length).toBe(1);
  } finally { await f.cleanup(); }
});
