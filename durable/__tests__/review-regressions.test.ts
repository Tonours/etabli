import { expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import { mkdtemp, rm } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { fauxAssistantMessage } from "@earendil-works/pi-ai/providers/faux";
import { OwnerPolicy } from "../src/policy.ts";
import { invocationGuard } from "../src/guards.ts";
import { dispatch, daemonConfig } from "../src/daemon.ts";
import { fixture, localRepo } from "./helpers.ts";
import { SharedCredentialStore } from "../src/credentials.ts";

test("daemon configuration bounds the restart budget used by production startup", () => {
  expect(daemonConfig({}).restartLimit).toBe(5);
  expect(daemonConfig({ restartLimit: 12 }).restartLimit).toBe(12);
  expect(daemonConfig({ restartLimit: 32 }).restartLimit).toBe(32);
  for (const restartLimit of [0, 33, 1.5, "12", false]) expect(() => daemonConfig({ restartLimit })).toThrow("restartLimit");
});

test("credential callback failures keep a safe distinct diagnostic", async () => {
  const root = await mkdtemp(join(tmpdir(), "durable-callback-"));
  try {
    const store = new SharedCredentialStore(join(root, "auth.json"));
    await store.modify("fixture", async () => ({ type: "api_key", key: "synthetic-preserved" }));
    await expect(store.modify("fixture", () => { throw new Error("synthetic-private-detail"); })).rejects.toThrow("Credential update callback failed");
    await expect(store.modify("fixture", async () => { throw new Error("synthetic-private-detail"); })).rejects.toThrow("Credential update callback failed");
    expect(await store.read("fixture")).toEqual({ type: "api_key", key: "synthetic-preserved" });
  } finally { await rm(root, { recursive: true, force: true }); }
});

async function guardFixture(check: (command: string) => void): Promise<void> {
  const root = await mkdtemp(join(tmpdir(), "durable-review-"));
  try {
    const repo = await localRepo(root);
    execFileSync("git", ["-C", repo, "remote", "add", "origin", "https://github.com/Tonours/fixture.git"]);
    check(repo);
  } finally { await rm(root, { recursive: true, force: true }); }
}

test("a Bash comment cannot hide later direct publication commands", async () => {
  await guardFixture((repo) => {
    const check = (command: string) => invocationGuard(command, repo, new OwnerPolicy(["ForestAdmin"]), () => "main");
    expect(check("echo prep\ngit push origin HEAD:feature")).toBeUndefined();
    for (const command of ["git push origin main", "gh pr merge 1", "gh pr view --repo ForestAdmin/fixture"]) {
      expect(check(`echo prep # note\n${command}`), command).toContain("guard");
    }
  });
});

test("glob arguments cannot hide a later foreign repository flag", async () => {
  await guardFixture((repo) => {
    const check = (command: string) => invocationGuard(command, repo, new OwnerPolicy(["ForestAdmin"]), () => "main");
    expect(check("gh issue create --title 'x*' --repo Tonours/fixture --body b")).toBeUndefined();
    for (const title of ["x*", "x?"]) expect(check(`gh issue create --title ${title} --repo ForestAdmin/fixture --body b`)).toContain("guard");
  });
});

test("source-only HEAD aliases cannot publish the default branch", async () => {
  await guardFixture((repo) => {
    const check = (command: string) => invocationGuard(command, repo, new OwnerPolicy(["ForestAdmin"]), () => "main");
    expect(check("git push origin HEAD:feature")).toBeUndefined();
    expect(check("git push origin @")).toContain("guard");
    expect(check("git push origin +@")).toContain("guard");
    expect(check("git push origin HEAD:heads/main")).toContain("guard");
    expect(check("git push origin HEAD:refs/heads/main")).toContain("guard");
    expect(check("git push origin HEAD:@")).toContain("guard");
    expect(check("git push origin '@{u}'")).toContain("guard");
  });
});

test("shell expansion and reserved prefixes cannot hide direct git or gh calls", async () => {
  await guardFixture((repo) => {
    const check = (command: string) => invocationGuard(command, repo, new OwnerPolicy(["ForestAdmin"]), () => "main");
    expect(check("cd . && git push origin HEAD:feature")).toBeUndefined();
    expect(check("echo 'safe' && gh pr view --repo Tonours/fixture")).toBeUndefined();
    for (const command of [
      "git push origin {main,x}", "gh issue create --{repo=ForestAdmin/x,title=y}", "git push origin HEAD:ma[i]n",
      'echo "$(gh pr merge 1)"', 'echo `gh pr merge 1`',
      "{ git push origin main; }", "if true; then git push origin main; fi", "for n in 1; do gh pr merge 1; done", "! gh pr merge 1", "time git push origin main", "exec gh pr merge 1",
    ]) expect(check(command), command).toContain("guard");
  });
});

test("a changed busy worktree blocks only its run during restart", async () => {
  const f = await fixture();
  let release: () => void = () => undefined;
  const gate = new Promise<void>((resolve) => { release = resolve; });
  f.faux.setResponses(Array.from({ length: 10 }, () => async (_input: unknown, options: { signal?: AbortSignal } | undefined) => {
    await Promise.race([gate, new Promise<void>((resolve) => options?.signal?.addEventListener("abort", () => resolve(), { once: true }))]);
    return fauxAssistantMessage("done");
  }));
  try {
    const bad = await f.core.runs.submit("Tonours/fixture", "changed branch", "bad-branch");
    const good = await f.core.runs.submit("Tonours/fixture", "unchanged branch", "good-branch");
    await f.core.runs.tick();
    execFileSync("git", ["-C", bad.worktree, "switch", "-c", "other"], { stdio: "ignore" });
    await f.reopen();
    expect(await f.core.runs.show(bad.id)).toMatchObject({ status: "blocked", reason: "run_setup_failed" });
    expect((await f.core.runs.show(good.id)).status).toBe("implementing");
    release();
    await f.core.harness.waitForIdle(context);
  } finally { release(); await f.cleanup(); }
});

test("aborting a terminal run reports no transition", async () => {
  const f = await fixture();
  try {
    f.faux.setResponses([fauxAssistantMessage("done")]);
    const run = await f.core.runs.submit("Tonours/fixture", "terminal", "terminal");
    await f.core.runs.tick();
    await f.core.harness.waitForIdle(context);
    await f.core.runs.tick();
    expect(await dispatch(f.core, { op: "abort", id: run.id })).toEqual({ aborted: false });
    expect((await f.core.runs.show(run.id)).status).toBe("done");
    const queued = await f.core.runs.submit("Tonours/fixture", "abort queued", "abort-queued");
    expect(await dispatch(f.core, { op: "abort", id: queued.id })).toEqual({ aborted: true });
    expect((await f.core.runs.show(queued.id)).status).toBe("aborted");
  } finally { await f.cleanup(); }
});

test.each([
  ["alias override", "git -c alias.p=push p origin main"], ["alias configuration", "git config alias.p push"],
  ["unknown alias", "git p origin main"], ["shell alias", "git -c alias.m='!gh pr merge 1' m"],
  ["API method", "gh api -X PUT repos/Tonours/fixture/pulls/1/merge"], ["API joined method", "gh api -XPUT repos/Tonours/fixture/pulls/1/merge"],
  ["API field", "gh api -f x=1 repos/Tonours/fixture/git/refs/heads/main"], ["API input", "gh api --input body.json repos/Tonours/fixture/pulls/1/merge"],
  ["API combined method", "gh api -iXPUT repos/Tonours/fixture/pulls/1/merge"], ["API combined field", "gh api -ifx=1 repos/Tonours/fixture/pulls/1/merge"],
  ["API long method", "gh api --method=PUT repos/Tonours/fixture/pulls/1/merge"],
  ["API endpoint hidden by filter", "gh api --jq repos/Tonours/fixture repos/ForestAdmin/fixture"],
  ["fork target precedence", "gh repo fork ForestAdmin/x --repo Tonours/y"], ["view target precedence", "gh repo view ForestAdmin/x -RTonours/y"],
  ["clone target precedence", "gh repo clone ForestAdmin/x --repo Tonours/y"], ["remote config add", "git config --add remote.origin.url https://github.com/ForestAdmin/evil"],
  ["create target after options", "gh repo create --private ForestAdmin/new"], ["fork target after options", "gh repo fork --org Tonours ForestAdmin/x"],
  ["view target after options", "gh repo view --json name ForestAdmin/x"],
  ["foreign fork", "gh repo fork Tonours/fixture --org ForestAdmin"],
  ["issue transfer", "gh issue transfer 1 ForestAdmin/fixture"], ["repo push", "gh repo create Tonours/new --push"],
  ["repo delete", "gh repo delete Tonours/fixture --yes"], ["repo archive", "gh repo archive Tonours/fixture"],
  ["repo rename", "gh repo rename renamed --repo Tonours/fixture"], ["release delete", "gh release delete v1"],
  ["workflow run", "gh workflow run deploy"], ["variable command", "cmd='git push origin main'; $cmd"],
  ["config rewrite", "git config url.https://github.com/ForestAdmin/evil.insteadOf https://github.com/Tonours/fixture"],
  ["push rewrite config", "git config url.https://github.com/ForestAdmin/evil.pushInsteadOf https://github.com/Tonours/fixture"],
])("Threat refuses %s through the real invocation guard", async (_label, command) => {
  await guardFixture((repo) => {
    const check = (value: string) => invocationGuard(value, repo, new OwnerPolicy(["ForestAdmin"]), () => "main");
    for (const control of ["git push origin HEAD:feature", "git config --get user.name", "gh api -X GET repos/Tonours/fixture/pulls", "gh api -XGET repos/Tonours/fixture/pulls", "gh api repos/Tonours/fixture/pulls", "gh repo view Tonours/fixture", "gh repo create Tonours/new", "gh repo fork Tonours/fixture --org Tonours", "gh issue transfer 1 Tonours/other", "gh repo view Tonours/x --repo Tonours/y", "gh repo view Tonours/fixture --json name", "gh repo create Tonours/new --private"]) expect(check(control)).toBeUndefined();
    expect(check(command)).toContain("guard");
  });
});

test("literal push URLs are checked after native Git URL rewriting", async () => {
  await guardFixture((repo) => {
    const check = () => invocationGuard("git push https://github.com/Tonours/fixture HEAD:feature", repo, new OwnerPolicy(["ForestAdmin"]), () => "main");
    expect(check()).toBeUndefined();
    expect(invocationGuard("git push origin HEAD:feature", repo, new OwnerPolicy(["ForestAdmin"]), () => "main")).toBeUndefined();
    execFileSync("git", ["-C", repo, "config", "url.https://github.com/ForestAdmin/evil.insteadOf", "https://github.com/Tonours/fixture"]);
    expect(check()).toContain("guard");
    expect(invocationGuard("git push origin HEAD:feature", repo, new OwnerPolicy(["ForestAdmin"]), () => "main")).toContain("guard");
  });
});

test.each(["git reset --hard HEAD~1", "git reflog", "git ls-files", "git cat-file -p HEAD^{tree}", "git rev-list HEAD", "git for-each-ref", "git symbolic-ref HEAD"])("supports local coding command %s", async (command) => {
  await guardFixture((repo) => {
    const check = (value: string) => invocationGuard(value, repo, new OwnerPolicy(["ForestAdmin"]), () => "main");
    expect(check("git p origin main")).toContain("guard");
    expect(check(command)).toBeUndefined();
  });
});


test.each(["--template ", "--template=", "-p ", "-p", "-p=", "-cp", "-cp=", "-ccp", "-cp ", "-ccp "])("template source %s is owner checked", async (option) => {
  await guardFixture((repo) => {
    const check = (value: string) => invocationGuard(value, repo, new OwnerPolicy(["ForestAdmin"]), () => "main");
    for (const source of ["Tonours/tpl", "https://github.com/Tonours/tpl"]) expect(check(`gh repo create Tonours/new ${option}${source}`)).toBeUndefined();
    expect(check("gh repo create Tonours/new --private")).toBeUndefined();
    for (const source of ["ForestAdmin/x", "https://github.com/ForestAdmin/x"]) expect(check(`gh repo create Tonours/new ${option}${source}`)).toContain("guard");
  });
});

test.each(["gh repo view -R Tonours/x --json name", "gh repo fork --clone", "gh repo view --web"])("refuses unsupported flag-only repo form %s", async (command) => {
  await guardFixture((repo) => {
    const check = (value: string) => invocationGuard(value, repo, new OwnerPolicy(["ForestAdmin"]), () => "main");
    expect(check("gh repo view Tonours/fixture --json name")).toBeUndefined();
    expect(check("gh repo view --json name ForestAdmin/x")).toContain("guard");
    expect(check(command)).toContain("Name an explicit repository before its options");
  });
});

test.each(["--template", "--template=", "-p", "-p=", "-cp", "-cp="])("refuses missing template source %s", async (option) => {
  await guardFixture((repo) => {
    const check = (value: string) => invocationGuard(value, repo, new OwnerPolicy(["ForestAdmin"]), () => "main");
    expect(check("gh repo create Tonours/new --template Tonours/tpl")).toBeUndefined();
    expect(check("gh repo view -R Tonours/fixture --json ForestAdmin/x")).toContain("guard");
    expect(check(`gh repo create Tonours/new ${option}`)).toContain("guard");
  });
});
