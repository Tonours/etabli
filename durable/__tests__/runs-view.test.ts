import { expect, test } from "bun:test";
import { age, ATTENTION_MS, describe, order, pullRequest, summary, title, type Group, type ListedRun, type Tone } from "../shared/runs-view.ts";

const now = 1_800_000_000_000, hour = 3_600_000;
const run = (status: string, reason = "", extra: Partial<ListedRun> = {}): ListedRun => ({ id: `${status}-${reason}`, status, reason, url: "", prompt: "task", createdAt: now - hour, startedAt: now - hour, ...extra });
const retry = "then start a new run from the CLI.";

test("describe matches the expected table for every status and reason", () => {
  const table: [string, string, Group, Tone, string, string][] = [
    ["queued", "", "active", "muted", "Queued", ""],
    ["planning", "", "active", "info", "Planning", ""],
    ["implementing", "", "active", "info", "Implementing", ""],
    ["reviewing", "", "active", "info", "Reviewing", ""],
    ["publishing", "", "active", "info", "Publishing", ""],
    ["done", "published", "finished", "ok", "PR opened", ""],
    ["done", "answer", "finished", "ok", "Done", ""],
    ["aborted", "", "finished", "muted", "Aborted", ""],
    ["blocked", "workflow_finished_without_publication", "attention", "alert", "No pull request", `The run ended without opening a pull request. Check its activity, ${retry}`],
    ["blocked", "run_setup_failed", "attention", "alert", "Setup failed", `The run could not start. Check the repository setup, ${retry}`],
    ["blocked", "wall_clock_limit", "attention", "alert", "Out of time", `The run reached its time limit. Review its progress, ${retry}`],
    ["blocked", "turn_limit", "attention", "alert", "Out of turns", `The run used all its turns. Review its progress, ${retry}`],
    ["blocked", "review_block_limit", "attention", "alert", "Review blocked", `Inspect the review findings, ${retry}`],
    ["blocked", "review_unavailable_or_invalid", "attention", "alert", "Review failed", `No valid review was returned. Check the reviewer setup, ${retry}`],
    ["blocked", "ci_attempts_exhausted", "attention", "alert", "CI failing", "CI still fails after the repair attempts. Fix the checks on the pull request."],
    ["blocked", "model_error", "attention", "alert", "Model error", `The model returned an error. Check the provider, ${retry}`],
    ["blocked", "no_model", "attention", "alert", "No model", `No model was available. Check the model configuration, ${retry}`],
    ...["interrupted", "restart_limit", "faulted", "orphaned"].map((reason): [string, string, Group, Tone, string, string] => ["blocked", reason, "attention", "alert", "Interrupted", `The run stopped unexpectedly. Check its activity, ${retry}`]),
    ["blocked", "unanswered", "attention", "alert", "Blocked", `The run stopped (unanswered). Check its activity, ${retry}`],
    ["blocked", "", "attention", "alert", "Blocked", `The run stopped (no reason recorded). Check its activity, ${retry}`],
    ["blocked", "constructor", "attention", "alert", "Blocked", `The run stopped (constructor). Check its activity, ${retry}`],
    ["paused", "", "active", "muted", "paused", ""],
    ["constructor", "", "active", "muted", "constructor", ""],
  ];
  for (const [status, reason, group, tone, label, hint] of table) expect([status, reason, describe(run(status, reason), now)]).toEqual([status, reason, { group, tone, label, hint }]);
});

test("the attention window is 72 h exactly and falls back to createdAt", () => {
  expect(describe(run("blocked", "x", { startedAt: now - ATTENTION_MS }), now).group).toBe("attention");
  expect(describe(run("blocked", "x", { startedAt: now - ATTENTION_MS - 1 }), now).group).toBe("finished");
  expect(describe(run("blocked", "x", { startedAt: 0, createdAt: now - ATTENTION_MS }), now).group).toBe("attention");
  expect(describe(run("blocked", "x", { startedAt: 0, createdAt: now - ATTENTION_MS - 1 }), now).group).toBe("finished");
});

test("order pins one display order and the counts", () => {
  const at = (id: string, status: string, hoursAgo: number, reason = "") => ({ ...run(status, reason), id, createdAt: now - hoursAgo * hour, startedAt: status === "queued" ? 0 : now - hoursAgo * hour });
  const creation = [
    at("old-blocked", "blocked", 100), at("done-1", "done", 50, "published"), at("queued-old", "queued", 9), at("blocked-early", "blocked", 8),
    at("active-early", "implementing", 7), at("queued-new", "queued", 6), at("blocked-late", "blocked", 2), at("active-late", "planning", 1), at("aborted", "aborted", 0.5),
  ];
  const result = order(creation, now);
  expect(result.runs.map((row) => row.id)).toEqual(["blocked-late", "blocked-early", "active-late", "active-early", "queued-old", "queued-new", "aborted", "done-1", "old-blocked"]);
  expect(result.counts).toEqual({ attention: 2, active: 4, finished: 3, working: 2, queued: 2 });
  expect(summary(result.counts)).toBe("2 need you · 2 working · 2 queued");
});

test("title, pull request link and age", () => {
  expect(title("\n  First line  \nsecond")).toBe("First line");
  expect(title("x".repeat(81))).toBe(`${"x".repeat(80)}…`);
  expect(title("x".repeat(80))).toBe("x".repeat(80));
  expect(pullRequest("https://github.com/o/r/pull/1")).toBe("https://github.com/o/r/pull/1");
  for (const bad of ["javascript:alert(1)", "http://x", "https://a b", "", " https://x"]) expect(pullRequest(bad)).toBe("");
  expect([59, 60 * 12, 3600 * 5, 3600 * 47, 3600 * 48, 86_400 * 3].map((seconds) => age(now - seconds * 1000, now))).toEqual(["59s", "12m", "5h", "47h", "2d", "3d"]);
  expect(age(now + 5000, now)).toBe("0s");
});
