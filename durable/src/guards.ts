import { resolve } from "node:path";
import { readFile } from "node:fs/promises";
import { parse } from "shell-quote";
import type { Context } from "@earendil-works/chord/context";
import { AgentDoc, ToolTask, configure, defineDoc, defineExtension, hook, section, type ConversationId, type Extension, type Tx, type ConversationRecord, type AgentChange, type HookApi } from "@earendil-works/pi-durable";
import { isReadOnlyBashCommand } from "../../workflow/runtime/read-only-bash.mjs";
import { noCommentsGuardDecision } from "../../workflow/runtime/no-comments-guard.mjs";
import { prBodyGuardDecision } from "../../workflow/runtime/pr-body-guard.mjs";
import { git, OwnerPolicy } from "./policy.ts";
import { EtabliPlanDoc } from "./plan-doc.ts";
import { active, RunsDoc } from "./runs-doc.ts";

type Decision = { hookSpecificOutput: { permissionDecisionReason: string } } | null;

function repoAt(cwd: string, policy: OwnerPolicy): string {
  for (const remote of git(cwd, ["remote"]).split("\n").filter(Boolean)) {
    for (const flag of [[], ["--push"]]) {
      for (const url of git(cwd, ["remote", "get-url", ...flag, "--all", remote]).split("\n")) policy.allow(url);
    }
  }
  return git(cwd, ["remote", "get-url", "origin"]);
}

export function remoteDefaultBranch(cwd: string, remote: string): string {
  const reference = git(cwd, ["ls-remote", "--symref", remote, "HEAD"]);
  const branch = /^ref: refs\/heads\/(.+)\tHEAD$/m.exec(reference)?.[1];
  if (!branch) throw new Error("Remote default branch unresolved");
  return branch;
}

export function invocationGuard(command: string, cwd: string, policy: OwnerPolicy, defaultBranch = remoteDefaultBranch, publicationTool = false): string | undefined {
  try {
    const shell = command.replaceAll("\\\n", "");
    if (/\b(?:git|gh)\b/.test(shell) && /`|\$\(|[<>]\(/.test(shell)) throw new Error("Command substitution is unresolved");
    const tokens = parse(shell.replaceAll("\n", " ; "), (name) => `$${name}`);
    let words: string[] = [];
    let glob = false;
    let directory: string | undefined = cwd;
    const check = () => {
      if (!words.length) return;
      const values = [...words];
      words = [];
      const expanded = glob;
      glob = false;
      let ghRepo = process.env.GH_REPO;
      let ghHost = process.env.GH_HOST;
      while (["{", "}", "!", "if", "then", "else", "elif", "do", "while", "until", "time", "exec"].includes(values[0] ?? "")) values.shift();
      for (;;) {
        while (/^[A-Za-z_][A-Za-z0-9_]*=/.test(values[0] ?? "")) {
          const assignment = values.shift()!;
          if (assignment.startsWith("GH_REPO=")) ghRepo = assignment.slice(8);
          if (assignment.startsWith("GH_HOST=")) ghHost = assignment.slice(8);
          if (assignment.startsWith("GIT_")) directory = undefined;
        }
        if (!["command", "env"].includes(values[0]?.split("/").pop() ?? "")) break;
        values.shift();
        if (values[0] === "--") values.shift();
      }
      const program = values.shift()?.split("/").pop();
      if (program === "cd") {
        if (values[0] === "--") values.shift();
        directory = directory && values.length === 1 && !/[$`~]/.test(values[0]) ? resolve(directory, values[0]) : undefined;
        return;
      }
      if (program !== "git" && program !== "gh") {
        if ((program?.startsWith("$") && /\b(?:git|gh)\b/.test(shell)) || values.some((value) => /^(?:.*\/)?(?:git|gh)$/.test(value))) throw new Error("Command wrapper is unresolved");
        return;
      }
      if (expanded || values.some((value) => /\{[^}]*(?:,|\.\.)[^}]*\}/.test(value))) throw new Error("Shell argument expansion is unresolved");
      if (!directory) throw new Error("Command directory is unresolved");
      if (program === "git") {
        let overridden = false;
        while (values[0]?.startsWith("-")) {
          const flag = values.shift()!;
          if (flag === "-C") directory = resolve(directory, values.shift() ?? "");
          else if (flag.startsWith("-C")) directory = resolve(directory, flag.slice(2));
          else {
            overridden = true;
            if (["-c", "--git-dir", "--work-tree", "--namespace"].includes(flag)) values.shift();
          }
        }
        const action = values.shift();
        if (publicationTool && action === "push") throw new Error("Use the reviewed publish tool for publication");
        if (action && !["status", "reset", "reflog", "ls-files", "cat-file", "rev-list", "for-each-ref", "symbolic-ref", "log", "diff", "show", "add", "commit", "checkout", "switch", "branch", "restore", "stash", "tag", "rm", "mv", "apply", "blame", "grep", "describe", "shortlog", "cherry-pick", "revert", "rebase", "merge", "fetch", "pull", "clone", "init", "worktree", "var", "version", "config", "remote", "rev-parse", "ls-remote", "push"].includes(action)) throw new Error("Git operation is unresolved");
        if (action === "remote" && ["add", "set-url"].includes(values[0])) {
          if (overridden || values.length !== 3 || values.some((arg) => arg.startsWith("-"))) throw new Error("Remote edit is unresolved");
          policy.allow(values[2]);
          return;
        }
        if (action === "config") {
          const key = values.findIndex((arg) => arg.startsWith("remote."));
          const reading = values.some((arg) => ["--get", "--get-all", "--get-regexp", "--get-urlmatch", "--list", "-l"].includes(arg)) || values.length === 1 && /^[^.]+\..+/.test(values[0]);
          if (values.some((arg) => ["-e", "--edit", "--unset", "--unset-all", "--remove-section", "--rename-section"].includes(arg)) || key < 0 && !reading) throw new Error("Only remote URL configuration writes are supported");
          if (key >= 0 && !reading) {
            if (overridden || !/^remote\.[^.]+\.(?:url|pushurl)$/.test(values[key]) || key !== values.length - 2) throw new Error("Remote configuration edit is unresolved");
            policy.allow(values[key + 1]);
          }
          return;
        }
        if (action !== "push") return;
        if (overridden) throw new Error("Git global overrides are unresolved");
        if (values.some((arg) => ["--all", "--mirror", "--delete", "-d", "--prune"].includes(arg) || arg.startsWith("--repo") || arg.startsWith("-o") || arg.startsWith("--receive-pack") || arg.startsWith("--exec"))) throw new Error("Ambiguous or deleting push refused");
        const arguments_ = values.filter((arg) => !["-u", "--set-upstream", "--force", "-f", "--force-with-lease", "--dry-run", "-n", "--porcelain", "--verbose", "-v"].includes(arg));
        if (arguments_.some((arg) => arg.startsWith("-"))) throw new Error("Unsupported push option");
        const remote = arguments_.shift() ?? "origin";
        let remoteUrls: string[];
        try { remoteUrls = git(directory, ["remote", "get-url", "--push", "--all", remote]).split("\n"); } catch { remoteUrls = [git(directory, ["ls-remote", "--get-url", remote])]; }
        for (const url of remoteUrls) policy.allow(url);
        const branch = defaultBranch(directory, remote);
        if (!arguments_.length) throw new Error("Name an explicit non-default destination ref");
        for (const spec of arguments_) {
          if (/[$`*?\[\]{}@]/.test(spec) || spec.startsWith(":")) throw new Error("Push refspec is unresolved or deleting");
          const parts = spec.replace(/^\+/, "").split(":");
          const destination = parts.at(-1)!.replace(/^refs\//, "").replace(/^heads\//, "");
          if (!destination || destination === branch || ["HEAD", "main", "master"].includes(destination) || parts.length > 2) throw new Error("Default-branch or unresolved push refused");
        }
        return;
      }
      if (ghHost && ghHost !== "github.com") throw new Error("GitHub host override is unresolved");
      let explicit: string | undefined;
      const args: string[] = [];
      for (let index = 0; index < values.length; index++) {
        const value = values[index];
        if (value === "--repo" || value === "-R") explicit = values[++index];
        else if (value.startsWith("--repo=")) explicit = value.slice(7);
        else if (value.startsWith("-R") && value.length > 2) explicit = value.slice(2);
        else args.push(value);
      }
      if (args.some((arg) => arg === "--hostname" || arg.startsWith("--hostname="))) throw new Error("GitHub host override is unresolved");
      if (args[0] === "pr" && args[1] === "merge") throw new Error("PR merge is forbidden");
      if (publicationTool && args[0] === "pr" && args[1] === "create") throw new Error("Use the reviewed publish tool for publication");
      if (args[0] === "api") {
        const request = args.slice(1).filter((arg, index, values) => !["-XGET", "--method=GET", "-X", "--method"].includes(arg) && !(arg === "GET" && ["-X", "--method"].includes(values[index - 1])));
        if (request.length !== 1) throw new Error("Only simple GET GitHub API calls are supported");
        const endpoint = args.find((arg) => arg.includes("repos/"));
        const target = endpoint && /^(?:https:\/\/api\.github\.com\/|\/)?repos\/([^/]+\/[^/]+)(?:\/|$)/.exec(endpoint)?.[1];
        if (!target) throw new Error("GitHub API repository is unresolved");
        policy.allow(target);
        return;
      }
      if (!["pr", "issue", "repo", "run", "workflow", "release"].includes(args[0])) throw new Error("GitHub command is not repository-bound");
      if (args[0] === "repo" && (!["clone", "view", "fork", "create"].includes(args[1]) || args.includes("--push"))) throw new Error("Repository operation is unresolved");
      for (let index = 0; index < args.length; index++) if (args[index] === "--org" || args[index].startsWith("--org=")) policy.allow(`${args[index] === "--org" ? args[index + 1] : args[index].slice(6)}/repository`);
      if (args[0] === "repo" && args[1] === "create") for (let index = 0; index < args.length; index++) {
        const template = /^(?:--template(?:=(.*))?|-c*p(.*))$/.exec(args[index]);
        if (template) {
          const attached = template[1] ?? template[2];
          policy.allow(attached === undefined || attached === "" && !args[index].includes("=") ? args[index + 1] : attached.replace(/^=/, ""));
        }
      }
      if (args[0] === "issue" && args[1] === "transfer") policy.allow(args[3]);
      const readOperations: Record<string, readonly string[]> = { release: ["view", "list", "download"], workflow: ["view", "list"], run: ["view", "list", "download", "watch"] };
      if (readOperations[args[0]] && !readOperations[args[0]].includes(args[1])) throw new Error("Only read-only repository administration is supported");
      const url = args.find((arg) => /^https:\/\/github\.com\//.test(arg));
      if (url) {
        const match = /^https:\/\/github\.com\/([^/]+\/[^/]+)/.exec(url);
        if (!match) throw new Error("Repository URL unresolved");
        policy.allow(match[1]);
      }
      const positional = args[0] === "repo" && args[1] !== "rename" && args[2] && !args[2].startsWith("-") ? args[2] : undefined;
      if (args[0] === "repo" && args.length > 2 && !positional) throw new Error("Name an explicit repository before its options");
      if (positional) policy.allow(positional);
      if (args[0] === "repo" && ["clone", "create", "delete", "archive", "unarchive", "sync"].includes(args[1]) && !explicit && !positional) throw new Error("Name an explicit repository target");
      policy.allow(explicit ?? positional ?? ghRepo ?? repoAt(directory, policy));
    };
    for (const token of tokens) {
      if (typeof token === "string") words.push(token);
      else if ("op" in token && token.op === "glob") { words.push(token.pattern); glob = true; }
      else {
        if ("comment" in token && token.comment.includes(" ; ")) throw new Error("Multiline shell comments are unresolved");
        check();
        if ("op" in token && ["(", ")", "|", "|&", "&", "||"].includes(token.op)) directory = undefined;
      }
    }
    check();
  } catch (error) {
    return `durable invocation guard: ${error instanceof Error ? error.message : "unresolved command"}`;
  }
}

export function guardedAgent(change: AgentChange, guard: Extension): AgentChange {
  if (change.extensions !== undefined) throw new Error("Guard selection is owned by the daemon");
  return { ...change, extensions: { add: [guard] } };
}

export const ChildOwnerDoc = defineDoc<{ parentId: ConversationId | null }>({
  kind: "etabli.child-owner", version: 1, scope: "conversation", history: "latest", fork: "initial",
  initial: () => ({ parentId: null }), checkpointWhen: () => true,
});

async function guardRun(api: Pick<HookApi, "snapshot">, id: ConversationId, context: Context) {
  const runs = (await api.snapshot(RunsDoc, context))?.runs ?? [];
  let current = id;
  const seen = new Set<ConversationId>();
  for (let depth = 0; depth < 16; depth++) {
    if (seen.has(current)) break;
    seen.add(current);
    const run = runs.find((row) => row.conversationId === current);
    if (run) return { run, child: current !== id, unresolved: false };
    const owner = await api.snapshot(ChildOwnerDoc, current, context);
    if (!owner) break;
    if (owner.parentId === null) return { run: undefined, child: current !== id, unresolved: current !== id };
    current = owner.parentId;
  }
  return { run: undefined, child: true, unresolved: true };
}

export async function configureGuard(tx: Tx, conversation: ConversationRecord, guard: Extension): Promise<void> {
  (await tx.doc(ChildOwnerDoc, conversation.id)).parentId = conversation.owner?.conversationId ?? null;
  const current = await tx.doc(AgentDoc, conversation.id);
  const extensions = current.extensions;
  const names = Array.isArray(extensions) ? extensions : undefined;
  if (names) {
    if (!names.includes(guard.name)) names.push(guard.name);
  } else {
    await configure(tx, conversation.id, { extensions: { add: [guard] } });
  }
}

export function createGuards(checkout: string, policy: OwnerPolicy): Extension {
  return defineExtension({
    name: "etabli-guards",
    sections: [section("etabli-contracts", async () => (await Promise.all(["agent-rules.md", "spec.md", "skills/implementation-loop.md"].map((file) => readFile(resolve(checkout, "workflow", file), "utf8")))).join("\n\n"))],
    hooks: [hook(ToolTask, {
      async beforeTool(call, api: HookApi, context) {
        const state = await api.snapshot(AgentDoc, api.conversationId, context);
        const { run, child, unresolved } = await guardRun(api, api.conversationId, context);
        if (run && (child || run.route !== "legacy") && !active(run)) return { block: "durable guard: run is terminal" };
        if (["write", "edit", "bash"].includes(call.name)) {
          if (unresolved) return { block: "durable guard: parent run is unresolved" };
          if (run) {
            const plan = await api.snapshot(EtabliPlanDoc, run.conversationId, context);
            if (plan?.enabled && plan.status !== "READY") {
              const discovery = !child && call.name === "bash" && isReadOnlyBashCommand(String(call.arguments.command ?? ""), { allowGitFetch: false });
              if (!discovery) return { block: child ? "durable guard: parent plan requires READY" : "durable guard: plan requires READY" };
            }
          }
        }
        const cwd = state?.cwd;
        if (!cwd) return { block: "durable guard: conversation directory is missing" };
        const input = call.name === "edit" && Array.isArray(call.arguments.edits)
          ? { file_path: call.arguments.path, edits: call.arguments.edits.map((edit) => ({ old_string: edit.oldText, new_string: edit.newText })) }
          : { ...call.arguments, file_path: call.arguments.path };
        const event = { cwd, tool_name: call.name, tool_input: input };
        const decision = (noCommentsGuardDecision(event) ?? prBodyGuardDecision(event)) as Decision;
        if (decision) return { block: decision.hookSpecificOutput.permissionDecisionReason };
        if (call.name === "bash") {
          const reason = invocationGuard(String(call.arguments.command ?? ""), cwd, policy, remoteDefaultBranch, !!run && (child || run.route !== "legacy"));
          if (reason) return { block: reason };
        }
      },
    })],
  });
}
