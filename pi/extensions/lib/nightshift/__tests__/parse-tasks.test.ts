import { describe, expect, test } from "bun:test";
import { parseTasks, normalizeTaskId } from "../parse-tasks.ts";

describe("normalizeTaskId", () => {
  test("lowercases and replaces non-alphanumeric with dashes", () => {
    expect(normalizeTaskId("Fix Login Redirect")).toBe("fix-login-redirect");
  });

  test("preserves dots, underscores, and dashes", () => {
    expect(normalizeTaskId("my.task_name-v2")).toBe("my.task_name-v2");
  });

  test("trims leading and trailing dashes", () => {
    expect(normalizeTaskId("--hello--")).toBe("hello");
  });

  test("collapses consecutive special chars into single dash", () => {
    expect(normalizeTaskId("a   b!!!c")).toBe("a-b-c");
  });

  test("handles empty string", () => {
    expect(normalizeTaskId("")).toBe("");
  });

  test("handles all-special-chars string", () => {
    expect(normalizeTaskId("!!!")).toBe("");
  });
});

describe("parseTasks", () => {
  test("parses single task with all fields", () => {
    const input = `# Night Shift Tasks

## TASK fix-login-redirect
repo: my-repo
base: main
branch: night/fix-login-redirect
engine: codex
verify:
- bun test
- bun run lint
prompt:
Fix the login redirect loop.

Context:
- Users on /app are redirected back to /login even after auth.
ENDPROMPT
`;

    const tasks = parseTasks(input);
    expect(tasks).toHaveLength(1);
    expect(tasks[0].id).toBe("fix-login-redirect");
    expect(tasks[0].repo).toBe("my-repo");
    expect(tasks[0].base).toBe("main");
    expect(tasks[0].branch).toBe("night/fix-login-redirect");
    expect(tasks[0].engine).toBe("codex");
    expect(tasks[0].verify).toEqual(["bun test", "bun run lint"]);
    expect(tasks[0].prompt).toBe(
      "Fix the login redirect loop.\n\nContext:\n- Users on /app are redirected back to /login even after auth.\n",
    );
  });

  test("parses multiple tasks", () => {
    const input = `## TASK task-one
repo: repo-a
engine: none
prompt:
Do thing one.
ENDPROMPT

## TASK task-two
repo: repo-b
prompt:
Do thing two.
ENDPROMPT
`;

    const tasks = parseTasks(input);
    expect(tasks).toHaveLength(2);
    expect(tasks[0].id).toBe("task-one");
    expect(tasks[0].engine).toBe("none");
    expect(tasks[1].id).toBe("task-two");
    expect(tasks[1].engine).toBe("codex"); // default
  });

  test("applies defaults: base=main, engine=codex, branch=night/{id}", () => {
    const input = `## TASK my-task
repo: demo
prompt:
Hello.
ENDPROMPT
`;

    const tasks = parseTasks(input);
    expect(tasks).toHaveLength(1);
    expect(tasks[0].base).toBe("main");
    expect(tasks[0].engine).toBe("codex");
    expect(tasks[0].branch).toBe("night/my-task");
    expect(tasks[0].verify).toEqual([]);
    expect(tasks[0].prompt).toBe("Hello.\n");
  });

  test("normalizes task ID with special characters", () => {
    const input = `## TASK Fix Login  Redirect!!
repo: app
prompt:
Fix it.
ENDPROMPT
`;

    const tasks = parseTasks(input);
    expect(tasks[0].id).toBe("fix-login-redirect");
    expect(tasks[0].branch).toBe("night/fix-login-redirect");
  });

  test("handles path field instead of repo", () => {
    const input = `## TASK custom-path
path: /abs/path/to/repo
prompt:
Work here.
ENDPROMPT
`;

    const tasks = parseTasks(input);
    expect(tasks[0].path).toBe("/abs/path/to/repo");
    expect(tasks[0].repo).toBeUndefined();
  });

  test("handles task without prompt block", () => {
    const input = `## TASK no-prompt
repo: demo
engine: none
`;

    const tasks = parseTasks(input);
    expect(tasks).toHaveLength(1);
    expect(tasks[0].prompt).toBe("");
  });

  test("handles empty verify list", () => {
    const input = `## TASK empty-verify
repo: demo
verify:
prompt:
Do thing.
ENDPROMPT
`;

    const tasks = parseTasks(input);
    expect(tasks[0].verify).toEqual([]);
  });

  test("stops verify list on non-list line", () => {
    const input = `## TASK mixed
repo: demo
verify:
- bun test
engine: codex
prompt:
Hello.
ENDPROMPT
`;

    const tasks = parseTasks(input);
    expect(tasks[0].verify).toEqual(["bun test"]);
    expect(tasks[0].engine).toBe("codex");
  });

  test("ignores lines before first task", () => {
    const input = `# Night Shift Tasks

Prep session:
- add tasks

## TASK actual-task
repo: demo
prompt:
Real task.
ENDPROMPT
`;

    const tasks = parseTasks(input);
    expect(tasks).toHaveLength(1);
    expect(tasks[0].id).toBe("actual-task");
  });

  test("handles empty input", () => {
    expect(parseTasks("")).toEqual([]);
    expect(parseTasks("# Just a heading\nSome text")).toEqual([]);
  });

  test("prompt includes blank lines", () => {
    const input = `## TASK multiline
repo: demo
prompt:
Line one.

Line three.
ENDPROMPT
`;

    const tasks = parseTasks(input);
    expect(tasks[0].prompt).toBe("Line one.\n\nLine three.\n");
  });

  test("preserves arbitrary key-value pairs", () => {
    const input = `## TASK with-extra
repo: demo
customField: custom-value
prompt:
Go.
ENDPROMPT
`;

    const tasks = parseTasks(input);
    // The parser stores arbitrary keys on the task
    expect((tasks[0] as Record<string, unknown>)["customField"]).toBe("custom-value");
  });
});
