import { fauxAssistantMessage, fauxToolCall } from "@earendil-works/pi-ai/providers/faux";
import type { TranscriptContext } from "@earendil-works/pi-ai";
import type { Command } from "../../src/publish.ts";
import { git } from "../../src/change.ts";
import { fixture } from "../helpers.ts";

export async function ciFixture(options: { now?: () => number; maxTurns?: number; wallMs?: number; notifyArgv?: string[] } = {}) {
  let pull: { url: string; headRefOid: string; headRefName: string; baseRefName: string; state: string; headRepositoryOwner: { login: string }; statusCheckRollup: unknown[] } | undefined;
  let remoteHead = "";
  let creates = 0, polls = 0, pushes = 0;
  const execute: Command = async (cwd, program, args) => {
    if (program === "git") {
      if (args[0] === "remote") return "https://github.com/Tonours/fixture.git";
      if (args[0] === "ls-remote") return "ref: refs/heads/main\tHEAD";
      if (args[0] === "push") { pushes++; remoteHead = args[2].split(":")[0]; if (pull) pull.headRefOid = remoteHead; return ""; }
      return git(cwd, args);
    }
    if (program === "gitleaks") return "";
    if (program === "gh" && args[1] === "list") return JSON.stringify(pull ? [pull] : []);
    if (program === "gh" && args[1] === "view") { polls++; if (!pull) throw new Error("not found"); return JSON.stringify(pull); }
    if (program === "gh" && args[1] === "create") {
      if (pull) throw new Error("Duplicate create");
      creates++;
      pull = { url: "https://github.com/Tonours/fixture/pull/1", headRefOid: remoteHead, headRefName: String(args[args.indexOf("--head") + 1]), baseRefName: "main", state: "OPEN", headRepositoryOwner: { login: "Tonours" }, statusCheckRollup: [{ __typename: "CheckRun", name: "fixture checks", status: "COMPLETED", conclusion: "FAILURE", detailsUrl: "https://example.invalid/check/1" }] };
      return pull.url;
    }
    throw new Error("Unexpected fixture command");
  };
  const f = await fixture({ workflow: true, publishCommand: execute, ciCommand: execute, ...options, reviewCli: async () => { throw new Error("Unexpected external review"); } });
  const respond = (input: TranscriptContext) => {
    const calls = input.messages.filter((message) => message.role === "assistant").flatMap((message) => message.content.filter((part) => part.type === "toolCall"));
    const phase = calls.length % 3;
    const number = Math.floor(calls.length / 3);
    const name = ["bash", "review", "publish"][phase];
    const args: Record<string, string> = name === "bash" ? { command: `printf '${number}' > result.txt && git add result.txt && git -c user.name=Fixture -c user.email=fixture@example.invalid commit -m 'finish ci fixture ${number}'` } : name === "review" ? { kind: "code" } : { title: "finish ci fixture", body: "## What\nAdds a fixture.\n\n## Why\nChecks CI recovery.\n\n## How to test\nRun check.sh.\n" };
    return fauxAssistantMessage(fauxToolCall(name, args), { stopReason: "toolUse" });
  };
  f.faux.setResponses(Array.from({ length: 60 }, () => respond));
  f.planner.setResponses(Array.from({ length: 80 }, () => (input: TranscriptContext) => {
    const axis = /Axis: (\w+)/.exec(JSON.stringify(input.messages))?.[1];
    const tables = axis === "logic" ? "### Lens table\n| Lens | Checked (file:line) | Found |\n| precedence | result.txt:1 | no |\n### Deciding-code table\n| Changed behavior | Deciding code opened (file:line) | Sibling / resolver | Result |\n| result | result.txt:1 | none | pass |\n" : axis === "threat" ? ["Deciding inputs", "Entry-point inventory", "Reused guards", "Deferrals", "Rollout", "Attack tests"].map((heading) => `### ${heading}\nnone: fixture\n`).join("") : "";
    return fauxAssistantMessage(`Findings\nNo findings.\n${tables}Verdict: GO\nSTATUS: complete`);
  }));
  const extras = { get pull() { return pull; }, get counts() { return { creates, polls, pushes }; }, execute };
  return Object.defineProperties(f, Object.getOwnPropertyDescriptors(extras)) as typeof f & typeof extras;
}
