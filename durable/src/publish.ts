import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { mkdtemp, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { obj, str } from "@earendil-works/pi-schema";
import { defineDoc, defineExtension, defineTool, type Conversation, type ConversationId, type Harness } from "@earendil-works/pi-durable";
import type { Context } from "@earendil-works/chord/context";
import { prBodyGuardDecision } from "../../workflow/runtime/pr-body-guard.mjs";
import { authorFamilies, codeRoundVerdict, EtabliPlanDoc, planHash, type ReviewReceipt } from "./plan-doc.ts";
import { active, RunsDoc, type Run } from "./runs-doc.ts";
import { change, git } from "./change.ts";
import { CiDoc } from "./ci-doc.ts";
import { OwnerPolicy } from "./policy.ts";

export const PublishDoc = defineDoc<PublishIntent & { reconciled: boolean; reconcileError: string }>({ kind: "etabli.publish", version: 1, scope: "conversation", history: "latest", fork: "initial", initial: () => ({ title: "", body: "", head: "", base: "", sourceHash: "", reconciled: false, reconcileError: "" }), checkpointWhen: () => true });

export function approvedChange(reviews: readonly ReviewReceipt[], sourceHash: string, currentPlanHash: string, authors: readonly string[]): boolean {
  const current = reviews.filter((receipt) => receipt.kind === "code" && receipt.sourceHash === sourceHash && receipt.planHash === currentPlanHash && JSON.stringify([...receipt.authors].sort()) === JSON.stringify([...authors].sort()));
  const latest = current.at(-1)?.round;
  return !!latest && ["GO", "GO WITH NOTES"].includes(codeRoundVerdict(current.filter((receipt) => receipt.round === latest)) ?? "");
}

export type PublishIntent = { title: string; body: string; head: string; base: string; sourceHash: string };
type Pull = { url: string; headRefOid: string; baseRefName: string; state: string; headRepositoryOwner: { login: string }; headRefName?: string };
export type Command = (cwd: string, command: string, args: readonly string[]) => Promise<string>;
const command: Command = async (cwd, program, args) => (await promisify(execFile)(program, [...args], { cwd, encoding: "utf8", timeout: 120_000, maxBuffer: 4_000_000 })).stdout.trim();

export async function existingPull(run: Readonly<Run>, intent: Readonly<PublishIntent>, policy: OwnerPolicy, execute: Command = command): Promise<string> {
  const repo = policy.allow(run.repo);
  const pulls = JSON.parse(await execute(run.worktree, "gh", ["pr", "list", "--repo", repo, "--head", run.branch, "--state", "all", "--json", "url,headRefOid,baseRefName,state,headRepositoryOwner"])) as Pull[];
  if (pulls.length > 1) throw new Error("Multiple pull requests for the run branch");
  const pull = pulls[0];
  if (!pull) return "";
  if (pull.headRefOid !== intent.head || pull.baseRefName !== intent.base || pull.state !== "OPEN" || pull.headRepositoryOwner.login.toLowerCase() !== repo.split("/")[0].toLowerCase() || !new RegExp(`^https://github\\.com/${repo}/pull/[1-9][0-9]*$`, "i").test(pull.url)) throw new Error("Existing pull request differs from publication intent");
  return pull.url;
}

export async function reconcilePublication(harness: Pick<Harness, "snapshot" | "commit">, run: Readonly<Run>, policy: OwnerPolicy, context: Context, execute?: Command): Promise<void> {
  if (run.route === "legacy" || active(run) || run.status === "queued" || run.url) return;
  const intent = await harness.snapshot(PublishDoc, run.conversationId, context);
  if (!intent?.head || intent.reconciled) return;
  let url = "";
  let error = "";
  try { url = await existingPull(run, intent, policy, execute); } catch { error = "lookup_failed"; }
  await harness.commit(async (tx) => {
    const stored = (await tx.doc(RunsDoc)).runs.find((row) => row.id === run.id)!;
    const document = await tx.doc(PublishDoc, run.conversationId);
    if (active(stored) || stored.status === "queued" || document.head !== intent.head) return;
    if (!stored.url) stored.url = url;
    document.reconciled = true;
    document.reconcileError = error;
  }, context);
}

export async function publishBranch(run: Readonly<Run>, intent: Readonly<PublishIntent>, policy: OwnerPolicy, execute: Command = command, update?: { url: string; previousHead: string }): Promise<string> {
  const repositoryGit = (args: readonly string[]) => execute(run.worktree, "git", args);
  const repo = policy.allow(run.repo);
  if (run.route === "legacy" || run.branch !== `feat/durable-${run.id.replaceAll("-", "")}` || await repositoryGit(["branch", "--show-current"]) !== run.branch) throw new Error("Publication requires this workflow run's branch");
  if (await repositoryGit(["status", "--porcelain"]) || await repositoryGit(["rev-parse", "HEAD"]) !== intent.head || (await change(run.worktree)).hash !== intent.sourceHash) throw new Error("Publication change differs from reviewed intent");
  const urls = (await repositoryGit(["remote", "get-url", "--push", "--all", "origin"])).split("\n");
  if (!urls.length || urls.some((url) => policy.allow(url).toLowerCase() !== repo.toLowerCase())) throw new Error("Publication remote differs from admitted repository");
  const remote = await repositoryGit(["ls-remote", "--symref", "origin", "HEAD"]);
  const base = /^ref: refs\/heads\/([^\s]+)\s+HEAD$/m.exec(remote)?.[1];
  if (!base || base !== intent.base || [base, "main", "master", "HEAD"].includes(run.branch)) throw new Error("Publication default branch changed or unresolved");
  const directory = await mkdtemp(join(tmpdir(), "etabli-pr-body-"));
  try {
    const bodyFile = join(directory, "body.md");
    await writeFile(bodyFile, intent.body, { mode: 0o600 });
    const args = ["pr", "create", "--repo", repo, "--head", run.branch, "--base", base, "--title", intent.title, "--body-file", bodyFile];
    const quote = (value: string) => `'${value.replaceAll("'", "'\\''")}'`;
    const quoted = `gh pr create --repo ${quote(repo)} --head ${quote(run.branch)} --base ${quote(base)} --title ${quote(intent.title)} --body-file ${quote(bodyFile)}`;
    const refused = prBodyGuardDecision({ cwd: run.worktree, tool_name: "bash", tool_input: { command: quoted } });
    if (refused) throw new Error(refused.hookSpecificOutput.permissionDecisionReason);
    const existing = () => existingPull(run, intent, policy, execute);
    if (update) {
      const pull = JSON.parse(await execute(run.worktree, "gh", ["pr", "view", update.url, "--repo", repo, "--json", "url,headRefOid,headRefName,baseRefName,state,headRepositoryOwner"])) as Pull;
      if (pull.url !== update.url || pull.url !== run.url || pull.headRefName !== run.branch || pull.baseRefName !== intent.base || pull.state !== "OPEN" || pull.headRepositoryOwner.login.toLowerCase() !== repo.split("/")[0].toLowerCase() || ![update.previousHead, intent.head].includes(pull.headRefOid)) throw new Error("CI pull request differs from recorded publication");
      if (pull.headRefOid === intent.head) return update.url;
    } else {
      const found = await existing();
      if (found) return found;
    }
    await execute(run.worktree, "gitleaks", ["git", "--no-banner", "--redact", "--log-opts", `${(await change(run.worktree)).base}..${intent.head}`]);
    await execute(run.worktree, "git", ["push", "origin", `${intent.head}:refs/heads/${run.branch}`]);
    if (update) {
      const updated = JSON.parse(await execute(run.worktree, "gh", ["pr", "view", update.url, "--repo", repo, "--json", "url,headRefOid,headRefName,baseRefName,state,headRepositoryOwner"])) as Pull;
      if (updated.url !== update.url || updated.headRefOid !== intent.head || updated.headRefName !== run.branch || updated.baseRefName !== intent.base || updated.state !== "OPEN" || updated.headRepositoryOwner.login.toLowerCase() !== repo.split("/")[0].toLowerCase()) throw new Error("Updated pull request could not be reconciled");
      return update.url;
    }
    try { await execute(run.worktree, "gh", args); } catch (error) { const reconciled = await existing(); if (reconciled) return reconciled; throw error; }
    const created = await existing();
    if (!created) throw new Error("Created pull request could not be reconciled");
    return created;
  } finally { await rm(directory, { recursive: true, force: true }); }
}

export function createPublishExtension(checkout: string, policy: OwnerPolicy, host: { conversation(id: ConversationId, context: Context): Promise<Conversation | undefined> }, execute: Command = command) {
  return defineExtension({ name: "etabli-publish", tools: [defineTool({
    name: "publish", description: "Publish the independently reviewed committed run branch with a contract-compliant PR body, record its URL and stop. Never merges.",
    parameters: obj({ title: str({ minLength: 1, maxLength: 200 }), body: str({ minLength: 1, maxLength: 64_000 }) }), replay: "safe",
    async execute(args, api, context) {
      const run = (await api.snapshot(RunsDoc, context))?.runs.find((run) => run.conversationId === api.conversationId);
      if (!run || run.route === "legacy") throw new Error("Publication requires a workflow run");
      if (run.status === "done" && run.url) return { output: [{ type: "text", text: run.url }], control: { terminate: true } };
      if (!active(run)) throw new Error("Run is terminal");
      const conversation = await host.conversation(api.conversationId, context);
      if (!conversation) throw new Error("Run conversation is missing");
      const authors = await authorFamilies(checkout, conversation, context);
      const source = await change(run.worktree);
      const plan = (await api.snapshot(EtabliPlanDoc, api.conversationId, context)) ?? EtabliPlanDoc.definition.initial();
      if (plan.enabled && plan.status !== "READY" || !approvedChange(plan.reviews, source.hash, planHash(plan), authors)) throw new Error("Publication requires complete independent reviews of this exact change");
      const previous = await api.snapshot(PublishDoc, api.conversationId, context);
      const intent = previous?.head ? previous : { ...args, sourceHash: source.hash, head: await git(run.worktree, ["rev-parse", "HEAD"]), base: (await git(run.worktree, ["symbolic-ref", "refs/remotes/origin/HEAD"])).replace("refs/remotes/origin/", "") };
      if (intent.title !== args.title || intent.body !== args.body || intent.sourceHash !== source.hash) throw new Error("Publication intent already belongs to different content");
      await api.commit(async (tx) => { Object.assign(await tx.doc(PublishDoc, api.conversationId), intent); const stored = (await tx.doc(RunsDoc)).runs.find((row) => row.id === run.id)!; if (!active(stored)) throw new Error("Run ended before publication"); stored.status = "publishing"; }, context);
      const ci = (await api.snapshot(CiDoc, context))?.runs.find((row) => row.runId === run.id);
      const attempt = ci?.attempts.filter((attempt) => attempt.state === "submitted").at(-1);
      const url = await publishBranch(run, intent, policy, execute, attempt && ci ? { url: ci.url, previousHead: attempt.triggerHead } : undefined);
      await api.commit(async (tx) => {
        const stored = (await tx.doc(RunsDoc)).runs.find((row) => row.id === run.id)!;
        if (!active(stored)) throw new Error("Run ended before publication completed");
        stored.url = url; stored.status = "done"; stored.reason = "published";
        const records = (await tx.doc(CiDoc)).runs;
        const record = records.find((row) => row.runId === run.id);
        if (record) { record.head = intent.head; record.url = url; record.retired = ""; record.nextPollAt = 0; record.backoff = 60_000; }
        else records.push({ runId: run.id, url, head: intent.head, originalStartedAt: stored.startedAt, nextPollAt: 0, backoff: 60_000, retired: "", attempts: [] });
      }, context);
      return { output: [{ type: "text", text: url }], control: { terminate: true } };
    },
  })] });
}
