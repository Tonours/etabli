import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { prBodyGuardDecision } from "../../../workflow/runtime/pr-body-guard.mjs";
import prBody from "../pr-body.ts";

type Handler = (event: Record<string, unknown>, ctx: { cwd: string }) => unknown;

const root = resolve(import.meta.dir, "../../..");
const GOOD = "Cap refresh retries per session.\n\n## What\n- `src/a.ts`: one retry\n\n## Why\n- loops\n\n## How to test\n- `bun test`: 12 pass\n";
let repo = "";

beforeEach(() => {
	repo = mkdtempSync(join(tmpdir(), "etabli-pr-body-"));
	mkdirSync(join(repo, ".git"));
});

afterEach(() => {
	rmSync(repo, { recursive: true, force: true });
});

function decide(command: string, cwd = repo) {
	return prBodyGuardDecision({ cwd, tool_name: "Bash", tool_input: { command } });
}

function reason(command: string) {
	return decide(command)?.hookSpecificOutput.permissionDecisionReason ?? "";
}

function bodyFile(text: string, name = "body.md") {
	writeFileSync(join(repo, name), text);
	return name;
}

describe("pr body guard", () => {
	test("passes a contract body from a relative or absolute body file", () => {
		const file = bodyFile(GOOD);
		expect(decide(`gh pr create --title "fix: x" --body-file ${file}`)).toBeNull();
		expect(decide(`gh pr create -F '${join(repo, file)}' --draft`)).toBeNull();
		expect(decide(`gh pr edit 12 --body-file=${file}`)).toBeNull();
	});

	test("passes an inline heredoc body and a literal newline body", () => {
		expect(decide(`gh pr create --title "fix: x" --body "$(cat <<'EOF'\n${GOOD}EOF\n)"`)).toBeNull();
		expect(decide(`gh pr create --body-file - <<'EOF'\n${GOOD}EOF`)).toBeNull();
		expect(decide(`gh pr create -t x -b $'Line\\n\\n## What\\nx\\n## Why\\ny\\n## How to test\\nz'`)).toBeNull();
	});

	test("names each missing heading and the skill", () => {
		const file = bodyFile("## What changed\n- x\n\n## Validation\n- y\n");
		const text = reason(`gh pr create --body-file ${file}`);
		expect(text).toContain("missing ## What, ## Why, ## How to test");
		expect(text).toContain("`pr` skill");
	});

	test("refuses a create without a body and a missing body file", () => {
		expect(reason("gh pr create --fill")).toContain("no body given");
		expect(reason("gh pr new --web")).toContain("no body given");
		expect(reason("cd x && rtk gh pr create --title y")).toContain("no body given");
		expect(reason("gh pr create --body-file nope.md")).toContain("body file nope.md not found");
	});

	test("refuses AI attribution and non-ASCII prose but not in code, tables or quotes", () => {
		expect(reason(`gh pr create --body-file ${bodyFile(`${GOOD}\nGenerated with Claude Code\n`)}`)).toContain("AI attribution");
		expect(reason(`gh pr create --body-file ${bodyFile(GOOD.replace("loops", "loops — forever"))}`)).toContain("non-ASCII");
		const fenced = `${GOOD}\n\`\`\`\na → b\n\`\`\`\n| x | y → z |\n> quoted — output\n- \`a→b\` inline\n`;
		expect(decide(`gh pr create --body-file ${bodyFile(fenced)}`)).toBeNull();
	});

	test("ignores other commands, edits without a body and quoted mentions", () => {
		expect(decide("gh pr view 12 --json body")).toBeNull();
		expect(decide("gh pr edit 12 --add-label bug")).toBeNull();
		expect(decide(`rg -n "gh pr create" docs`)).toBeNull();
		expect(prBodyGuardDecision({ cwd: repo, tool_name: "Write", tool_input: { command: "gh pr create" } })).toBeNull();
	});

	test("requires the repo template headings on top of ours", () => {
		mkdirSync(join(repo, ".github"));
		writeFileSync(join(repo, ".github/PULL_REQUEST_TEMPLATE.md"), "<!-- ## Hidden -->\n## :evergreen_tree: Description\n\n## Security\n- [ ] ok\n");
		expect(reason(`gh pr create --body-file ${bodyFile(GOOD)}`)).toContain("missing ## :evergreen_tree: Description, ## Security");
		const filled = `## :evergreen_tree: Description\n${GOOD}\n## Security\n- [ ] ok\n`;
		expect(decide(`gh pr create --body-file ${bodyFile(filled)}`)).toBeNull();
	});

	test("lets a template that asks what changed and how it was verified stand in for ours", () => {
		writeFileSync(join(repo, "pull_request_template.md"), "## What changed\n\n## Verification\n");
		expect(decide(`gh pr create --body-file ${bodyFile("x\n## What changed\n- a\n## Verification\n- b\n")}`)).toBeNull();
		expect(reason(`gh pr create --body-file ${bodyFile(GOOD)}`)).toContain("missing ## What changed, ## Verification");
	});

	test("keeps our headings when the template has only one of the two", () => {
		writeFileSync(join(repo, "pull_request_template.md"), "## What changed\n");
		expect(reason(`gh pr create --body-file ${bodyFile("## What changed\n- a\n")}`)).toContain("missing ## What, ## Why, ## How to test");
	});

	test("finds the template from a subdirectory and reads a body file under ~", () => {
		writeFileSync(join(repo, "pull_request_template.md"), "## Security\n");
		mkdirSync(join(repo, "src"));
		const sub = join(repo, "src");
		expect(decide(`gh pr create --body-file ${join(repo, bodyFile(GOOD))}`, sub)?.hookSpecificOutput.permissionDecisionReason).toContain("missing ## Security");
		const home = process.env.HOME;
		process.env.HOME = repo;
		try {
			expect(decide(`gh pr create --body-file ~/${bodyFile(`${GOOD}## Security\n`)}`, sub)).toBeNull();
		} finally {
			process.env.HOME = home;
		}
	});
});

describe("pr body runtimes", () => {
	test("the Pi extension blocks with the guard reason", () => {
		const handlers: Handler[] = [];
		prBody({ on: (_name: string, handler: Handler) => handlers.push(handler) } as unknown as Parameters<typeof prBody>[0]);
		const [blocked] = handlers.map((h) => h({ toolName: "bash", input: { command: "gh pr create --fill" } }, { cwd: repo }));
		expect(blocked).toMatchObject({ block: true });
		expect(String((blocked as { reason: string }).reason)).toContain("no body given");
		const [passed] = handlers.map((h) => h({ toolName: "bash", input: { command: "ls" } }, { cwd: repo }));
		expect(passed).toBeUndefined();
	});

	test("the Claude hook denies, passes, and fails open on bad input", () => {
		const hook = join(root, "claude/hooks/pr-body-guard.mjs");
		const run = (input: string) => spawnSync("node", [hook], { input, encoding: "utf8" });
		const denied = run(JSON.stringify({ cwd: repo, tool_name: "Bash", tool_input: { command: "gh pr create --fill" } }));
		expect(denied.status).toBe(0);
		expect(JSON.parse(denied.stdout).hookSpecificOutput.permissionDecision).toBe("deny");
		expect(run(JSON.stringify({ cwd: repo, tool_name: "Bash", tool_input: { command: "ls" } })).stdout).toBe("");
		const broken = run("{not json");
		expect(broken.status).toBe(0);
		expect(broken.stdout).toBe("");
	});
});
