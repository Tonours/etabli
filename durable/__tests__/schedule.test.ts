import { expect, test } from "bun:test";
import { randomBytes } from "node:crypto";
import { request as httpRequest } from "node:http";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { fauxAssistantMessage } from "@earendil-works/pi-ai/providers/faux";
import { fixture } from "./helpers.ts";
import { serve, serveRemote } from "../src/api.ts";
import { request } from "../src/cli.ts";
import { nextDue, SchedulesDoc, type Schedule } from "../src/schedule.ts";

const epoch = Date.UTC(2026, 0, 1);
test("UTC numeric cron validates bounded fields, calendar impossibilities, leap days, OR and steps", () => {
  expect(nextDue("* * * * *", epoch)).toBe(epoch + 60_000);
  expect(nextDue("0 0 */2 * *", epoch + 3_600_000)).toBe(Date.UTC(2026, 0, 3));
  expect(nextDue("0 0 * * */2", epoch + 3_600_000)).toBe(Date.UTC(2026, 0, 3));
  expect(nextDue("0 0 */2 * 1", Date.UTC(2026, 0, 5, 1))).toBe(Date.UTC(2026, 0, 19));
  expect(nextDue("0 0 1 * */2", Date.UTC(2026, 2, 1, 1))).toBe(Date.UTC(2026, 7, 1));
  expect(nextDue("0 0 1 * 1", epoch + 3_600_000)).toBe(Date.UTC(2026, 0, 5));
  expect(nextDue("*/15 9-10 * * 1-5", epoch)).toBe(Date.UTC(2026, 0, 1, 9));
  expect(nextDue("0 0 29 2 *", epoch)).toBe(Date.UTC(2028, 1, 29));
  expect(nextDue("0 0 1 * 0,7", epoch)).toBe(Date.UTC(2026, 0, 4));
  for (const cron of ["", "* * *", "0 0 31 2 *", "60 * * * *", "* 24 * * *", "* * 0 * *", "* * * 13 *", "* * * * 8", "*/0 * * * *", "*/61 * * * *", "0 0 * JAN *", "@daily", "1--2 * * * *", "0 0 2-1 * *"]) expect(() => nextDue(cron, epoch)).toThrow();
});

test("schedule API identity, conflict, UTC validation, auth and idempotent deletion", async () => {
  const f = await fixture({ now: () => epoch });
  const local = await serve(f.core, f.state);
  const token = randomBytes(32).toString("base64url");
  const remote = await serveRemote(f.core, 0, token, ["fixture@example.invalid"]);
  const port = (remote.address() as { port: number }).port;
  const raw = (path: string, method: string, body?: unknown, authenticated = false) => new Promise<number>((resolve, reject) => {
    const outgoing = httpRequest({ host: "127.0.0.1", port, path, method, headers: authenticated ? { authorization: `Bearer ${token}`, "Tailscale-User-Login": "fixture@example.invalid", "Content-Type": "application/json" } : {} }, (response) => { response.resume(); response.once("end", () => resolve(response.statusCode!)); });
    outgoing.once("error", reject); outgoing.end(body ? JSON.stringify(body) : undefined);
  });
  try {
    const input = { op: "schedule-create", repo: "Tonours/fixture", prompt: "scheduled", cron: "* * * * *", requestId: "once" };
    const first = await request(f.state, input) as Schedule;
    expect(first).toMatchObject({ repo: input.repo, prompt: input.prompt, cron: input.cron, requestId: input.requestId, createdAt: epoch, nextDue: epoch + 60_000 });
    expect(await request(f.state, input)).toEqual(first);
    await expect(request(f.state, { ...input, prompt: "changed" })).rejects.toThrow("different schedule");
    await expect(request(f.state, { ...input, requestId: "invalid", cron: "0 0 31 2 *" })).rejects.toThrow("eight years");
    await expect(request(f.state, { ...input, requestId: "foreign", repo: "ForeignOrg/private" })).rejects.toThrow();
    for (const requestId of ["schedule:spoof", "ci:spoof"]) await expect(request(f.state, { op: "run", repo: "Tonours/fixture", prompt: "bad", requestId })).rejects.toThrow("prefix reserved");
    expect(await request(f.state, { op: "schedule-list" })).toEqual([first]);
    expect(await raw("/v1/schedules", "GET")).toBe(401);
    expect(await raw(`/v1/schedules/${first.id}`, "DELETE")).toBe(401);
    expect(await raw("/v1/schedules", "PATCH", undefined, true)).toBe(405);
    expect(await raw("/v1/schedules/bad", "DELETE", undefined, true)).toBe(404);
    expect(await raw("/v1/schedules?cron=*", "GET", undefined, true)).toBe(400);
    expect(await raw("/v1/schedules", "POST", { ...input, cron: 5 }, true)).toBe(400);
    expect(await raw("/v1/schedules", "POST", { ...input, requestId: "remote-control" }, true)).toBe(200);
    const other = (await f.core.schedules.list()).find((row) => row.requestId === "remote-control")!;
    expect(await raw(`/v1/schedules/${other.id}`, "DELETE", undefined, true)).toBe(200);
    expect(await request(f.state, { op: "schedule-delete", id: first.id })).toEqual({ deleted: true });
    expect(await request(f.state, { op: "schedule-delete", id: first.id })).toEqual({ deleted: false });
    expect(await request(f.state, { op: "schedule-list" })).toEqual([]);
    await expect(request(f.state, input)).rejects.toThrow("Schedule deleted");
  } finally { await local.shutdown(); await remote.shutdown(); await f.cleanup(); }
});

test("overdue occurrence survives retry/restart, coalesces outage, holds overlapping run and stops on delete", async () => {
  let now = epoch;
  const f = await fixture({ now: () => now });
  try {
    const schedule = await f.core.schedules.create("Tonours/fixture", "scheduled", "* * * * *", "clock");
    await f.core.schedules.tick(); expect(await f.core.runs.list()).toHaveLength(0);
    now += 7 * 86_400_000;
    Object.assign(f.core.runs.repositories, { admit: async () => { throw new Error("offline"); } });
    await f.core.schedules.tick();
    const pending = (await f.core.harness.snapshot(SchedulesDoc, context))!.schedules[0].occurrence!;
    expect(pending).toMatchObject({ status: "pending", due: schedule.nextDue, error: "submission_unavailable" });
    await f.reopen();
    now += 60_000;
    await f.core.schedules.tick();
    const runs = await f.core.runs.list(); expect(runs).toHaveLength(1);
    expect(runs[0].requestId).toBe(pending.requestId);
    expect((await f.core.schedules.list())[0].nextDue).toBe(nextDue(schedule.cron, now));
    now += 60_000;
    await f.core.schedules.tick(); expect(await f.core.runs.list()).toHaveLength(1);
    f.faux.setResponses([fauxAssistantMessage("done")]);
    await f.core.runs.tick(); await f.core.harness.waitForIdle(context); await f.core.runs.tick();
    await f.core.schedules.tick(); expect(await f.core.runs.list()).toHaveLength(2);
    await f.core.schedules.delete(schedule.id); now += 60_000;
    await f.core.schedules.tick(); await f.reopen(); await f.core.schedules.tick();
    expect(await f.core.runs.list()).toHaveLength(2);
  } finally { await f.cleanup(); }
});

test("DELETE and GET stay responsive during slow admission and deletion cancels reserved submission", async () => {
  let now = epoch;
  const f = await fixture({ now: () => now });
  let release = () => {};
  const gate = new Promise<void>((resolve) => { release = resolve; });
  let ticking: Promise<void> | undefined;
  try {
    const schedule = await f.core.schedules.create("Tonours/fixture", "slow", "* * * * *", "slow");
    const admit = f.core.runs.repositories.admit.bind(f.core.runs.repositories);
    let entered = false;
    Object.assign(f.core.runs.repositories, { admit: async (repo: string) => { entered = true; await gate; return admit(repo); } });
    now += 60_000; ticking = f.core.schedules.tick();
    while (!entered) await new Promise((resolve) => setTimeout(resolve, 5));
    const timeout = new Promise<never>((_, reject) => { const timer = setTimeout(() => reject(new Error("schedule API blocked")), 500); timer.unref(); });
    expect(await Promise.race([f.core.schedules.list(), timeout])).toHaveLength(1);
    expect(await Promise.race([f.core.schedules.delete(schedule.id), timeout])).toBe(true);
    release(); await ticking;
    expect(await f.core.runs.list()).toHaveLength(0);
  } finally { release(); await ticking; await f.cleanup(); }
});

test("revoked ownership and existing trigger identities get durable failure dispositions", async () => {
  let now = epoch;
  const f = await fixture({ now: () => now });
  try {
    const first = await f.core.schedules.create("Tonours/fixture", "collision", "* * * * *", "collision");
    await f.core.runs.submit(first.repo, first.prompt, `schedule:${first.id}:${first.nextDue}`);
    now += 60_000; await f.core.schedules.tick();
    let row = (await f.core.harness.snapshot(SchedulesDoc, context))!.schedules[0];
    expect(row.occurrence).toMatchObject({ status: "failed", error: "request_identity_conflict", runId: "" });
    expect(await f.core.runs.list()).toHaveLength(1);
    await f.core.schedules.delete(first.id);
    await f.core.schedules.create("Tonours/fixture", "revoked", "* * * * *", "revoked");
    f.policy.workOrgs.add("tonours"); now += 60_000; await f.core.schedules.tick();
    row = (await f.core.harness.snapshot(SchedulesDoc, context))!.schedules[1];
    expect(row.occurrence).toMatchObject({ status: "failed", error: "policy_denied" });
    expect(row.value.nextDue).toBeGreaterThan(now);
    expect(await f.core.runs.list()).toHaveLength(1);
  } finally { await f.cleanup(); }
});


test("sparse accepted recurrence commits its due occurrence before a distant next due", async () => {
  for (const denied of [false, true]) {
    let now = epoch;
    const f = await fixture({ now: () => now });
    try {
      const schedule = await f.core.schedules.create("Tonours/fixture", "sparse", "0 0 29 2 */7", "sparse");
      now = schedule.nextDue;
      if (denied) f.policy.workOrgs.add("tonours");
      await f.core.schedules.tick();
      const row = (await f.core.harness.snapshot(SchedulesDoc, context))!.schedules[0];
      expect(row.occurrence?.status).toBe(denied ? "failed" : "acknowledged");
      expect(row.value.nextDue).toBe(Date.UTC(2060, 1, 29));
      if (!denied) expect(await f.core.schedules.create(schedule.repo, schedule.prompt, schedule.cron, schedule.requestId)).toEqual(row.value);
      expect(await f.core.runs.list()).toHaveLength(denied ? 0 : 1);
    } finally { await f.cleanup(); }
  }
});
