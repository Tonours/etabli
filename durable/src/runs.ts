import { randomUUID } from "node:crypto";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { LiveDoc, configure, type Harness, type Extension, type ModelRef } from "@earendil-works/pi-durable";
import { Repositories } from "./repositories.ts";
import { guardedAgent } from "./guards.ts";
import { notify } from "./notify.ts";
import { phaseModel, startPlan, templateSections, type ModelRole } from "./plan-doc.ts";
import { finalSnapshot } from "./backup.ts";
import { reconcilePublication, type Command } from "./publish.ts";

import { active, activeStatuses, RunsDoc, type Run } from "./runs-doc.ts";
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

  constructor(options: { guard: Extension; harness: Harness; repositories: Repositories; model: () => Promise<ModelRef>; workflow?: string; phaseModel?: (role: ModelRole) => Promise<ModelRef>; publishCommand?: Command; now?: () => number; wallMs?: number; maxTurns?: number; notifyArgv?: readonly string[] }) {
    this.harness = options.harness;
    this.guard = options.guard;
    this.repositories = options.repositories;
    this.model = options.model;
    this.now = options.now ?? Date.now;
    this.wallMs = options.wallMs ?? 4 * 60 * 60 * 1000;
    this.maxTurns = options.maxTurns ?? 64;
    this.notifyArgv = options.notifyArgv ?? [];
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
      const id = randomUUID();
      return this.harness.commit(async (tx) => {
        const conversation = await tx.createConversation({ ownership: { kind: "ownerless" } });
        const run: Run = { id, requestId, repo, prompt, conversationId: conversation.id, branch: `feat/durable-${id.replaceAll("-", "")}`, worktree: this.repositories.path(id), route: this.workflow ? route : "legacy", status: "queued", reason: "", url: "", createdAt: this.now(), startedAt: 0, deadline: 0, maxTurns: this.maxTurns, submissionId: "", notified: false };
        (await tx.doc(RunsDoc)).runs.push(run);
        return run;
      }, context);
    });
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
        await notify(this.notifyArgv, run).catch(() => undefined);
      }
      for (const run of await this.list()) if (run.route !== "legacy" && ["done", "blocked", "aborted"].includes(run.status) && run.notified && !this.stopping.has(run.id)) await finalSnapshot(this.repositories.root, run.id).catch(() => console.error("Final snapshot unavailable; check sqlite3 and state permissions; retrying", run.id));
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
