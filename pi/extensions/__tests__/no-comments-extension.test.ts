import { describe, expect, test } from "bun:test";
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
			return (handlers.get(eventName) ?? []).map((handler) => handler(event));
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
		expect(commentFamilyFor("a.py")).toBe("hash");
		expect(commentFamilyFor("a.sql")).toBe("dash");
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
		expect(collectCommentLines("#!/usr/bin/env bash\necho hi\n", "hash")).toEqual(
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
			noCommentsGuardDecision({
				tool_name: "Bash",
				tool_input: { command: "echo // not a file comment" },
			}),
		).toBeNull();
		expect(
			noCommentsGuardDecision({
				tool_name: "Write",
				tool_input: { file_path: "PLAN.md", content: "# PLAN\n// ignored\n" },
			}),
		).toBeNull();
		expect(
			noCommentsGuardDecision({
				tool_name: "Write",
				tool_input: { path: "README.md", content: "Note: // docs\n" },
			}),
		).toBeNull();
	});

	test("denies Write that adds a comment on a new code file", () => {
		const decision = noCommentsGuardDecision({
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
				noCommentsGuardDecision({
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
		const edit = noCommentsGuardDecision({
			toolName: "edit",
			input: {
				path: "lib/x.ts",
				old_string: "export const n = 1;",
				new_string: "export const n = 1; // why",
			},
		});
		expect(edit?.hookSpecificOutput?.permissionDecision).toBe("deny");

		const multi = noCommentsGuardDecision({
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
			noCommentsGuardDecision({
				tool_name: "Write",
				tool_input: {
					file_path: "src/ok.ts",
					content: "export const n = 1;\n",
				},
			}),
		).toBeNull();
		expect(
			noCommentsGuardDecision({
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
