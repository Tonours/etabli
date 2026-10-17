import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
	addedCommentLines,
	collectCommentLines,
	commentFamilyFor,
	isGuardedCodeFile,
	noCommentsGuardDecision,
} from "../../../workflow/runtime/no-comments-guard.mjs";
import noComments from "../no-comments.ts";

type Handler = (event: Record<string, unknown>) => unknown;

let fixtureCwd = "";

beforeEach(() => {
	fixtureCwd = mkdtempSync(join(tmpdir(), "etabli-no-comments-fixture-"));
});

afterEach(() => {
	rmSync(fixtureCwd, { recursive: true, force: true });
});

function guardDecision(event: Parameters<typeof noCommentsGuardDecision>[0]) {
	return noCommentsGuardDecision({ cwd: fixtureCwd, ...event });
}

function setupExtension() {
	const handlers = new Map<string, Handler[]>();
	const pi = {
		on(eventName: string, handler: Handler) {
			handlers.set(eventName, [...(handlers.get(eventName) ?? []), handler]);
		},
	};
	noComments(pi as unknown as Parameters<typeof noComments>[0]);
	return {
		emit(eventName: string, event: Record<string, unknown>) {
			return (handlers.get(eventName) ?? []).map((handler) => handler({ cwd: fixtureCwd, ...event }));
		},
	};
}

describe("no-comments detector", () => {
	test("guards code files and skips docs/json", () => {
		expect(isGuardedCodeFile("src/x.ts")).toBe(true);
		expect(isGuardedCodeFile("src/x.py")).toBe(true);
		expect(isGuardedCodeFile("PLAN.md")).toBe(false);
		expect(isGuardedCodeFile("notes.md")).toBe(false);
		expect(isGuardedCodeFile("pkg.json")).toBe(false);
		expect(commentFamilyFor("a.ts")).toBe("clike");
		expect(commentFamilyFor("a.py")).toBe("python");
		expect(commentFamilyFor("a.sql")).toBe("sql");
	});

	test("ignores comments inside strings and urls", () => {
		const source = [
			'const url = "https://example.com/path//docs";',
			"const hash = 'not # a comment';",
			"const tmpl = `keep // inside`;",
			"export const n = 1;",
		].join("\n");
		expect(collectCommentLines(source, "clike")).toEqual([]);
	});

	test("exempts shebang, SPDX, and copyright headers", () => {
		const source = [
			"#!/usr/bin/env node",
			"// SPDX-License-Identifier: MIT",
			"// Copyright 2026 Anthony Guimard",
			"export const ok = true;",
		].join("\n");
		expect(collectCommentLines(source, "clike")).toEqual([]);
		expect(collectCommentLines("#!/usr/bin/env bash\necho hi\n", "shell")).toEqual(
			[],
		);
	});

	test("detects added line and block comments", () => {
		expect(
			addedCommentLines(
				"export const n = 1;\n",
				"export const n = 1; // increment later\n",
				"clike",
			),
		).toEqual(["// increment later"]);
		expect(
			addedCommentLines(
				"export const n = 1;\n",
				"/* helper */\nexport const n = 1;\n",
				"clike",
			),
		).toEqual(["/* helper */"]);
	});

	test("preserves comments already present", () => {
		const previous = "export const n = 1; // keep\n";
		const next = "export const n = 2; // keep\n";
		expect(addedCommentLines(previous, next, "clike")).toEqual([]);
	});

	test("detects french restating comments", () => {
		expect(
			addedCommentLines(
				"function add(a, b) {\n  return a + b;\n}\n",
				"function add(a, b) {\n  // additionne a et b\n  return a + b;\n}\n",
				"clike",
			),
		).toEqual(["// additionne a et b"]);
	});
});

describe("noCommentsGuardDecision", () => {
	test("allows bash and non-code files", () => {
		expect(
			guardDecision({
				tool_name: "Bash",
				tool_input: { command: "echo // not a file comment" },
			}),
		).toBeNull();
		expect(
			guardDecision({
				tool_name: "Write",
				tool_input: { file_path: "PLAN.md", content: "# PLAN\n// ignored\n" },
			}),
		).toBeNull();
		expect(
			guardDecision({
				tool_name: "Write",
				tool_input: { path: "README.md", content: "Note: // docs\n" },
			}),
		).toBeNull();
	});

	test("denies Write that adds a comment on a new code file", () => {
		const decision = guardDecision({
			tool_name: "write",
			tool_input: {
				path: "src/new.ts",
				content: "export const n = 1; // leftover\n",
			},
		});
		expect(decision?.hookSpecificOutput?.permissionDecision).toBe("deny");
		expect(decision?.hookSpecificOutput?.permissionDecisionReason).toMatch(
			/no-comments: src\/new\.ts/,
		);
		expect(decision?.hookSpecificOutput?.permissionDecisionReason).toMatch(
			/implementation-loop 12b/,
		);
	});

	test("allows Write that only preserves existing comments", () => {
		const cwd = mkdtempSync(join(tmpdir(), "etabli-no-comments-write-"));
		try {
			mkdirSync(join(cwd, "src"));
			writeFileSync(join(cwd, "src", "keep.ts"), "export const n = 1; // keep\n");
			expect(
				guardDecision({
					cwd,
					tool_name: "Write",
					tool_input: {
						file_path: join(cwd, "src", "keep.ts"),
						content: "export const n = 2; // keep\n",
					},
				}),
			).toBeNull();
		} finally {
			rmSync(cwd, { recursive: true, force: true });
		}
	});

	test("denies Edit and MultiEdit that introduce comments", () => {
		const edit = guardDecision({
			toolName: "edit",
			input: {
				path: "lib/x.ts",
				old_string: "export const n = 1;",
				new_string: "export const n = 1; // why",
			},
		});
		expect(edit?.hookSpecificOutput?.permissionDecision).toBe("deny");

		const multi = guardDecision({
			tool_name: "MultiEdit",
			tool_input: {
				file_path: "lib/x.ts",
				edits: [
					{
						oldText: "export const n = 1;",
						newText: "/* n is one */\nexport const n = 1;",
					},
				],
			},
		});
		expect(multi?.hookSpecificOutput?.permissionDecision).toBe("deny");
	});

	test("allows comment-free Write and Edit", () => {
		expect(
			guardDecision({
				tool_name: "Write",
				tool_input: {
					file_path: "src/ok.ts",
					content: "export const n = 1;\n",
				},
			}),
		).toBeNull();
		expect(
			guardDecision({
				tool_name: "Edit",
				tool_input: {
					file_path: "src/ok.ts",
					old_string: "export const n = 1;",
					new_string: "export const n = 2;",
				},
			}),
		).toBeNull();
	});
});

describe("unified Claude verdicts", () => {
	const decide = (event: Parameters<typeof noCommentsGuardDecision>[0]) => (guardDecision(event) ? "deny" : "allow");
	const write = (path: string, content: string) => ({ tool_name: "write", tool_input: { path, content } });

	test("allows tool directives and comment-like syntax", () => {
		expect(decide(write("a.sh", "n=${#arr[@]}\n"))).toBe("allow");
		expect(decide(write("a.scss", ".a { background: url(http://example.test/x.png); }\n"))).toBe("allow");
		expect(decide(write("a.js", 'const p = s.replace(/\\/*$/, "");\n'))).toBe("allow");
		expect(decide(write("b.ts", "// @ts-expect-error legacy\nconst x: number = 'a';\n"))).toBe("allow");
		expect(decide(write("c.ts", "// eslint-disable-next-line no-console\nconsole.log(1);\n"))).toBe("allow");
	});

	test("denies astro comments, JSDoc continuations and duplicated comments", () => {
		writeFileSync(join(fixtureCwd, "doc.ts"), "/**\n * Existing doc.\n */\nexport const a = 1;\n");
		expect(decide(write("e.astro", "---\n// note\n---\n"))).toBe("deny");
		expect(
			decide({ tool_name: "edit", tool_input: { path: "doc.ts", oldText: " * Existing doc.\n", newText: " * Existing doc.\n * new line\n" } }),
		).toBe("deny");
		expect(
			decide({ tool_name: "edit", tool_input: { path: "doc.ts", oldText: "export const a = 1;", newText: "export const a = 1;\n/**\n * Existing doc.\n */" } }),
		).toBe("deny");
		expect(
			decide({ tool_name: "edit", tool_input: { path: "doc.ts", oldText: "export const a = 1;", newText: "export const a = 2;" } }),
		).toBe("allow");
	});

	test("lexes strings, comments and regexes per language", () => {
		expect(collectCommentLines('const x = "(/)"; // added note\n', "clike")).toEqual(["// added note"]);
		expect(collectCommentLines("const s = `a\n// not a comment\nb`;\n", "clike")).toEqual([]);
		expect(collectCommentLines('s = """first\n# data\nlast"""\n', "python")).toEqual([]);
		expect(collectCommentLines("x = 1# added note\n", "python")).toEqual(["# added note"]);
		expect(collectCommentLines("data='first\n# data\nlast'\n", "shell")).toEqual([]);
		expect(collectCommentLines("n=${#arr[@]}\necho $#\n", "shell")).toEqual([]);
		expect(commentFamilyFor("a.sh")).toBe("shell");
		expect(collectCommentLines('s = "first\n# data\nlast"\n', "ruby")).toEqual([]);
		expect(collectCommentLines("s = ''''\n# added note\n", "ruby")).toEqual(["# added note"]);
		expect(collectCommentLines("SELECT 'first\n-- data\nlast';\n", "sql")).toEqual([]);
		expect(collectCommentLines("echo $'it\\'s'\n# added note\n", "shell")).toEqual(["# added note"]);
		expect(collectCommentLines('x="$(\n  printf hi # added note\n)"\necho "$x"\n', "shell")).toEqual(["# added note"]);
		expect(collectCommentLines("SELECT E'it\\'s';\n-- added note\n", "sql")).toEqual(["-- added note"]);
		expect(collectCommentLines("pattern = /don't/\n# added note\n", "ruby")).toEqual(["# added note"]);
		expect(collectCommentLines('m="$(grep -o \\( "$f")\n# data"\n', "shell")).toEqual([]);
		expect(collectCommentLines("t=\"$(cat <<'TEXT'\n# Heading\nTEXT\n)\"\n# added note\n", "shell")).toEqual(["# added note"]);
		expect(collectCommentLines("cat <<EOF\n$(\n  printf hi # added note\n)\nEOF\n", "shell")).toEqual(["# added note"]);
		expect(collectCommentLines("cat <<EOF.json\n{}\nEOF.json\n# added note\ncat <<EOF\nx\nEOF\n", "shell")).toEqual(["# added note"]);
		expect(collectCommentLines("r = values.reduce(:/) # added / note\n", "ruby")).toEqual(["# added / note"]);
		expect(collectCommentLines('SELECT e"path\\" FROM src; -- added note\n', "sql")).toEqual(["-- added note"]);
		expect(collectCommentLines("cat <<EOF\nDon't panic\n# Heading\nEOF\n# added note\n", "shell")).toEqual(["# added note"]);
		expect(collectCommentLines("rules = {pattern:/don't/}\n# added note\n", "ruby")).toEqual(["# added note"]);
		expect(collectCommentLines("cat <<EOF\n$(case \"$m\" in\n  prod) printf p # added note\n    ;;\nesac)\nEOF\n", "shell")).toEqual(["# added note"]);
		expect(collectCommentLines("cat <<EOF\n`printf hi # added note\n`\nEOF\n", "shell")).toEqual(["# added note"]);
		expect(collectCommentLines('r="$(cat test-case.json)"\n# added note\n', "shell")).toEqual(["# added note"]);
		expect(collectCommentLines('r="$({ case "$m" in\n  prod) printf p # added note\n  ;;\nesac; })"\n', "shell")).toEqual(["# added note"]);
		expect(collectCommentLines('r="$(case "$m" in\n  prod) printf p;;\nesac>/dev/null)"\n# added note\n', "shell")).toEqual(["# added note"]);
		expect(collectCommentLines('v="$((case>0))"\n# added note\n', "shell")).toEqual(["# added note"]);
		expect(collectCommentLines('r="$(( $(case "$m" in\n  prod) printf 1;;\n  staging) printf 2;;\n  *) printf 3 # added note\n  ;;\nesac) + 1 ))"\n', "shell")).toEqual(["# added note"]);
	});

	test("replace_all edits are judged on every occurrence", () => {
		writeFileSync(join(fixtureCwd, "r.ts"), 'const label = "run";\nrun();\n');
		expect(
			decide({ tool_name: "edit", tool_input: { path: "r.ts", old_string: "run", new_string: "run/* added note */", replace_all: true } }),
		).toBe("deny");
	});

	test("an apostrophe in a comment does not hide later comments", () => {
		writeFileSync(join(fixtureCwd, "apos.ts"), "const x = 1; // don't\nconst y = 2;\n");
		expect(
			decide({ tool_name: "edit", tool_input: { path: "apos.ts", oldText: "const y = 2;", newText: "const y = 2;\n// brand new note" } }),
		).toBe("deny");
	});
});

describe("no-comments extension", () => {
	test("blocks write/edit that add comments and lets bash through", () => {
		const runtime = setupExtension();
		const blockedWrite = runtime.emit("tool_call", {
			toolName: "write",
			toolCallId: "w1",
			input: {
				path: "src/x.ts",
				content: "export const n = 1; // slop\n",
			},
		})[0];
		expect(blockedWrite).toMatchObject({
			block: true,
			reason: expect.stringMatching(/no-comments: src\/x\.ts/),
		});

		const blockedEdit = runtime.emit("tool_call", {
			toolName: "Edit",
			toolCallId: "e1",
			input: {
				file_path: "src/x.ts",
				old_string: "export const n = 1;",
				new_string: "export const n = 1; // slop",
			},
		})[0];
		expect(blockedEdit).toMatchObject({ block: true });

		const allowed = runtime.emit("tool_call", {
			toolName: "write",
			toolCallId: "w2",
			input: { path: "src/x.ts", content: "export const n = 1;\n" },
		})[0];
		expect(allowed).toBeUndefined();

		const bash = runtime.emit("tool_call", {
			toolName: "bash",
			toolCallId: "b1",
			input: { command: "echo // comment" },
		})[0];
		expect(bash).toBeUndefined();

		const markdown = runtime.emit("tool_call", {
			toolName: "write",
			toolCallId: "md1",
			input: { path: "PLAN.md", content: "# PLAN\n// docs\n" },
		})[0];
		expect(markdown).toBeUndefined();
	});
});
