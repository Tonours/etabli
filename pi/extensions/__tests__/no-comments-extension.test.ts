import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
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

type Handler = (event: Record<string, unknown>, ctx: { cwd: string }) => unknown;

let fixtureCwd = "";

beforeEach(() => {
	fixtureCwd = mkdtempSync(join(tmpdir(), "etabli-no-comments-fixture-"));
	mkdirSync(join(fixtureCwd, ".git"));
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
			return (handlers.get(eventName) ?? []).map((handler) => handler(event, { cwd: fixtureCwd }));
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

	test("keeps an existing comment when the previous text was past the nesting cap", () => {
		const nest = (depth: number) => `// keep\nconst x=${"`${".repeat(depth)}0${"}`".repeat(depth)};\n`;
		expect(addedCommentLines(nest(65), nest(64), "clike")).toEqual([]);
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

	test("denies astro comments and duplicated comments", () => {
		writeFileSync(join(fixtureCwd, "dup.ts"), "/* Existing note. */\nexport const a = 1;\n");
		expect(decide(write("e.astro", "---\n// note\n---\n"))).toBe("deny");
		expect(decide(write("dup.ts", "/* Existing note. */\n/* Existing note. */\nexport const a = 1;\n"))).toBe("deny");
		expect(
			decide({ tool_name: "edit", tool_input: { path: "dup.ts", oldText: "export const a = 1;", newText: "export const a = 1;\n/* Existing note. */" } }),
		).toBe("deny");
		expect(
			decide({
				tool_name: "multiedit",
				tool_input: {
					path: "dup.ts",
					edits: [
						{ oldText: "export const a = 1;", newText: "export const a = 1;\n// Existing note." },
						{ oldText: "// Existing note.", newText: "/* Existing note. */" },
					],
				},
			}),
		).toBe("deny");
		expect(
			decide({ tool_name: "edit", tool_input: { path: "dup.ts", oldText: "export const a = 1;", newText: "export const a = 2;" } }),
		).toBe("allow");
	});

	test("allows doc comments and a shell header, denies other comments", () => {
		writeFileSync(join(fixtureCwd, "doc.ts"), "/**\n * Existing doc.\n */\nexport const a = 1;\n");
		expect(
			decide({ tool_name: "edit", tool_input: { path: "doc.ts", oldText: " * Existing doc.\n", newText: " * Existing doc.\n * new line\n" } }),
		).toBe("allow");
		expect(decide(write("lib.rs", "//! Crate docs.\n/// Adds one.\npub fn inc(x: u8) -> u8 { x + 1 }\n"))).toBe("allow");
		expect(decide(write("lib2.rs", "//// banner\npub fn inc() {}\n"))).toBe("deny");
		expect(decide(write("api.ts", "/** Adds one. */\nexport const inc = (x: number) => x + 1;\n"))).toBe("allow");
		expect(decide(write("note.ts", "/* note */\nexport {};\n"))).toBe("deny");
		expect(decide(write("stars.rs", "/*** ordinary */\npub fn f() {}\n"))).toBe("deny");
		expect(decide(write("line.ts", "// note\nexport {};\n"))).toBe("deny");
		expect(decide(write("head.sh", "#!/usr/bin/env bash\n# Deploys the thing.\n#\n# Usage: head.sh\nset -eu\n"))).toBe("allow");
		expect(decide(write("late.sh", "set -eu\n# restates set\n"))).toBe("deny");
		expect(decide(write("sub.sh", "\"$(\n# note\n)\"\n"))).toBe("deny");
		expect(decide(write("head.py", "# note\nx = 1\n"))).toBe("deny");
	});

	test("guards only files inside a git work tree, lexical or physical", () => {
		const outside = mkdtempSync(join(tmpdir(), "etabli-no-comments-outside-"));
		try {
			const added = "// note\nexport {};\n";
			expect(noCommentsGuardDecision({ cwd: outside, tool_name: "Write", tool_input: { file_path: "a.ts", content: added } })).toBeNull();
			expect(noCommentsGuardDecision({ cwd: outside, tool_name: "Write", tool_input: { file_path: join(fixtureCwd, "a.ts"), content: added } })).not.toBeNull();
			mkdirSync(join(fixtureCwd, "src"));
			writeFileSync(join(fixtureCwd, "src", "real.ts"), "export {};\n");
			symlinkSync(join(fixtureCwd, "src"), join(outside, "linked"));
			symlinkSync(join(fixtureCwd, "src", "real.ts"), join(outside, "file.ts"));
			const viaLink = (file_path: string) =>
				noCommentsGuardDecision({ cwd: outside, tool_name: "Write", tool_input: { file_path, content: added } });
			expect(viaLink("linked/real.ts")).not.toBeNull();
			expect(viaLink("linked/deep/new.ts")).not.toBeNull();
			expect(viaLink("file.ts")).not.toBeNull();
			expect(viaLink("linked/../escape.ts")).not.toBeNull();
			expect(noCommentsGuardDecision({ cwd: outside, tool_name: "Write", tool_input: { file_path: join(fixtureCwd, "..", "beside.ts"), content: added } })).toBeNull();
			const worktree = join(outside, "wt");
			mkdirSync(worktree);
			writeFileSync(join(worktree, ".git"), "gitdir: /elsewhere\n");
			expect(viaLink("wt/a.ts")).not.toBeNull();
		} finally {
			rmSync(outside, { recursive: true, force: true });
		}
	});

	test("lexes strings, comments and regexes per language", () => {
		expect(collectCommentLines('const x = "(/)"; // added note\n', "clike")).toEqual(["// added note"]);
		expect(collectCommentLines("const s = `a\n// not a comment\nb`;\n", "clike")).toEqual([]);
		expect(collectCommentLines('s = """first\n# data\nlast"""\n', "python")).toEqual([]);
		expect(collectCommentLines("x = 1# added note\n", "python")).toEqual(["# added note"]);
		expect(collectCommentLines("data='first\n# data\nlast'\n", "shell")).toEqual([]);
		expect(collectCommentLines("n=${#arr[@]}\necho $#\n", "shell")).toEqual([]);
		expect(commentFamilyFor("a.sh")).toBe("shell");
		expect(collectCommentLines("SELECT 'first\n-- data\nlast';\n", "sql")).toEqual([]);
		expect(collectCommentLines("echo $'it\\'s'\n# added note\n", "shell")).toEqual(["# added note"]);
		expect(collectCommentLines('x="$(\n  printf hi # added note\n)"\necho "$x"\n', "shell")).toEqual(["# added note"]);
		expect(collectCommentLines("SELECT E'it\\'s';\n-- added note\n", "sql")).toEqual(["-- added note"]);
		expect(collectCommentLines('m="$(grep -o \\( "$f")\n# data"\n', "shell")).toEqual([]);
		expect(collectCommentLines("t=\"$(cat <<'TEXT'\n# Heading\nTEXT\n)\"\n# added note\n", "shell")).toEqual(["# added note"]);
		expect(collectCommentLines("cat <<EOF\n$(\n  printf hi # added note\n)\nEOF\n", "shell")).toEqual(["# added note"]);
		expect(collectCommentLines("cat <<EOF.json\n{}\nEOF.json\n# added note\ncat <<EOF\nx\nEOF\n", "shell")).toEqual(["# added note"]);
		expect(collectCommentLines('SELECT e"path\\" FROM src; -- added note\n', "sql")).toEqual(["-- added note"]);
		expect(collectCommentLines("cat <<EOF\nDon't panic\n# Heading\nEOF\n# added note\n", "shell")).toEqual(["# added note"]);
		expect(collectCommentLines("cat <<EOF\n`printf hi # added note\n`\nEOF\n", "shell")).toEqual(["# added note"]);
		expect(collectCommentLines('r="$(cat test-case.json)"\n# added note\n', "shell")).toEqual(["# added note"]);
		expect(collectCommentLines('r="$(case "$m" in\n  prod) printf p;;\nesac>/dev/null)"\n# added note\n', "shell")).toEqual(["# added note"]);
		expect(collectCommentLines('v="$((case>0))"\n# added note\n', "shell")).toEqual(["# added note"]);
		expect(collectCommentLines('t="$(( $(case "$q" in (case) printf 12;; (*) printf 1;; esac) + 1 ))"\n# added note\n', "shell")).toEqual(["# added note"]);
	});

	test("lexes SQL and Lua block constructs", () => {
		const cases: Array<[string, string, string[]]> = [
			["sql", "/* first\n-- data\nlast */\nSELECT 1;\n", ["/* first", "-- data", "last */"]],
			["sql", "/* ' outer /* inner */ ' */\nSELECT 1; -- actual comment\n", ["/* ' outer /* inner */ ' */", "-- actual comment"]],
			["lua", "--[[ first\nsecond ]]\nx = 1\n", ["--[[ first", "second ]]"]],
			["lua", "--[==[ a\n]] b\n]==]\n", ["--[==[ a", "]] b", "]==]"]],
			["lua", "s = [[\n-- data\n]]\n-- added note\n", ["-- added note"]],
			["lua", "s = [=[\n]]\n-- data\n]=]\n", []],
			["clike", '/* a /* b */\nconst s = "*/";\n', ["/* a /* b */"]],
			["sql", "SELECT $$/* data */$$;\n", []],
			["sql", "SELECT $body$\n-- data\n$body$; -- added note\n", ["-- added note"]],
			["sql", "SELECT $1; -- added note\n", ["-- added note"]],
			["sql", "SELECT a$x$ FROM t; -- added note\nSELECT b$x$;\n", ["-- added note"]],
			["sql", "SELECT 1 AS a$$x$$; -- added note\nSELECT 2 AS b$$x$$;\n", ["-- added note"]],
			["sql", "SELECT é$x$; -- added note\nSELECT b$x$;\n", ["-- added note"]],
			["sql", "SELECT $é$/* data */$é$;\n", []],
		];
		for (const [family, text, expected] of cases) expect(collectCommentLines(text, family)).toEqual(expected);
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

	test("resolves the edited file against the session cwd, not the process cwd", () => {
		mkdirSync(join(fixtureCwd, "src"));
		writeFileSync(join(fixtureCwd, "src", "kept.ts"), "export const n = 1; // kept\n");
		expect(process.cwd()).not.toBe(fixtureCwd);
		const runtime = setupExtension();
		const rewrite = runtime.emit("tool_call", {
			toolName: "write",
			toolCallId: "w3",
			input: { path: "src/kept.ts", content: "export const n = 2; // kept\n" },
		})[0];
		expect(rewrite).toBeUndefined();
	});
});

describe("no-comments lexer edges", () => {
	const decide = (event: Parameters<typeof noCommentsGuardDecision>[0]) => guardDecision(event);
	const note = ["// note"];
	const lex = (family: string, text: string, expected: string[]) => expect(collectCommentLines(text, family)).toEqual(expected);

	test("exempts only real shebang and license lines", () => {
		lex("python", "#!/usr/bin/env python3\nx = 1\n", []);
		lex("clike", "// License: MIT\n// licence Apache-2.0\n", []);
		lex("clike", "// uses a license key\n// mit result\n", ["// uses a license key", "// mit result"]);
	});

	test("tells line comment starters apart from operators", () => {
		lex("sql", "SELECT 5 - 3, a-b;\n", []);
		lex("lua", "x = a-b\n", []);
		lex("ruby", "# note\n", []);
	});

	test("ends block comments at the right closer", () => {
		lex("clike", "/*/ added note\nstill */\nconst a = 1;\n", ["/*/ added note", "still */"]);
		lex("clike", "/**/\nconst a = 1; // note\n", ["/**/", "// note"]);
		lex("sql", "/* a /* b */ c */ SELECT 1; -- note\n", ["/* a /* b */ c */", "-- note"]);
		lex("sql", "/* a /* b */*/ SELECT 1; -- note\n", ["/* a /* b */*/", "-- note"]);
	});

	test("reads regex literals up to their closing slash only", () => {
		lex("clike", "const r = /ab\n// note\n", note);
		lex("clike", "x = /ab", []);
		lex("clike", "const r = /\\//; // note\n", note);
		lex("clike", "x = /[///]/;\n", []);
		lex("clike", 'x = /["]/; // note\n', note);
		lex("clike", 'x = /a"b/; // note\n', note);
		lex("clike", "x = /a/ / 2; // note\n", note);
		lex("clike", 'x = /a/"b // c"\n', []);
		lex("clike", 'if (a) b(); else return /"/; // note\n', note);
	});

	test("honours escapes per string family", () => {
		lex("python", 'x = "a"  # note\n', ["# note"]);
		lex("python", "x = 'it'\n# note\n", ["# note"]);
		lex("clike", "x = 'a\\'b'; // note\n", note);
		lex("clike", "x = `a\\`b` // note\n", note);
		lex("clike", 's = "\\a\\" b"; // note\n', note);
		lex("shell", "echo 'a\\'\n# note\n", ["# note"]);
		lex("shell", 'echo "a\\"b" # note\n', ["# note"]);
		lex("sql", "SELECT 'a\\'; -- note\n", ["-- note"]);
		lex("sql", "SELECT $'a\\'; -- note\n", ["-- note"]);
		lex("go", "x := `a\\`\n// note\n", note);
		lex("go", 'x := "a\\"b" // note\n', note);
	});

	test("scans substitutions and template holes only where the language has them", () => {
		lex("clike", 'x = "it`s"; // note\n', note);
		lex("shell", "echo 'a`b' # note\n", ["# note"]);
		lex("clike", 'x = "a${b"; // note\n', note);
		lex("go", "x := `a${b`\n// note\n", note);
		lex("clike", "x = `${a}`; // note\n", note);
		lex("clike", "x = `a`; // note\n", note);
		lex("shell", "echo `date` # note\n", ["# note"]);
		lex("clike", `${"$(".repeat(70)}\n// note`, note);
	});

	test("caps nesting depth without recursing without bound", () => {
		const nest = (depth: number) => `const x=${"`${".repeat(depth)}0${"}`".repeat(depth)};\n`;
		expect(collectCommentLines(nest(64), "clike")).toEqual([]);
		expect(collectCommentLines(nest(65), "clike")).toBeNull();
		expect(collectCommentLines(nest(20000), "clike")).toBeNull();
	});

	test("resumes right after the construct that was skipped", () => {
		lex("clike", 'x\n"a // b"\n', []);
		lex("shell", 'echo \\a"b # c"\n', []);
		lex("shell", 'x=$(a)"b # c"\n', []);
		lex("lua", '--[[ a ]]"x -- y"\n', ["--[[ a ]]"]);
		lex("lua", 's = [[a]]"x -- y"\n', []);
		lex("sql", 'SELECT $$a$$"x -- y"\n', []);
		lex("clike", "const a = [[\n// note\n]];\n", note);
	});

	test("reads heredocs in shell only", () => {
		lex("clike", "x = a <<EOF;\n// note\nEOF\n", note);
		lex("shell", "cat <<-EOF\n\tEOF\n# note\n", ["# note"]);
		lex("shell", "cat <<EOF\n\tEOF\n# data\nEOF\n", []);
	});

	test("accepts a path under each input key and names the comment found", () => {
		const added = "// note\nexport {};\n";
		for (const key of ["file_path", "path", "filePath"]) {
			const verdict = decide({ tool_name: "Write", tool_input: { [key]: "k.ts", content: added } });
			expect(verdict?.hookSpecificOutput.permissionDecisionReason).toContain("k.ts adds a code comment (// note).");
		}
		expect(decide({ tool_name: "Write", tool_input: { filePath: "k.ts", content: "/**/\n" } })).not.toBeNull();
	});

	test("judges an edit without replace_all on its first occurrence only", () => {
		writeFileSync(join(fixtureCwd, "one.ts"), 'const label = "run";\nrun();\n');
		const edit = { path: "one.ts", old_string: "run", new_string: "run/* added note */" };
		expect(decide({ tool_name: "Edit", tool_input: edit })).toBeNull();
		expect(decide({ tool_name: "Edit", tool_input: { ...edit, replaceAll: false } })).toBeNull();
		expect(decide({ tool_name: "Edit", tool_input: { ...edit, replace_all: false } })).toBeNull();
		expect(decide({ tool_name: "Edit", tool_input: { ...edit, replaceAll: true } })).not.toBeNull();
		expect(decide({ tool_name: "Edit", tool_input: { ...edit, replace_all: true } })).not.toBeNull();
	});

	test("judges a multi-edit on the whole file, not edit by edit", () => {
		writeFileSync(join(fixtureCwd, "move.ts"), "// n\nfoo();\nbar();\n");
		const moved = {
			path: "move.ts",
			edits: [
				{ oldText: "// n\n", newText: "" },
				{ oldText: "bar();", newText: "// n\nbar();" },
			],
		};
		expect(decide({ tool_name: "MultiEdit", tool_input: moved })).toBeNull();
	});

	test("falls back to the edit text when the file cannot be read", () => {
		mkdirSync(join(fixtureCwd, "dir.ts"));
		const verdict = decide({ tool_name: "Edit", tool_input: { path: "dir.ts", old_string: "x", new_string: "// note" } });
		expect(verdict?.hookSpecificOutput.permissionDecision).toBe("deny");
	});

	test("ignores tools that do not write files", () => {
		const input = { path: "a.ts", old_string: "x", new_string: "// note" };
		for (const tool_name of ["Read", "Bash", "shell", "run_terminal_command"]) {
			expect(decide({ tool_name, tool_input: input })).toBeNull();
		}
	});
});
