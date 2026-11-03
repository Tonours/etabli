import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { prBodyGuardDecision, scanShell, staticWord } from "../../../workflow/runtime/pr-body-guard.mjs";
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

describe("pr body guard, shell and markdown edges", () => {
	test("refuses a special file as body instead of reading it", () => {
		expect(reason("gh pr create --body-file /dev/stdin")).toContain("not a regular file");
	});

	test("ignores mentions inside quotes, heredocs and comments", () => {
		expect(decide("printf '%s\\n' 'usage: start; gh pr create --fill'")).toBeNull();
		expect(decide(`gh pr view 12 --jq '.body | split("; gh pr create")'`)).toBeNull();
		expect(decide("cat <<'EOF' > notes.md\nrun: gh pr create --fill\nEOF")).toBeNull();
		expect(decide("ls # then gh pr create --fill")).toBeNull();
	});

	test("checks every invocation on the line", () => {
		expect(reason("gh pr edit 12 --add-label bug; gh pr create --fill")).toContain("gh pr create: no body given");
	});

	test("reads only the body value, not the rest of the command", () => {
		expect(decide("gh pr edit 12 --title 'fix: document --body argument'")).toBeNull();
		expect(reason("gh pr create --body bad; printf '\\n## What\\nx\\n## Why\\ny\\n## How to test\\nz\\n'")).toContain("missing ## What");
	});

	test("decodes ANSI-C bodies and keeps single-quoted backslash-n literal", () => {
		expect(reason("gh pr create -b $'Change.\\n## What\\nx\\n## Why\\n\\303\\251\\n## How to test\\nz\\n'")).toContain("non-ASCII");
		expect(reason("gh pr create -b 'Change.\\n## What\\nx\\n## Why\\ny\\n## How to test\\nz'")).toContain("missing ## What");
		expect(reason('gh pr create --body "$BODY"')).toContain("body value is built at run time");
		expect(reason("cat b.md | gh pr create -F -")).toContain("pipe");
	});

	test("sees global flags and wrappers", () => {
		expect(reason("gh --repo Tonours/etabli pr create --body bad")).toContain("missing ## What");
		expect(reason("command gh pr create --body bad")).toContain("missing ## What");
		expect(reason("url=$(gh -R o/r pr new --fill)")).toContain("no body given");
	});

	test("follows a cd for the body file and the template", () => {
		const other = mkdtempSync(join(tmpdir(), "etabli-pr-body-other-"));
		try {
			mkdirSync(join(other, ".git"));
			writeFileSync(join(other, "body.md"), GOOD);
			expect(decide(`cd ${other} && gh pr create --body-file body.md`, "/")).toBeNull();
			writeFileSync(join(other, "PULL_REQUEST_TEMPLATE.md"), "### Security\n");
			expect(reason(`cd '${other}' && gh pr create --body-file body.md`)).toContain("missing ### Security");
		} finally {
			rmSync(other, { recursive: true, force: true });
		}
	});

	test("lets help through", () => {
		expect(decide("gh pr create --help")).toBeNull();
		expect(decide("gh pr edit -h")).toBeNull();
	});

	test("does not count headings hidden in comments or code", () => {
		const hidden = "Intro\n<!--\n## What\n## Why\n## How to test\n-->\n```\n## What\n```\n";
		expect(reason(`gh pr create --body-file ${bodyFile(hidden)}`)).toContain("missing ## What, ## Why, ## How to test");
	});

	test("closes a fence only with a matching marker", () => {
		const nested = `${GOOD}\n\`\`\`\`md\n\`\`\`\n\u00e9\n\`\`\`\`\n`;
		expect(decide(`gh pr create --body-file ${bodyFile(nested)}`)).toBeNull();
	});
});

describe("shell scanner", () => {
	test("hides quoted text, comments and escapes but keeps code and substitutions", () => {
		expect(scanShell("a 'b c' d").visible).toBe("a '___' d");
		expect(scanShell("a $'b\\'c' d").visible).toBe("a $'____' d");
		expect(scanShell('a "b $(c) d" e').visible).toBe('a "_________ e');
		expect(scanShell("a $(b) c").visible).toBe("a $(b) c");
		expect(scanShell("a \\; b").visible).toBe("a __ b");
		expect(scanShell("a # b\nc").visible).toBe("a ___\nc");
		expect(scanShell("a#b").visible).toBe("a#b");
		expect(scanShell("(echo) # x").visible).toBe("(echo) ___");
	});

	test("records heredoc bodies and hides them", () => {
		const one = scanShell("cat <<'EOF' | x\nbody; y\nEOF\nz");
		expect(one.visible).toBe("cat <<'EOF' | x\n___________\nz");
		expect(one.heredocs).toEqual([{ at: 4, body: "body; y\n", quoted: true }]);
		const tabs = scanShell("cat <<-EOF\n\tb\n\tEOF\nz");
		expect(tabs.heredocs[0].body).toBe("\tb\n");
		expect(tabs.visible.endsWith("\nz")).toBe(true);
		const two = scanShell("x <<A <<B\n1\nA\n2\nB\ny");
		expect(two.heredocs.map((doc) => doc.body)).toEqual(["1\n", "2\n"]);
		expect(two.visible.endsWith("\ny")).toBe(true);
		const open = scanShell("cat <<EOF\nno end");
		expect(open.heredocs[0].body).toBe("no end");
		const nested = scanShell(`x "$(cat <<'EOF'\nsay "hi"\nEOF\n)" ; gh`);
		expect(nested.heredocs[0].body).toBe('say "hi"\n');
		expect(nested.visible.endsWith(" ; gh")).toBe(true);
	});

	test("reads static words and refuses dynamic ones", () => {
		expect(staticWord(`a'b c'"d\\"e"\\ f`)).toBe('ab cd"e f');
		expect(staticWord("$'a\\tb\\x41\\u00e9\\101\\q'")).toBe("a\tbA\u00e9A\\q");
		expect(staticWord('"a$b"')).toBeNull();
		expect(staticWord("a`b`")).toBeNull();
		expect(staticWord("'open")).toBeNull();
		expect(staticWord('"open')).toBeNull();
		expect(staticWord("$'open")).toBeNull();
	});
});

describe("pr body guard, round 2 edges", () => {
	test("tells here-strings and shifts from heredocs", () => {
		expect(reason("cat <<< 'hello'\ngh pr create --body bad")).toContain("missing ## What");
		expect(reason("echo $((1 << 2))\ngh pr create --body bad")).toContain("missing ## What");
	});

	test("follows line continuations", () => {
		expect(reason("gh \\\n  pr create --body bad")).toContain("missing ## What");
		expect(decide(`gh pr create --body-file \\\n  ${bodyFile(GOOD)}`)).toBeNull();
	});

	test("reads values attached to short options", () => {
		expect(reason("gh pr edit 12 -bbad")).toContain("missing ## What");
		expect(decide(`gh pr edit 12 -F${bodyFile(GOOD)}`)).toBeNull();
		expect(reason("gh -RTonours/etabli pr create --body bad")).toContain("missing ## What");
		expect(reason("env GH_HOST=github.com gh pr create --body bad")).toContain("missing ## What");
	});

	test("survives unicode escapes", () => {
		expect(reason("gh pr create --body $'\\u2014before'; gh pr create --body bad")).toContain("non-ASCII");
		expect(staticWord("$'\\U110000'")).toBe("\ufffd");
	});

	test("scopes cd to its separator and subshell", () => {
		const file = bodyFile(GOOD);
		expect(decide(`cd .; gh pr create -F ${file}`)).toBeNull();
		expect(reason(`(cd /tmp && pwd); gh pr create -F ${file}`)).toBe("");
	});

	test("skips indented code and comments only outside fences", () => {
		expect(reason("gh pr create -b 'Example:\n\n    ## What\n    ## Why\n    ## How to test\n'")).toContain("missing ## What");
		expect(reason("gh pr create -b $'Example:\\n\\n    ## What\\n    ## Why\\n    ## How to test\\n'")).toContain("missing ## What");
		expect(decide(`gh pr create --body-file ${bodyFile(`${GOOD}\nExample:\n\n    a \u2192 b\n`)}`)).toBeNull();
		const fenced = "Change.\n\n## What\n```html\n<!--\n```\n\n## Why\ny\n## How to test\nz\n";
		expect(decide(`gh pr create --body-file ${bodyFile(fenced)}`)).toBeNull();
	});

	test("refuses an unquoted heredoc that expands and reads a backslash delimiter", () => {
		expect(reason(`BAD=x; gh pr create -F - <<EOF\n${GOOD}$BAD\nEOF`)).toContain("unquoted heredoc");
		expect(reason(`gh pr create -F - <<EOF\n${GOOD}EOF`)).toContain("unquoted heredoc");
		expect(decide(`gh pr create -F - <<EOF\n${GOOD.replaceAll("`", "")}EOF`)).toBeNull();
		expect(decide("cat <<\\EOF\nthen gh pr create --fill\nEOF")).toBeNull();
	});
});

describe("pr body guard, mutation gaps", () => {
	test("keeps scanning after a dollar or paren inside double quotes", () => {
		expect(reason('echo "a $b (c)"; gh pr create --fill')).toContain("no body given");
	});

	test("keeps hiding quotes after a heredoc", () => {
		expect(decide("cat <<'EOF'\nx\nEOF\necho 'gh pr create --fill'")).toBeNull();
	});

	test("refuses a cd it cannot resolve", () => {
		const file = bodyFile(GOOD);
		expect(reason(`cd - && gh pr create -F ${file}`)).toContain("cannot be resolved");
		expect(reason(`cd "$DIR" && gh pr create -F ${file}`)).toContain("cannot be resolved");
	});

	test("takes the heredoc of its own invocation", () => {
		expect(decide(`cat <<'A' > notes\nbad\nA\ngh pr create -F - <<'B'\n${GOOD}B`)).toBeNull();
		expect(reason(`cat <<'A' > notes\n${GOOD}A\ngh pr create -F - <<'B'\nbad\nB`)).toContain("missing ## What");
	});

	test("ends a double-quoted word on its closing quote after an escape", () => {
		expect(staticWord('"a\\""')).toBe('a"');
	});

	test("reads lines again after a closed multi-line comment", () => {
		expect(decide(`gh pr create --body-file ${bodyFile(`<!--\nnote\n-->\n${GOOD}`)}`)).toBeNull();
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
