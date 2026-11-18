import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import type { Context } from "@earendil-works/chord/context";
import { obj, str, union, lit } from "@earendil-works/pi-schema";
import { configure, defineDoc, defineExtension, defineTool, section, type Conversation, type ConversationId, type Cursor, type ModelRef, type Tx } from "@earendil-works/pi-durable";
import { active, RunsDoc } from "./runs-doc.ts";

export type PlanStatus = "DRAFT" | "CHALLENGED" | "READY";
export type ModelRole = "planner" | "implementer" | "escalation";
export type ModelRoute = ModelRef & { alias: string; family: string; transport: "native" | "cli" };
export type ReviewReceipt = {
  kind: "plan" | "code";
  axis: string;
  round: string;
  sourceHash: string;
  planHash: string;
  authors: string[];
  reviewer: ModelRoute;
  verdict: string;
  body: string;
  conversationId: ConversationId;
};
export type PlanState = { enabled: boolean; status: PlanStatus; sections: Record<string, string>; escalation: string; reviews: ReviewReceipt[] };

export function codeRoundVerdict(receipts: readonly ReviewReceipt[]): string | undefined {
  const first = receipts[0];
  if (receipts.length !== 4 || !first) return undefined;
  if (receipts.some((receipt) => receipt.kind !== "code" || receipt.round !== first.round || receipt.sourceHash !== first.sourceHash || receipt.planHash !== first.planHash || JSON.stringify(receipt.authors) !== JSON.stringify(first.authors) || !["GO", "GO WITH NOTES", "BLOCK"].includes(receipt.verdict))) return undefined;
  if (!["logic", "spec", "threat", "adversary"].every((axis) => receipts.some((receipt) => receipt.axis === axis))) return undefined;
  return receipts.find((receipt) => receipt.axis === "adversary")!.verdict;
}

export const EtabliPlanDoc = defineDoc<PlanState>({
  kind: "etabli.plan", version: 1, scope: "conversation", history: "latest", fork: "initial",
  initial: () => ({ enabled: false, status: "DRAFT", sections: {}, escalation: "", reviews: [] }),
  checkpointWhen: () => true,
});

type Routes = {
  models: Record<string, { family: string; harness: string; model: string | null }>;
  author_family_routes: Record<string, string[]>;
  durable: { planner: string; planner_escalation: string[]; implementer: string; native_routes: Record<string, { provider: string }>; review: { cli_fallback: string } };
};

export async function readRoutes(checkout: string): Promise<Routes> {
  return JSON.parse(await readFile(join(checkout, "workflow/runtime/model-routing.json"), "utf8")) as Routes;
}

function resolveRoute(routes: Routes, alias: string): ModelRoute {
  const entry = routes.models[alias];
  const native = routes.durable.native_routes[alias];
  if (!entry?.model || !entry.family || (!native && (alias !== routes.durable.review.cli_fallback || entry.harness !== "claude"))) throw new Error("Model route is unavailable");
  return { alias, family: entry.family, provider: native?.provider ?? entry.family, modelId: entry.model, transport: native ? "native" : "cli" };
}

export async function phaseModel(checkout: string, role: ModelRole): Promise<ModelRoute> {
  const routes = await readRoutes(checkout);
  const alias = role === "escalation" ? routes.durable.planner_escalation[0] : routes.durable[role];
  const route = resolveRoute(routes, alias);
  if (route.transport !== "native") throw new Error("Phase requires a native model route");
  return route;
}

export async function reviewCandidates(checkout: string, authors: readonly string[]): Promise<ModelRoute[]> {
  const routes = await readRoutes(checkout);
  if (!authors.length || authors.some((family) => !routes.author_family_routes[family])) throw new Error("Review author provenance is missing");
  const aliases = routes.author_family_routes[authors[0]].filter((alias) => authors.every((family) => routes.author_family_routes[family].includes(alias)));
  const candidates = aliases.filter((alias) => !authors.includes(routes.models[alias]?.family)).map((alias) => resolveRoute(routes, alias));
  if (!candidates.length) throw new Error("No eligible review route");
  const native = candidates.filter((route) => route.transport === "native");
  return native.length ? native : candidates;
}

export function planHash(plan: Readonly<PlanState>): string {
  return createHash("sha256").update(JSON.stringify(Object.entries(plan.sections).sort(([a], [b]) => a.localeCompare(b)))).digest("hex");
}

export async function templateSections(checkout: string): Promise<Record<string, string>> {
  const template = await readFile(join(checkout, "PLAN_TEMPLATE.md"), "utf8");
  return Object.fromEntries([...template.matchAll(/^## (.+)$/gm)].map((match) => [match[1], ""]));
}

export async function startPlan(tx: Tx, conversationId: ConversationId, sections: Record<string, string>, model: ModelRef): Promise<void> {
  const plan = await tx.doc(EtabliPlanDoc, conversationId);
  plan.enabled = true;
  plan.status = "DRAFT";
  plan.sections = sections;
  await configure(tx, conversationId, { model });
  const run = (await tx.doc(RunsDoc)).runs.find((run) => run.conversationId === conversationId);
  if (run && active(run) && run.route !== "legacy") {
    run.admissionRoute ??= run.route;
    run.route = "plan";
    run.status = "planning";
  }
}

export async function changePlanStatus(tx: Tx, conversationId: ConversationId, status: PlanStatus, model: ModelRef, authors: readonly string[]): Promise<void> {
  const plan = await tx.doc(EtabliPlanDoc, conversationId);
  if (!plan.enabled) throw new Error("This run has no plan route");
  if (status === "READY" && !plan.reviews.some((review) => review.kind === "plan" && review.sourceHash === planHash(plan) && review.verdict === "READY" && JSON.stringify([...review.authors].sort()) === JSON.stringify([...authors].sort()))) throw new Error("READY requires an eligible review of the current plan");
  plan.status = status;
  await configure(tx, conversationId, { model });
  const run = (await tx.doc(RunsDoc)).runs.find((run) => run.conversationId === conversationId);
  if (run && active(run) && run.route !== "legacy") run.status = status === "READY" ? "implementing" : "planning";
}

export async function authorFamilies(checkout: string, conversation: Pick<Conversation, "entries">, context: Context): Promise<string[]> {
  const routes = await readRoutes(checkout);
  const families = new Set<string>();
  let cursor: Cursor | undefined;
  do {
    const page = await conversation.entries({ order: "ascending" }, 250, cursor, context);
    for (const entry of page.items) for (const message of entry.model ?? []) if (message.role === "assistant") {
      const matching = Object.entries(routes.durable.native_routes).filter(([, route]) => route.provider === message.provider).map(([alias]) => routes.models[alias].family);
      if (!matching.length || new Set(matching).size !== 1) throw new Error("Author model provenance is unresolved");
      families.add(matching[0]);
    }
    cursor = page.next;
  } while (cursor);
  if (!families.size) throw new Error("Review author provenance is missing");
  return [...families].sort();
}

export function createPlanExtension(checkout: string, authors: (id: ConversationId, context: Context) => Promise<string[]>, model: (role: ModelRole) => Promise<ModelRef> = (role) => phaseModel(checkout, role)) {
  return defineExtension({
    name: "etabli-plan",
    sections: [section("etabli-run", async (input, context) => {
      const run = (await input.read.snapshot(RunsDoc, context))?.runs.find((run) => run.conversationId === input.conversationId);
      return run && run.route !== "legacy" ? `The host already isolated this run in ${run.worktree} on branch ${run.branch}. Work there. Use native plan tools when a plan is required, review(kind=plan) before READY, and review(kind=code) on the final committed change. Section edits after READY reopen CHALLENGED on the planner; use them for replanning. The host journals review receipts automatically. Fold findings through the shared workflow. Finish with publish(title, body); an answer alone blocks the run. The publish tool owns push and PR creation. Never merge or send external comments. Current run phase: ${run.status}.` : "";
    }), section("etabli-plan-document", async (input, context) => {
      const plan = await input.read.snapshot(EtabliPlanDoc, input.conversationId, context);
      return plan?.enabled ? `The authoritative plan is this native document. Use plan tools; do not project it to PLAN.md or docs/plan/.\n${JSON.stringify(plan)}` : "This run has no plan document. Use plan_begin if the shared workflow routes this task through a plan.";
    })],
    tools: [
      defineTool({ name: "plan_begin", description: "Start a plan-route task in the native store and switch to the planner.", parameters: obj({}), replay: "safe", async execute(_args, api, context) {
        const sections = await templateSections(checkout);
        const planner = await model("planner");
        await api.commit(async (tx) => {
          const run = (await tx.doc(RunsDoc)).runs.find((run) => run.conversationId === api.conversationId);
          if (!run || run.route === "legacy") throw new Error("Plan creation requires a workflow run");
          if ((await tx.doc(EtabliPlanDoc, api.conversationId)).enabled) return;
          await startPlan(tx, api.conversationId, sections, planner);
        }, context);
        return { output: [{ type: "text", text: "Plan created: DRAFT. Continue with the planner." }] };
      } }),
      defineTool({ name: "plan_read", description: "Read the authoritative native plan document.", parameters: obj({}), replay: "safe", async execute(_args, api, context) {
        return { output: [{ type: "text", text: JSON.stringify(await api.snapshot(EtabliPlanDoc, api.conversationId, context)) }] };
      } }),
      defineTool({ name: "plan_section", description: "Replace one existing plan-template section in the native document.", parameters: obj({ section: str({ minLength: 1, maxLength: 200 }), content: str({ maxLength: 128_000 }) }), replay: "safe", async execute(args, api, context) {
        const planner = await model("planner");
        await api.commit(async (tx) => {
          const plan = await tx.doc(EtabliPlanDoc, api.conversationId);
          if (!plan.enabled || !Object.hasOwn(plan.sections, args.section)) throw new Error("Unknown native plan section");
          if (plan.sections[args.section] === args.content) return;
          plan.sections[args.section] = args.content;
          if (plan.status === "READY") await changePlanStatus(tx, api.conversationId, "CHALLENGED", planner, []);
        }, context);
        return { output: [{ type: "text", text: "Plan section stored. An edit after READY reopens CHALLENGED on the planner; obtain a new plan review. Review receipts journal evidence automatically without rewriting sections." }] };
      } }),
      defineTool({ name: "plan_status", description: "Set plan status; READY requires an eligible independent review of the current content.", parameters: obj({ status: union([lit("DRAFT"), lit("CHALLENGED"), lit("READY")]) }), replay: "safe", async execute(args, api, context) {
        const observedAuthors = await authors(api.conversationId, context);
        const target = await model(args.status === "READY" ? "implementer" : "planner");
        await api.commit((tx) => changePlanStatus(tx, api.conversationId, args.status, target, observedAuthors), context);
        return { output: [{ type: "text", text: `Plan status: ${args.status}. Model switch applies to the next request.` }] };
      } }),
      defineTool({ name: "plan_escalate", description: "Record a reason for escalating the active planner to the configured escalation model.", parameters: obj({ reason: str({ minLength: 1, maxLength: 4000 }) }), replay: "safe", async execute(args, api, context) {
        const escalation = await model("escalation");
        await api.commit(async (tx) => {
          const plan = await tx.doc(EtabliPlanDoc, api.conversationId);
          if (!plan.enabled || plan.status === "READY") throw new Error("Only an active planner may escalate");
          plan.escalation = args.reason;
          await configure(tx, api.conversationId, { model: escalation });
        }, context);
        return { output: [{ type: "text", text: "Planner escalation recorded." }] };
      } }),
    ],
  });
}
