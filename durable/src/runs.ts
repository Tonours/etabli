import { randomUUID } from "node:crypto";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { LiveDoc, InboxDoc, configure, type Tx, type Harness, type Extension, type ModelRef } from "@earendil-works/pi-durable";
import { Repositories } from "./repositories.ts";
import { guardedAgent } from "./guards.ts";
import { notify } from "./notify.ts";
import { EtabliPlanDoc, phaseModel, startPlan, templateSections, type ModelRole } from "./plan-doc.ts";
import { finalSnapshot } from "./backup.ts";
import { PublishDoc, reconcilePublication, type Command } from "./publish.ts";

import { active, activeStatuses, RunsDoc, type Run } from "./runs-doc.ts";
import { SchedulesDoc, nextDue } from "./schedule.ts";
import { CiDoc, terminalGeneration } from "./ci-doc.ts";
import { git } from "./change.ts";
export { RunsDoc, type Run } from "./runs-doc.ts";

export class Runs {
  readonly harness: Harness;
  readonly repositories: Repositories;
  readonly guard: Extension;
  readonly model: () => Promise<ModelRef>;
  readonly now: () => number;
  readonly wallMs: number;
  readonly maxTurns: number;
  readonly notifyArgv: readonly string[];
  readonly workflow: string | undefined;
  readonly phaseModel: (role: ModelRole) => Promise<ModelRef>;
  readonly publishCommand: Command | undefined;
  private line: Promise<unknown> = Promise.resolve();
  private stopping = new Map<string, Promise<boolean>>();
  private validated = false;
  private notifications = new Set<Promise<void>>();
  readonly pushNotify: (() => Promise<void>) | undefined;

  constructor(options: { guard: Extension; harness: Harness; repositories: Repositories; model: () => Promise<ModelRef>; workflow?: string; phaseModel?: (role: ModelRole) => Promise<ModelRef>; publishCommand?: Command; now?: () => number; wallMs?: number; maxTurns?: number; notifyArgv?: readonly string[]; pushNotify?: () => Promise<void> }) {
    this.harness = options.harness;
    this.guard = options.guard;
    this.repositories = options.repositories;
    this.model = options.model;
    this.now = options.now ?? Date.now;
    this.wallMs = options.wallMs ?? 4 * 60 * 60 * 1000;
    this.maxTurns = options.maxTurns ?? 64;
    this.notifyArgv = options.notifyArgv ?? [];
    this.pushNotify = options.pushNotify;
    this.workflow = options.workflow;
    this.phaseModel = options.phaseModel ?? ((role) => phaseModel(options.workflow!, role));
    this.publishCommand = options.publishCommand;
    if (!Number.isSafeInteger(this.wallMs) || this.wallMs < 1 || !Number.isSafeInteger(this.maxTurns) || this.maxTurns < 1) throw new Error("Run limits must be positive integers");
  }

  private serialized<T>(action: () => Promise<T>): Promise<T> {
    const next = this.line.then(action);
    this.line = next.catch(() => undefined);
    return next;
  }

  async drainNotifications(): Promise<void> { await Promise.all(this.notifications); }

  async list(): Promise<readonly Run[]> { return (await this.harness.snapshot(RunsDoc, context))?.runs ?? []; }

  async show(id: string): Promise<Run> {
    const run = (await this.list()).find((run) => run.id === id);
    if (!run) throw new Error("Run not found");
    return run;
  }

  async submit(repo: string, prompt: string, requestId: string, route: "answer" | "plan" = "answer"): Promise<Run> {
    repo = this.repositories.policy.allow(repo);
    if (!prompt.trim() || prompt.length > 64_000 || !requestId || requestId.length > 200) throw new Error("Provide a bounded prompt and request id");
    return this.serialized(async () => {
      const existing = (await this.list()).find((run) => run.requestId === requestId);
      if (existing) {
        if (existing.repo !== repo || existing.prompt !== prompt || existing.route !== (this.workflow ? route : "legacy")) throw new Error("Request id already belongs to a different input");
        return existing;
      }
      await this.repositories.admit(repo);
      return this.harness.commit((tx) => this.create(tx, repo, prompt, requestId, route), context);
    });
  }

  private async create(tx: Tx, repo: string, prompt: string, requestId: string, route: "answer" | "plan"): Promise<Run> {
    const id = randomUUID();
    const conversation = await tx.createConversation({ ownership: { kind: "ownerless" } });
    const run: Run = { id, requestId, repo, prompt, conversationId: conversation.id, branch: `feat/durable-${id.replaceAll("-", "")}`, worktree: this.repositories.path(id), route: this.workflow ? route : "legacy", status: "queued", reason: "", url: "", createdAt: this.now(), startedAt: 0, deadline: 0, maxTurns: this.maxTurns, submissionId: "", notified: false };
    (await tx.doc(RunsDoc)).runs.push(run);
    return run;
  }

  async submitOccurrence(scheduleId: string, due: number): Promise<void> {
    const row = (await this.harness.snapshot(SchedulesDoc, context))?.schedules.find((row) => row.value.id === scheduleId);
    if (!row || row.deleted || row.occurrence?.due !== due || row.occurrence.status !== "pending") return;
    try { this.repositories.policy.allow(row.value.repo); }
    catch {
      await this.harness.commit(async (tx) => {
        const stored = (await tx.doc(SchedulesDoc)).schedules.find((row) => row.value.id === scheduleId);
        if (stored && !stored.deleted && stored.occurrence?.due === due && stored.occurrence.status === "pending") {
          stored.occurrence.status = "failed"; stored.occurrence.error = "policy_denied";
          stored.value.nextDue = nextDue(stored.value.cron, Math.max(due, this.now()), 400);
        }
      }, context);
      return;
    }
    await this.repositories.admit(row.value.repo);
    await this.harness.commit(async (tx) => {
      const stored = (await tx.doc(SchedulesDoc)).schedules.find((row) => row.value.id === scheduleId);
      if (!stored || stored.deleted || stored.occurrence?.due !== due || stored.occurrence.status !== "pending") return;
      const occurrence = stored.occurrence;
      const existing = (await tx.doc(RunsDoc)).runs.find((run) => run.requestId === occurrence.requestId);
      if (existing) {
        occurrence.status = "failed"; occurrence.error = "request_identity_conflict";
      } else {
        const run = await this.create(tx, stored.value.repo, stored.value.prompt, occurrence.requestId, "plan");
        occurrence.runId = run.id; occurrence.status = "acknowledged"; occurrence.error = "";
      }
      stored.value.nextDue = nextDue(stored.value.cron, Math.max(due, this.now()), 400);
    }, context);
  }

  async reactivateCi(id: string, number: number): Promise<boolean> {
    const run = await this.show(id);
    const ci = (await this.harness.snapshot(CiDoc, context))?.runs.find((row) => row.runId === id);
    if (!ci || run.status !== "done") return false;
    await this.repositories.prepare(run.id, run.repo, run.branch);
    if (await git(run.worktree, ["status", "--porcelain"]) || await git(run.worktree, ["rev-parse", "HEAD"]) !== ci.head) {
      await this.harness.commit(async (tx) => {
        const record = (await tx.doc(CiDoc)).runs.find((row) => row.runId === id)!;
        const attempt = record.attempts.find((attempt) => attempt.number === number);
        if (attempt?.state === "reserved") { attempt.state = "cancelled"; record.retired = "worktree_changed"; }
      }, context);
      return false;
    }
    const model = this.workflow ? await this.phaseModel("implementer") : await this.model();
    const conversation = await this.harness.conversation(run.conversationId, context);
    if (!conversation) throw new Error("Stored run conversation is missing");
    return this.serialized(() => this.harness.commit(async (tx) => {
      const runs = (await tx.doc(RunsDoc)).runs;
      const stored = runs.find((row) => row.id === id)!;
      const record = (await tx.doc(CiDoc)).runs.find((row) => row.runId === id)!;
      const attempt = record.attempts.find((attempt) => attempt.number === number);
      const publication = await tx.doc(PublishDoc, run.conversationId);
      const plan = await tx.doc(EtabliPlanDoc, run.conversationId);
      const live = await tx.doc(LiveDoc, run.conversationId);
      const inbox = await tx.doc(InboxDoc, run.conversationId);
      if (!attempt || attempt.state !== "reserved" || record.retired || stored.status !== "done" || stored.reason !== "published" || !stored.notified || stored.url !== record.url || publication.head !== record.head || attempt.triggerHead !== record.head) return false;
      if (runs.filter((row) => active(row) || this.stopping.has(row.id)).length >= 2 || live.run || inbox.items.length || this.stopping.has(id)) return false;
      if (plan.enabled && plan.status !== "READY") return false;
      await configure(tx, run.conversationId, guardedAgent({ cwd: run.worktree, model, maxTurns: this.maxTurns }, this.guard));
      plan.reviews = plan.reviews.filter((review) => review.kind !== "code");
      Object.assign(publication, PublishDoc.definition.initial());
      stored.submissionId = await conversation.submit(tx, { type: "input", content: attempt.input, requestId: attempt.requestId, whenBusy: "reject" });
      attempt.state = "submitted";
      stored.status = "implementing"; stored.reason = ""; stored.notified = false;
      stored.startedAt = this.now(); stored.deadline = stored.startedAt + this.wallMs; stored.maxTurns = this.maxTurns;
      return true;
    }, context));
  }

  async exhaustCi(id: string, head: string): Promise<void> {
    await this.serialized(() => this.harness.commit(async (tx) => {
      const run = (await tx.doc(RunsDoc)).runs.find((run) => run.id === id)!;
      const ci = (await tx.doc(CiDoc)).runs.find((row) => row.runId === id)!;
      if (run.status !== "done" || ci.head !== head || ci.attempts.filter((attempt) => attempt.state === "submitted").length < 2) return;
      run.status = "blocked"; run.reason = "ci_attempts_exhausted"; run.notified = false; ci.retired = "attempts_exhausted";
    }, context));
  }

  private async finish(id: string, status: Run["status"], reason: string, expected: readonly Run["status"][] = activeStatuses): Promise<boolean> {
    return this.harness.commit(async (tx) => {
      const run = (await tx.doc(RunsDoc)).runs.find((run) => run.id === id)!;
      if (!expected.includes(run.status)) return false;
      run.status = status;
      run.reason = reason;
      return true;
    }, context);
  }

  private stop(id: string, status: "blocked" | "aborted", reason: string, expected: readonly Run["status"][] = ["queued", ...activeStatuses]): Promise<boolean> {
    const pending = this.stopping.get(id);
    if (pending) return pending;
    const work = (async () => {
      if (!await this.finish(id, status, reason, expected)) return false;
      const run = await this.show(id);
      await (await this.harness.conversation(run.conversationId, context))?.abort(context, { background: true });
      return true;
    })().finally(() => { this.stopping.delete(id); });
    this.stopping.set(id, work);
    return work;
  }

  async enforceLimits(): Promise<void> {
    if (!this.validated) return;
    await Promise.all((await this.list()).filter((run) => active(run) && this.now() >= run.deadline).map((run) => this.stop(run.id, "blocked", "wall_clock_limit")));
  }

  async drainStops(): Promise<void> { await Promise.all(this.stopping.values()); }

  async tick(): Promise<void> {
    return this.serialized(async () => {
      await this.enforceLimits();
      for (const run of await this.list()) {
        if (!active(run)) continue;
        const conversation = await this.harness.conversation(run.conversationId, context);
        if (!conversation) throw new Error("Stored run conversation is missing");
        const live = await this.harness.snapshot(LiveDoc, run.conversationId, context);
        if (live?.run) continue;
        const submission = run.submissionId ? await this.harness.submission(run.submissionId, context) : undefined;
        const receipt = await submission?.status(context);
        if (receipt?.status === "done") await this.finish(run.id, run.route === "legacy" ? "done" : "blocked", run.route === "legacy" ? "answer" : "workflow_finished_without_publication");
        else if (receipt?.status === "unanswered") await this.finish(run.id, "blocked", live?.runFailure?.reason ?? "unanswered");
      }
      let busy = (await this.list()).filter((run) => active(run) || this.stopping.has(run.id)).length;
      for (const run of await this.list()) {
        if (busy >= 2) break;
        if (run.status !== "queued") continue;
        try {
          await this.repositories.prepare(run.id, run.repo, run.branch);
          const model = run.route === "plan" ? await this.phaseModel("planner") : await this.model();
          const sections = run.route === "plan" ? await templateSections(this.workflow!) : undefined;
          const conversation = await this.harness.conversation(run.conversationId, context);
          if (!conversation) throw new Error("Stored run conversation is missing");
          const started = await this.harness.commit(async (tx) => {
            const runs = (await tx.doc(RunsDoc)).runs;
            const stored = runs.find((candidate) => candidate.id === run.id)!;
            if (stored.status !== "queued" || runs.filter((candidate) => active(candidate) || this.stopping.has(candidate.id)).length >= 2) return false;
            await configure(tx, run.conversationId, guardedAgent({ cwd: run.worktree, model, maxTurns: run.maxTurns }, this.guard));
            if (sections) await startPlan(tx, run.conversationId, sections, model);
            const submissionId = await conversation.submit(tx, { type: "input", content: run.prompt, requestId: `start:${run.requestId}` });
            stored.submissionId = submissionId;
            stored.status = run.route === "plan" ? "planning" : "implementing";
            stored.startedAt = this.now();
            stored.deadline = stored.startedAt + this.wallMs;
            return true;
          }, context);
          if (started) busy++;
        } catch {
          await this.finish(run.id, "blocked", "run_setup_failed", ["queued"]);
        }
      }
      for (const run of await this.list()) if (["done", "blocked", "aborted"].includes(run.status) && !this.stopping.has(run.id)) await reconcilePublication(this.harness, run, this.repositories.policy, context, this.publishCommand);
      for (const run of await this.list()) {
        if (!["done", "blocked", "aborted"].includes(run.status) || run.notified || this.stopping.has(run.id)) continue;
        await this.harness.commit(async (tx) => {
          (await tx.doc(RunsDoc)).runs.find((candidate) => candidate.id === run.id)!.notified = true;
        }, context);
        if (["done", "blocked"].includes(run.status) && this.pushNotify) {
          const pending = this.pushNotify().catch(() => undefined).finally(() => this.notifications.delete(pending));
          this.notifications.add(pending);
        }
        await notify(this.notifyArgv, run).catch(() => undefined);
      }
      for (const run of await this.list()) if (run.route !== "legacy" && ["done", "blocked", "aborted"].includes(run.status) && run.notified && !this.stopping.has(run.id)) await finalSnapshot(this.repositories.root, run.id, terminalGeneration(run, (await this.harness.snapshot(CiDoc, context))?.runs.find((row) => row.runId === run.id))).catch(() => console.error("Final snapshot unavailable; check sqlite3 and state permissions; retrying", run.id));
    });
  }

  async steer(id: string, content: string, requestId: string): Promise<number> {
      const run = await this.show(id);
      if (!active(run)) throw new Error("Only an active run can be steered");
      if (!content.trim() || content.length > 64_000 || !requestId || requestId.length > 200) throw new Error("Provide bounded steering input and request id");
      const conversation = await this.harness.conversation(run.conversationId, context);
      if (!conversation) throw new Error("Run conversation missing");
      return (await conversation.submit({ type: "input", content, whenBusy: "steer", whenIdle: "reject", requestId }, context)).id;
  }

  async abort(id: string): Promise<boolean> {
    await this.show(id);
    return this.stop(id, "aborted", "user_abort");
  }

  async reconcile(): Promise<void> {
    if ((await this.list()).filter(active).length > 2) throw new Error("Stored concurrency exceeds two; inspect the store before resuming");
    for (const run of await this.list()) {
      if (run.worktree !== this.repositories.path(run.id) && (active(run) || run.status === "queued" || (await this.harness.snapshot(LiveDoc, run.conversationId, context))?.run)) {
        throw new Error("Active run worktree belongs to another state directory; restore completed runs or recover the original state path");
      }
    }
    this.validated = true;
    await this.enforceLimits();
    for (const run of await this.list()) {
      if (active(run)) {
        try { await this.repositories.prepare(run.id, run.repo, run.branch); }
        catch { await this.stop(run.id, "blocked", "run_setup_failed", activeStatuses); }
      }
      if (run.status === "aborted" || run.status === "blocked") await this.stop(run.id, run.status, run.reason, [run.status]);
    }
    await this.tick();
    this.harness.resume();
  }
}
