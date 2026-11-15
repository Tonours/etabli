import { randomUUID } from "node:crypto";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { defineDoc } from "@earendil-works/pi-durable";
import type { Runs } from "./runs.ts";
import { active } from "./runs-doc.ts";

export type Schedule = { id: string; requestId: string; repo: string; prompt: string; cron: string; nextDue: number; createdAt: number };
export type Occurrence = { due: number; requestId: string; status: "pending" | "acknowledged" | "failed"; runId: string; error: string; retryAt: number };
export const SchedulesDoc = defineDoc<{ schedules: { value: Schedule; deleted: boolean; occurrence?: Occurrence }[] }>({
  kind: "etabli.schedules", version: 1, scope: "session", initial: () => ({ schedules: [] }), checkpointWhen: () => true,
});

function field(source: string, min: number, max: number): number[] {
  const values = new Set<number>();
  for (const item of source.split(",")) {
    const match = /^(\*|\d+(?:-\d+)?)(?:\/(\d+))?$/.exec(item);
    if (!match) throw new Error("Use numeric five-field UTC cron with *, lists, ranges or steps");
    const step = Number(match[2] ?? 1);
    const [lower, upper] = match[1] === "*" ? [min, max] : match[1].split("-").map(Number);
    const end = upper ?? (match[2] ? max : lower);
    if (!Number.isSafeInteger(step) || step < 1 || step > max - min + 1 || lower < min || end > max || lower > end) throw new Error("Cron field is out of range");
    for (let value = lower; value <= end; value += step) values.add(value);
  }
  return [...values].sort((a, b) => a - b);
}

export function nextDue(cron: string, after: number): number {
  if (!cron.trim() || cron.length > 200 || !Number.isSafeInteger(after) || !Number.isFinite(new Date(after).valueOf())) throw new Error("Provide bounded cron and timestamp");
  const fields = cron.trim().split(/\s+/);
  if (fields.length !== 5) throw new Error("Cron needs five fields in UTC");
  const [minutes, hours, days, months, weekdays] = fields.map((value, index) => field(value, [0, 0, 1, 1, 0][index], [59, 23, 31, 12, 7][index]));
  const weekdaysSet = new Set(weekdays.map((day) => day % 7));
  const start = new Date(after);
  start.setUTCHours(0, 0, 0, 0);
  for (let offset = 0; offset <= 366 * 8; offset++) {
    const date = new Date(start.valueOf() + offset * 86_400_000);
    if (!months.includes(date.getUTCMonth() + 1)) continue;
    const day = days.includes(date.getUTCDate()), weekday = weekdaysSet.has(date.getUTCDay());
    if (!(fields[2].startsWith("*") || fields[4].startsWith("*") ? day && weekday : day || weekday)) continue;
    for (const hour of hours) for (const minute of minutes) {
      const due = date.valueOf() + hour * 3_600_000 + minute * 60_000;
      if (due > after) return due;
    }
  }
  throw new Error("Cron has no occurrence within eight years");
}

export class Schedules {
  readonly runs: Runs;
  constructor(runs: Runs) { this.runs = runs; }
  async list(): Promise<readonly Schedule[]> { return ((await this.runs.harness.snapshot(SchedulesDoc, context))?.schedules ?? []).filter((row) => !row.deleted).map((row) => row.value); }
  async create(repo: string, prompt: string, cron: string, requestId: string): Promise<Schedule> {
    repo = this.runs.repositories.policy.allow(repo);
    if (!prompt.trim() || prompt.length > 64_000 || !requestId || requestId.length > 200) throw new Error("Provide a bounded prompt and request id");
    const due = nextDue(cron, this.runs.now());
    await this.runs.repositories.admit(repo);
    return this.runs.harness.commit(async (tx) => {
      const rows = (await tx.doc(SchedulesDoc)).schedules;
      const old = rows.find((row) => row.value.requestId === requestId);
      if (old) {
        if (old.deleted) throw new Error("Schedule deleted; use a new request id");
        if (old.value.repo !== repo || old.value.prompt !== prompt || old.value.cron !== cron) throw new Error("Request id already belongs to a different schedule");
        return { ...old.value };
      }
      const value: Schedule = { id: randomUUID(), requestId, repo, prompt, cron, nextDue: due, createdAt: this.runs.now() };
      rows.push({ value, deleted: false });
      return value;
    }, context);
  }
  async delete(id: string): Promise<boolean> {
    return this.runs.harness.commit(async (tx) => {
      const row = (await tx.doc(SchedulesDoc)).schedules.find((row) => row.value.id === id && !row.deleted);
      if (!row) return false;
      row.deleted = true;
      return true;
    }, context);
  }
  async tick(): Promise<void> {
    for (const schedule of await this.list()) {
      try {
        const last = (await this.runs.harness.snapshot(SchedulesDoc, context))?.schedules.find((row) => row.value.id === schedule.id)?.occurrence;
        if (last?.runId) {
          const run = await this.runs.show(last.runId);
          if (run.status === "queued" || active(run)) continue;
        }
        const occurrence = await this.runs.harness.commit(async (tx) => {
          const row = (await tx.doc(SchedulesDoc)).schedules.find((row) => row.value.id === schedule.id);
          if (!row || row.deleted || row.value.nextDue > this.runs.now()) return;
          if (row.occurrence?.status !== "pending") row.occurrence = { due: row.value.nextDue, requestId: `schedule:${schedule.id}:${row.value.nextDue}`, status: "pending", runId: "", error: "", retryAt: 0 };
          return { ...row.occurrence };
        }, context);
        if (!occurrence || occurrence.retryAt > this.runs.now()) continue;
        await this.runs.submitOccurrence(schedule.id, occurrence.due);
      } catch {
        await this.runs.harness.commit(async (tx) => {
          const row = (await tx.doc(SchedulesDoc)).schedules.find((row) => row.value.id === schedule.id);
          if (row?.occurrence?.status === "pending") { row.occurrence.error = "submission_unavailable"; row.occurrence.retryAt = this.runs.now() + 60_000; }
        }, context);
        console.error("Schedule submission unavailable; retrying", schedule.id);
      }
    }
  }
}
