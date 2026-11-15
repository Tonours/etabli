import { readFile, writeFile, stat, appendFile } from "node:fs/promises";
import { join } from "node:path";
import { createModels, type TranscriptContext } from "@earendil-works/pi-ai";
import { fauxProvider, fauxAssistantMessage, fauxToolCall } from "@earendil-works/pi-ai/providers/faux";
import { openCore, serve } from "../../src/daemon.ts";
import { OwnerPolicy } from "../../src/policy.ts";
import { Repositories } from "../../src/repositories.ts";
import { git } from "../../src/change.ts";

const [root, source, notifyCut = "after_notify"] = process.argv.slice(2);
const state = join(root, "state");
const policy = new OwnerPolicy(["ForeignOrg"]);
const barrier = async (stage: string) => {
  if (await stat(join(root, `released-${stage}`)).then(() => true, () => false)) return;
  await writeFile(join(root, "phase"), `${stage}:${process.pid}`);
  while (!await stat(join(root, `released-${stage}`)).then(() => true, () => false)) await new Promise((resolve) => setTimeout(resolve, 10));
};
const implementer = fauxProvider({ provider: "zai", models: [{ id: "glm-5.3" }] });
const reviewer = fauxProvider({ provider: "openai-codex", models: [{ id: "gpt-6.1-sol" }, { id: "gpt-6-astra" }] });
const respond = (input: TranscriptContext) => {
  const calls = input.messages.filter((message) => message.role === "assistant").flatMap((message) => message.content.filter((part) => part.type === "toolCall"));
  const name = calls.length === 0 ? "bash" : calls.some((call) => call.name === "review") ? "publish" : "review";
  const args: Record<string, string> = name === "bash" ? { command: "printf finished > result.txt && git add result.txt && git -c user.name=Fixture -c user.email=fixture@example.invalid commit -m 'finish crash fixture'" } : name === "review" ? { kind: "code" } : { title: "finish crash fixture", body: "## What\nAdds a fixture.\n\n## Why\nChecks crash recovery.\n\n## How to test\nRun check.sh.\n" };
  return fauxAssistantMessage(fauxToolCall(name, args), { stopReason: "toolUse" });
};
implementer.setResponses(Array.from({ length: 30 }, () => respond));
reviewer.setResponses(Array.from({ length: 30 }, () => (input: TranscriptContext) => {
  const axis = /Axis: (\w+)/.exec(JSON.stringify(input.messages))?.[1];
  const tables = axis === "logic" ? "### Lens table\n| Lens | Checked (file:line) | Found |\n| precedence | result.txt:1 | no |\n### Deciding-code table\n| Changed behavior | Deciding code opened (file:line) | Sibling / resolver | Result |\n| result | result.txt:1 | none | pass |\n" : axis === "threat" ? ["Deciding inputs", "Entry-point inventory", "Reused guards", "Deferrals", "Rollout", "Attack tests"].map((heading) => `### ${heading}\nnone: fixture\n`).join("") : "";
  return fauxAssistantMessage(`Findings\nNo findings.\n${tables}Verdict: GO\nSTATUS: complete`);
}));
const models = createModels();
models.setProvider(implementer.provider); models.setProvider(reviewer.provider);
const notifyCode = `const fs=require('node:fs');const path=require('node:path');const root=process.argv[1],stage=process.argv[2],daemon=process.argv[3];fs.appendFileSync(path.join(root,'notify-called'),JSON.stringify(process.argv.slice(4))+'\\n');const finish=()=>{fs.appendFileSync(path.join(root,'notify-effects'),'once\\n');};if(stage==='after_notify')finish();if(!fs.existsSync(path.join(root,'released-'+stage))){fs.writeFileSync(path.join(root,'phase'),stage+':'+daemon+':'+process.pid);const t=setInterval(()=>{if(fs.existsSync(path.join(root,'released-'+stage))){clearInterval(t);if(stage==='before_notify')finish();}},10);}else if(stage==='before_notify')finish();`;
const core = await openCore({ state, policy, models, workflow: true, model: async () => ({ provider: "zai", modelId: "glm-5.3" }), repositories: new Repositories(state, policy, () => source, async (repo) => repo), restartLimit: 12,
  notifyArgv: [process.execPath, "-e", notifyCode, root, notifyCut, String(process.pid)],
  publishCommand: async (cwd, program, args) => {
    if (program === "git") {
      if (args[0] === "remote") return "https://github.com/Tonours/fixture.git";
      if (args[0] === "ls-remote") return "ref: refs/heads/main\tHEAD";
      if (args[0] === "push") { await barrier("before_push"); await appendFile(join(root, "push-effects"), `${args[2]}\n`); await barrier("after_push"); return ""; }
      return git(cwd, args);
    }
    if (program === "gitleaks") return "";
    if (program === "gh" && args[1] === "list") {
      const pull = await readFile(join(root, "pull.json"), "utf8").catch(() => "");
      if (pull) await barrier("before_store");
      return pull ? `[${pull}]` : "[]";
    }
    if (program === "gh" && args[1] === "create") {
      await barrier("before_create");
      if (await stat(join(root, "pull.json")).then(() => true, () => false)) throw new Error("Duplicate create");
      const pull = { url: "https://github.com/Tonours/fixture/pull/1", headRefOid: await git(cwd, ["rev-parse", "HEAD"]), baseRefName: "main", state: "OPEN", headRepositoryOwner: { login: "Tonours" } };
      await writeFile(join(root, "pull.json"), JSON.stringify(pull));
      await appendFile(join(root, "create-effects"), "once\n");
      await barrier("after_create");
      return pull.url;
    }
    throw new Error("Unexpected publication command");
  },
});
await serve(core, state);
await writeFile(join(root, "ready"), String(process.pid));
let ticking = false;
setInterval(() => { if (ticking) return; ticking = true; void core.runs.tick().catch(() => process.exit(1)).finally(() => { ticking = false; }); }, 20);
