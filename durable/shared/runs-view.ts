/** Status vocabulary shared by the PWA and the TUI. No Node or DOM import. */
export type Group = "attention" | "active" | "finished";
export type Tone = "alert" | "info" | "ok" | "muted";
export type RunView = { group: Group; tone: Tone; label: string; hint: string };
export type ListedRun = { id: string; status: string; reason: string; url: string; prompt: string; createdAt: number; startedAt: number };
export type Counts = Record<Group, number> & { working: number; queued: number };

export const ATTENTION_MS = 72 * 3_600_000;
export const GROUPS: readonly { group: Group; heading: string }[] = [
  { group: "attention", heading: "Needs you" },
  { group: "active", heading: "In progress" },
  { group: "finished", heading: "Finished" },
];

const ACTIVE: Record<string, string> = { planning: "Planning", implementing: "Implementing", reviewing: "Reviewing", publishing: "Publishing" };
const RETRY = "then start a new run from the CLI.";
const INTERRUPTED: [string, string] = ["Interrupted", `The run stopped unexpectedly. Check its activity, ${RETRY}`];
const BLOCKED: Record<string, [string, string]> = {
  workflow_finished_without_publication: ["No pull request", `The run ended without opening a pull request. Check its activity, ${RETRY}`],
  run_setup_failed: ["Setup failed", `The run could not start. Check the repository setup, ${RETRY}`],
  wall_clock_limit: ["Out of time", `The run reached its time limit. Review its progress, ${RETRY}`],
  turn_limit: ["Out of turns", `The run used all its turns. Review its progress, ${RETRY}`],
  review_block_limit: ["Review blocked", `Inspect the review findings, ${RETRY}`],
  review_unavailable_or_invalid: ["Review failed", `No valid review was returned. Check the reviewer setup, ${RETRY}`],
  ci_attempts_exhausted: ["CI failing", "CI still fails after the repair attempts. Fix the checks on the pull request."],
  model_error: ["Model error", `The model returned an error. Check the provider, ${RETRY}`],
  no_model: ["No model", `No model was available. Check the model configuration, ${RETRY}`],
  interrupted: INTERRUPTED, restart_limit: INTERRUPTED, faulted: INTERRUPTED, orphaned: INTERRUPTED,
};

/** Start time, or creation time for a run that never started; ages and the attention window count from it. */
export const since = (run: ListedRun) => run.startedAt || run.createdAt;

/** One-line tool arguments, cut at 120 characters. */
export function toolSummary(args: unknown): string {
  const flat = JSON.stringify(args ?? {});
  return flat.length > 120 ? `${flat.slice(0, 120)}…` : flat;
}
const own = <T>(table: Record<string, T>, key: string): T | undefined => Object.hasOwn(table, key) ? table[key] : undefined;

export function describe(run: ListedRun, now: number): RunView {
  if (run.status === "blocked") {
    const [label, hint] = own(BLOCKED, run.reason) ?? ["Blocked", `The run stopped (${run.reason || "no reason recorded"}). Check its activity, ${RETRY}`];
    return { group: now - since(run) <= ATTENTION_MS ? "attention" : "finished", tone: "alert", label, hint };
  }
  if (run.status === "queued") return { group: "active", tone: "muted", label: "Queued", hint: "" };
  const phase = own(ACTIVE, run.status);
  if (phase) return { group: "active", tone: "info", label: phase, hint: "" };
  if (run.status === "done") return { group: "finished", tone: "ok", label: run.reason === "published" ? "PR opened" : "Done", hint: "" };
  if (run.status === "aborted") return { group: "finished", tone: "muted", label: "Aborted", hint: "" };
  return { group: "active", tone: "muted", label: run.status, hint: "" };
}

export function ended(run: Pick<ListedRun, "status">): boolean {
  return run.status === "done" || run.status === "blocked" || run.status === "aborted";
}

/** Needs you newest first; In progress running newest first, then queued oldest first; Finished newest first. */
export function order<T extends ListedRun>(runs: readonly T[], now: number): { runs: T[]; groups: Record<Group, T[]>; counts: Counts } {
  const groups: Record<Group, T[]> = { attention: [], active: [], finished: [] };
  for (const run of runs) groups[describe(run, now).group].push(run);
  const newest = (a: T, b: T) => since(b) - since(a) || a.id.localeCompare(b.id);
  groups.attention.sort(newest);
  groups.finished.sort(newest);
  groups.active.sort((a, b) => Number(a.status === "queued") - Number(b.status === "queued") || (a.status === "queued" ? a.createdAt - b.createdAt || a.id.localeCompare(b.id) : newest(a, b)));
  const queued = groups.active.filter((run) => run.status === "queued").length;
  return { runs: [...groups.attention, ...groups.active, ...groups.finished], groups, counts: { attention: groups.attention.length, active: groups.active.length, finished: groups.finished.length, working: groups.active.length - queued, queued } };
}

export function summary(counts: Counts): string {
  return `${counts.attention} need you · ${counts.working} working · ${counts.queued} queued`;
}

export function title(prompt: string): string {
  const line = prompt.split(/\r?\n/).map((text) => text.trim()).find(Boolean) ?? "";
  return line.length > 80 ? `${line.slice(0, 80)}…` : line;
}

export function pullRequest(url: string): string {
  return /^https:\/\/\S+$/.test(url) ? url : "";
}

export function age(since: number, now: number): string {
  const seconds = Math.max(0, Math.floor((now - since) / 1000));
  if (seconds < 60) return `${seconds}s`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`;
  if (seconds < 48 * 3600) return `${Math.floor(seconds / 3600)}h`;
  return `${Math.floor(seconds / 86_400)}d`;
}
