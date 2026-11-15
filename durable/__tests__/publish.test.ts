import { expect, test } from "bun:test";
import { writeFile } from "node:fs/promises";
import { execFileSync } from "node:child_process";
import { join } from "node:path";
import { fixture } from "./helpers.ts";
import { change, git } from "../src/change.ts";
import { publishBranch, approvedChange, type Command } from "../src/publish.ts";
import type { ReviewReceipt } from "../src/plan-doc.ts";

const body = "## What\nAdds a fixture result.\n\n## Why\nExercises publication recovery.\n\n## How to test\nRun the fixture check.\n";

test("publication reconciles every side-effect boundary without creating a duplicate PR", async () => {
  const f = await fixture({ workflow: true });
  try {
    const run = await f.core.runs.submit("Tonours/fixture", "publication fixture", "publish");
    await f.core.runs.repositories.prepare(run.id, run.repo, run.branch);
    await writeFile(join(run.worktree, "result.txt"), "finished\n");
    execFileSync("git", ["-C", run.worktree, "add", "result.txt"]);
    execFileSync("git", ["-C", run.worktree, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-m", "finish fixture"], { stdio: "ignore" });
    const intent = { title: "finish fixture", body, head: await git(run.worktree, ["rev-parse", "HEAD"]), base: "main", sourceHash: (await change(run.worktree)).hash };
    for (const cut of ["before_push", "after_push", "before_create", "after_create", "after_url"]) {
      let cutOnce = true;
      let pushes = 0;
      let creates = 0;
      let url = "";
      const execute: Command = async (cwd, program, args) => {
        if (program === "git") {
          if (args[0] === "remote") return "https://github.com/Tonours/fixture.git";
          if (args[0] === "ls-remote") return "ref: refs/heads/main\tHEAD\n1111111111111111111111111111111111111111\tHEAD";
          if (args[0] === "push") {
            expect(args).toEqual(["push", "origin", `${intent.head}:refs/heads/${run.branch}`]);
            if (cutOnce && cut === "before_push") { cutOnce = false; throw new Error("cut"); }
            pushes++;
            if (cutOnce && cut === "after_push") { cutOnce = false; throw new Error("cut"); }
            return "";
          }
          return git(cwd, args);
        }
        if (program === "gitleaks") return "";
        if (program === "gh" && args[1] === "list") return JSON.stringify(url ? [{ url, headRefOid: intent.head, baseRefName: "main", state: "OPEN", headRepositoryOwner: { login: "Tonours" } }] : []);
        if (program === "gh" && args[1] === "create") {
          if (cutOnce && cut === "before_create") { cutOnce = false; throw new Error("cut"); }
          expect(url).toBe("");
          creates++;
          url = "https://github.com/Tonours/fixture/pull/1";
          if (cutOnce && cut === "after_create") { cutOnce = false; throw new Error("cut"); }
          return url;
        }
        throw new Error(`Unexpected command ${program} ${args.join(" ")}`);
      };
      let result = "";
      try { result = await publishBranch(run, intent, f.policy, execute); if (cut === "after_url") throw new Error("cut before store"); } catch { }
      result = await publishBranch(run, intent, f.policy, execute);
      expect(result).toBe("https://github.com/Tonours/fixture/pull/1");
      expect(creates).toBe(1);
      expect(pushes).toBeGreaterThanOrEqual(1);
      expect(await publishBranch(run, intent, f.policy, execute)).toBe(result);
      expect(creates).toBe(1);
    }
    await expect(publishBranch({ ...run, route: "legacy" }, intent, f.policy)).rejects.toThrow("workflow");
    let effects = 0;
    await expect(publishBranch(run, { ...intent, body: "bad body" }, f.policy, async (cwd, program, args) => {
      if (program === "git" && args[0] === "remote") return "https://github.com/Tonours/fixture.git";
      if (program === "git" && args[0] === "ls-remote") return "ref: refs/heads/main\tHEAD";
      if (program === "gh" || program === "gitleaks" || args[0] === "push") { effects++; return "[]"; }
      return git(cwd, args);
    })).rejects.toThrow("PR body");
    expect(effects).toBe(0);
    await expect(publishBranch(run, { ...intent, body: "bad body" }, f.policy, async (cwd, program, args) => {
      if (program === "git" && args[0] === "remote") return "https://github.com/ForestAdmin/fixture.git";
      return git(cwd, args);
    })).rejects.toThrow("owner refused");
  } finally { await f.cleanup(); }
});

test("publication requires all four current independent verdicts from one round", () => {
  const receipt = (axis: string, round = "round"): ReviewReceipt => ({ kind: "code", axis, round, sourceHash: "source", planHash: "plan", authors: ["zai"], reviewer: { alias: "sol", family: "openai", provider: "openai-codex", modelId: "gpt-6.1-sol", transport: "native" }, verdict: "GO", body: "GO", conversationId: 1 as ReviewReceipt["conversationId"] });
  const reviews = ["logic", "spec", "threat", "adversary"].map((axis) => receipt(axis));
  expect(approvedChange(reviews, "source", "plan", ["zai"])).toBe(true);
  expect(approvedChange(reviews.slice(1), "source", "plan", ["zai"])).toBe(false);
  expect(approvedChange(reviews, "changed", "plan", ["zai"])).toBe(false);
  expect(approvedChange(reviews, "source", "changed", ["zai"])).toBe(false);
  expect(approvedChange(reviews, "source", "plan", ["openai", "zai"])).toBe(false);
  expect(approvedChange([...reviews, receipt("logic", "later")], "source", "plan", ["zai"])).toBe(false);
  expect(approvedChange([...reviews.slice(0, 3), { ...receipt("adversary"), verdict: "BLOCK" }], "source", "plan", ["zai"])).toBe(false);
  expect(approvedChange([{ ...receipt("logic"), verdict: "BLOCK" }, ...reviews.slice(1)], "source", "plan", ["zai"])).toBe(true);
  expect(approvedChange([...reviews.slice(0, 3), { ...receipt("adversary"), verdict: "GO WITH NOTES" }], "source", "plan", ["zai"])).toBe(true);
  expect(approvedChange([...reviews, receipt("logic")], "source", "plan", ["zai"])).toBe(false);
  expect(approvedChange([{ ...receipt("logic"), verdict: "incomplete" }, ...reviews.slice(1)], "source", "plan", ["zai"])).toBe(false);
});
