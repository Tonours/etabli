import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { randomUUID } from "node:crypto";
import type { Context } from "@earendil-works/chord/context";
import { obj, union, lit } from "@earendil-works/pi-schema";
import { configure, defineExtension, defineTool, type Conversation, type ConversationId, type Cursor, type ToolExecutionApi } from "@earendil-works/pi-durable";
import { createReadTool } from "@earendil-works/pi-durable/tools";
import { authorFamilies, changePlanStatus, codeRoundVerdict, EtabliPlanDoc, phaseModel, planHash, reviewCandidates, type ModelRoute, type ReviewReceipt } from "./plan-doc.ts";
import { active, RunsDoc } from "./runs-doc.ts";
import { change } from "./change.ts";
import { runCliReview } from "./review-cli.ts";

type Host = { conversation(id: ConversationId, context: Context): Promise<Conversation | undefined> };
type Kind = "plan" | "code";

export function reviewVerdict(body: string, kind: Kind, axis: string): string {
  if (!/STATUS: complete\s*$/.test(body)) throw new Error("Review is incomplete");
  if ((body.match(/^Verdict:/gm)?.length ?? 0) > 1) throw new Error("Review verdict is ambiguous");
  const verdict = /(?:^|\n)Verdict:[ \t]*(GO WITH NOTES|GO|BLOCK|READY|CHALLENGED)[ \t]*\r?\n(?:[ \t]*\r?\n)*STATUS: complete\s*$/.exec(body)?.[1];
  if (!verdict && kind === "code" && axis === "spec" && !/^Verdict:/m.test(body)) {
    const findings = body.replace(/\n?STATUS: complete\s*$/, "").trim();
    if (findings.replace(/^Findings\s*\n/, "").trim() === "No findings.") return "GO";
    if (/^Findings\s*\n\S/.test(findings)) return "BLOCK";
  }
  if (!verdict || !(kind === "plan" ? ["READY", "CHALLENGED"] : ["GO", "GO WITH NOTES", "BLOCK"]).includes(verdict)) throw new Error("Review verdict is missing");
  const section = (heading: string) => {
    const matches = [...body.matchAll(new RegExp(`^### ${heading}[ \\t]*\\r?$`, "gm"))];
    if (matches.length > 1) throw new Error("Review section is ambiguous");
    const match = matches[0];
    return match ? body.slice(match.index + match[0].length).split(/^(?:### |Verdict:|STATUS:)/m)[0].trim() : "";
  };
  const rows = (heading: string) => section(heading).split("\n").filter((line) => /^\|/.test(line) && !/^\|[\s:|-]+$/.test(line)).length;
  if (axis === "logic" && (rows("Lens table") < 2 || rows("Deciding-code table") < 2 || ["Lens table", "Deciding-code table"].some((heading) => /\|\s*not run(?:\s|:|\|)/i.test(section(heading))))) throw new Error("Logic review lacks deciding-code coverage");
  if (axis === "logic" && section("Open questions") && !/^(?:[-*]\s*)?None\.?$/i.test(section("Open questions"))) throw new Error("Logic review has unresolved candidates");
  if (axis === "threat" && ["Deciding inputs", "Entry-point inventory", "Reused guards", "Deferrals", "Rollout", "Attack tests"].some((heading) => !section(heading))) throw new Error("Threat review lacks required tables");
  return verdict;
}

async function nativeAnswer(host: Host, id: ConversationId, route: ModelRoute, context: Context): Promise<string> {
  const conversation = await host.conversation(id, context);
  if (!conversation) throw new Error("Review child is missing");
  let cursor: Cursor | undefined;
  let answer = "";
  let observed = false;
  do {
    const page = await conversation.entries({ order: "ascending" }, 250, cursor, context);
    for (const entry of page.items) for (const message of entry.model ?? []) if (message.role === "assistant") {
      if (message.provider !== route.provider || message.model !== route.modelId) throw new Error("Review effective model differs from selected route");
      observed = true;
      if (!message.content.some((part) => part.type === "toolCall")) answer = message.content.filter((part) => part.type === "text").map((part) => part.text).join("\n");
    }
    cursor = page.next;
  } while (cursor);
  if (!observed || !answer) throw new Error("Review effective provenance or answer is missing");
  return answer;
}

async function childReview(api: ToolExecutionApi, host: Host, route: ModelRoute, cwd: string, prompt: string, readonlyTools: boolean, context: Context, cli: typeof runCliReview): Promise<{ body: string; id: ConversationId }> {
  const id = await api.commit(async (tx) => {
    const child = await tx.createConversation({ ownership: { kind: "task", taskId: api.taskId } });
    const tools = readonlyTools && route.transport === "native" ? [createReadTool()] : [];
    await configure(tx, child.id, { cwd, model: route, extensions: [], tools, modelTools: tools, maxTurns: 40, compaction: { enabled: false } });
    return child.id;
  }, context);
  if (route.transport === "cli") {
    const response = await cli({ cwd, prompt, modelId: route.modelId }, { signal: context.abortSignal });
    await api.commit((tx) => tx.appendEntry(id, { kind: "etabli.cli-review", data: { prompt, ...response } }), context);
    return { body: response.body, id };
  }
  const child = await api.conversation(id, context);
  if (!child) throw new Error("Review child is missing");
  const result = await (await child.submit({ type: "input", content: prompt, requestId: `review:${api.taskId}:${id}` }, context)).wait(context);
  if (result.status !== "done") throw new Error("Native review did not finish");
  return { body: await nativeAnswer(host, id, route, context), id };
}

export function createReviewExtension(checkout: string, host: Host, cli = runCliReview) {
  return defineExtension({ name: "etabli-review", tools: [defineTool({
    name: "review", description: "Run independent read-only reviews of the current native plan or cumulative code patch. Three BLOCK rounds on an unchanged source block the run.",
    parameters: obj({ kind: union([lit("plan"), lit("code")]) }),
    async execute(args, api, context) {
      const run = (await api.snapshot(RunsDoc, context))?.runs.find((run) => run.conversationId === api.conversationId);
      if (!run || !active(run) || run.route === "legacy") throw new Error("Review requires an active workflow run");
      try {
        const conversation = await host.conversation(api.conversationId, context);
        if (!conversation) throw new Error("Run conversation is missing");
        const authors = await authorFamilies(checkout, conversation, context);
        const plan = (await api.snapshot(EtabliPlanDoc, api.conversationId, context)) ?? EtabliPlanDoc.definition.initial();
        if (args.kind === "plan" && !plan.enabled) throw new Error("This run has no plan document");
        if (args.kind === "code" && plan.enabled && plan.status !== "READY") throw new Error("Implementation review requires READY");
        const source = args.kind === "plan" ? { hash: planHash(plan), patch: JSON.stringify(plan.sections) } : await change(run.worktree);
        const round = randomUUID();
        const receipts: ReviewReceipt[] = [];
        await api.commit(async (tx) => { (await tx.doc(RunsDoc)).runs.find((row) => row.id === run.id)!.status = "reviewing"; }, context);
        const routes = await reviewCandidates(checkout, authors);
        const axes = args.kind === "plan" ? ["adversary"] : ["logic", "spec", "threat", "adversary"];
        for (const axis of axes) {
          const contract = (await Promise.all((axis === "adversary" ? ["skills/adversary.md", "templates/review-lead.md", "review-rubric.md"] : [`templates/review-${axis}-hunter.md`]).map((path) => readFile(join(checkout, "workflow", path), "utf8")))).join("\n\n");
          const intent = axis === "logic" ? "" : `\nIntent: ${run.prompt}\n${axis === "adversary" ? `Authoritative native plan: ${JSON.stringify(plan.sections)}\nPrior independent reviews: ${JSON.stringify(receipts)}` : ""}`;
          const prompt = `Axis: ${axis}\n${contract}\nRead-only review at ${run.worktree}. No writes, commands, git, network or delegation. The patch below is the complete immutable pin. Native plan storage replaces PLAN.md; do not seek a projected plan file.\nMode: ${args.kind === "plan" ? "plan adversary" : "code diff"}. You report only; parent writes the native document. End with Verdict: ${args.kind === "plan" ? "READY or CHALLENGED" : "GO or GO WITH NOTES or BLOCK"} and STATUS: complete.${intent}\nSource SHA256: ${source.hash}\n<source>\n${source.patch}\n</source>`;
          let reviewed = false;
          for (const route of routes) {
            try {
              const result = await childReview(api, host, route, run.worktree, prompt, axis !== "spec", context, cli);
              const verdict = reviewVerdict(result.body, args.kind, axis);
              receipts.push({ kind: args.kind, axis, round, sourceHash: source.hash, planHash: planHash(plan), authors, reviewer: route, verdict, body: result.body, conversationId: result.id });
              reviewed = true;
              break;
            } catch (error) { context.abortSignal?.throwIfAborted(); if (route === routes.at(-1)) throw error; }
          }
          if (!reviewed) throw new Error("No eligible available reviewer");
        }
        const current = await api.snapshot(EtabliPlanDoc, api.conversationId, context);
        if (planHash(current ?? plan) !== planHash(plan) || args.kind === "code" && (await change(run.worktree)).hash !== source.hash || JSON.stringify(await authorFamilies(checkout, conversation, context)) !== JSON.stringify(authors)) throw new Error("Review source or author provenance changed");
        const challenged = args.kind === "plan" && receipts.some((receipt) => receipt.verdict === "CHALLENGED");
        const planner = challenged ? await phaseModel(checkout, "planner") : undefined;
        const blocked = await api.commit(async (tx) => {
          const document = await tx.doc(EtabliPlanDoc, api.conversationId);
          document.reviews.push(...receipts);
          const relevant = document.reviews.filter((receipt) => receipt.kind === args.kind && receipt.sourceHash === source.hash);
          const blockedRounds = new Set(relevant.filter((receipt) => receipt.axis === "adversary" && (args.kind === "plan" ? receipt.verdict === "CHALLENGED" : codeRoundVerdict(relevant.filter((item) => item.round === receipt.round)) === "BLOCK")).map((receipt) => receipt.round));
          const stored = (await tx.doc(RunsDoc)).runs.find((row) => row.id === run.id)!;
          if (!active(stored)) throw new Error("Run ended during review");
          const stop = blockedRounds.size >= 3;
          if (planner) await changePlanStatus(tx, api.conversationId, "CHALLENGED", planner, authors);
          stored.status = stop ? "blocked" : document.enabled && document.status !== "READY" ? "planning" : "implementing";
          if (stop) stored.reason = "review_block_limit";
          return stop;
        }, context);
        return { output: [{ type: "text", text: JSON.stringify(receipts) }], control: { terminate: blocked } };
      } catch (error) {
        if (context.abortSignal?.aborted) throw error;
        await api.commit(async (tx) => { const stored = (await tx.doc(RunsDoc)).runs.find((row) => row.id === run.id)!; if (active(stored)) { stored.status = "blocked"; stored.reason = "review_unavailable_or_invalid"; } }, context);
        return { output: [{ type: "text", text: "Review unavailable, incomplete or invalid; run blocked." }], control: { terminate: true } };
      }
    },
  })] });
}
