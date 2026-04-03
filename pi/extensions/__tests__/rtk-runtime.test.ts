/// <reference path="./bun-test.d.ts" />
import { describe, expect, test } from "bun:test";
import { delimiter } from "node:path";
import {
  createRtkCommandRewriter,
  createRtkSpawnHook,
  prependPathToEnv,
} from "../lib/rtk-runtime.ts";

describe("prependPathToEnv", () => {
  test("prepends PATH without dropping existing vars", () => {
    expect(prependPathToEnv({ PATH: "/usr/bin", HOME: "/tmp/home" }, "/tmp/intercepted")).toEqual({
      PATH: `/tmp/intercepted${delimiter}/usr/bin`,
      HOME: "/tmp/home",
    });
  });

  test("creates a PATH when env is missing", () => {
    expect(prependPathToEnv(undefined, "/tmp/intercepted")).toEqual({ PATH: "/tmp/intercepted" });
  });

  test("returns the original env when no prefix exists", () => {
    const env = { PATH: "/usr/bin" };
    expect(prependPathToEnv(env, null)).toBe(env);
  });
});

describe("createRtkSpawnHook", () => {
  test("passes a prefixed PATH into rewrite and execution env", () => {
    let seenEnv: Record<string, string | undefined> | undefined;
    const spawnHook = createRtkSpawnHook({
      pathPrefix: "/tmp/intercepted",
      rewriteCommand: (command, env) => {
        seenEnv = env;
        return `rtk ${command}`;
      },
    });

    const result = spawnHook({
      command: "git status",
      cwd: "/tmp/repo",
      env: { PATH: "/usr/bin", HOME: "/tmp/home" },
    });

    expect(seenEnv).toEqual({
      PATH: `/tmp/intercepted${delimiter}/usr/bin`,
      HOME: "/tmp/home",
    });
    expect(result).toEqual({
      command: "rtk git status",
      cwd: "/tmp/repo",
      env: {
        PATH: `/tmp/intercepted${delimiter}/usr/bin`,
        HOME: "/tmp/home",
      },
    });
  });
});

describe("createRtkCommandRewriter", () => {
  test("caches successful rewrites for identical commands", () => {
    let calls = 0;
    const rewrite = createRtkCommandRewriter((command) => {
      calls += 1;
      return command === "git status" ? "rtk git status" : command;
    });

    expect(rewrite("git status")).toBe("rtk git status");
    expect(rewrite("git status")).toBe("rtk git status");
    expect(calls).toBe(1);
  });

  test("caches expected no-rewrite failures as the original command", () => {
    let calls = 0;
    const rewrite = createRtkCommandRewriter(() => {
      calls += 1;
      throw { status: 1 };
    });

    expect(rewrite("echo hi")).toBe("echo hi");
    expect(rewrite("echo hi")).toBe("echo hi");
    expect(calls).toBe(1);
  });

  test("disables rewrites after a missing-binary error", () => {
    let calls = 0;
    const rewrite = createRtkCommandRewriter(() => {
      calls += 1;
      throw { code: "ENOENT" };
    });

    expect(rewrite("git status")).toBe("git status");
    expect(rewrite("ls -la")).toBe("ls -la");
    expect(calls).toBe(1);
  });

  test("does not cache unexpected rewrite failures", () => {
    let calls = 0;
    const rewrite = createRtkCommandRewriter(() => {
      calls += 1;
      throw { status: 2 };
    });

    expect(rewrite("git diff")).toBe("git diff");
    expect(rewrite("git diff")).toBe("git diff");
    expect(calls).toBe(2);
  });

  test("skips empty commands", () => {
    let calls = 0;
    const rewrite = createRtkCommandRewriter(() => {
      calls += 1;
      return "noop";
    });

    expect(rewrite("   ")).toBe("   ");
    expect(calls).toBe(0);
  });
});
