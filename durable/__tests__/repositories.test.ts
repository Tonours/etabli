import { expect, test } from "bun:test";
import { mkdir, writeFile, readFile, stat } from "node:fs/promises";
import { join } from "node:path";
import { execFileSync } from "node:child_process";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { fauxAssistantMessage } from "@earendil-works/pi-ai/providers/faux";
import { fixture } from "./helpers.ts";

test("restart reconciles a partial private clone before atomic native submission", async () => {
  const f = await fixture();
  try {
    const partial = join(f.state, "repos/Tonours--fixture.git.creating");
    await mkdir(partial, { recursive: true });
    await writeFile(join(partial, "unfinished"), "partial clone");
    f.faux.setResponses([fauxAssistantMessage("done")]);
    const run = await f.core.runs.submit("Tonours/fixture", "partial clone", "partial");
    await f.reopen();
    await f.core.harness.waitForIdle(context);
    await f.core.runs.tick();
    expect((await f.core.runs.show(run.id)).status).toBe("done");
    expect(await stat(partial).then(() => true, () => false)).toBe(false);
    expect((await f.core.runs.list()).length).toBe(1);
  } finally { await f.cleanup(); }
});

test("restart reuses the persisted run branch after worktree creation was interrupted", async () => {
  const f = await fixture();
  try {
    const run = await f.core.runs.submit("Tonours/fixture", "existing branch", "branch");
    await f.core.runs.repositories.prepare(run.id, run.repo, run.branch);
    await writeFile(join(run.worktree, "preserved.txt"), "preserve this branch\n");
    const git = (args: string[]) => execFileSync("git", ["-C", run.worktree, ...args], { stdio: "ignore" });
    git(["add", "preserved.txt"]);
    git(["-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-m", "preserve existing branch"]);
    const cache = join(f.state, "repos/Tonours--fixture.git");
    execFileSync("git", ["-C", cache, "worktree", "remove", run.worktree], { stdio: "ignore" });
    f.faux.setResponses([fauxAssistantMessage("done")]);
    await f.reopen();
    await f.core.harness.waitForIdle(context);
    await f.core.runs.tick();
    expect((await f.core.runs.show(run.id)).status).toBe("done");
    expect(await readFile(join(run.worktree, "preserved.txt"), "utf8")).toBe("preserve this branch\n");
  } finally { await f.cleanup(); }
});
