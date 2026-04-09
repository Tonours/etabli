/// <reference path="./bun-test.d.ts" />
import { describe, expect, test } from "bun:test";
import { delimiter } from "node:path";
import {
  createRtkCommandRewriter,
  createRtkSpawnHook,
  getRtkRuntimeState,
  prependPathToEnv,
  resetRtkRuntimeState,
} from "../lib/rtk-runtime.ts";

const DEFAULT_CONFIG = {
  enabled: true,
  mode: "always" as const,
  maxCacheEntries: 2,
  maxCommandLength: 64,
  dangerousCommandBypass: true,
};

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
    }, DEFAULT_CONFIG);

    expect(rewrite("git status")).toBe("rtk git status");
    expect(rewrite("git status")).toBe("rtk git status");
    expect(calls).toBe(1);
    expect(getRtkRuntimeState().cacheHits).toBe(1);
  });

  test("caches expected no-rewrite failures as the original command", () => {
    let calls = 0;
    const rewrite = createRtkCommandRewriter(() => {
      calls += 1;
      throw { status: 1 };
    }, DEFAULT_CONFIG);

    expect(rewrite("echo hi")).toBe("echo hi");
    expect(rewrite("echo hi")).toBe("echo hi");
    expect(calls).toBe(1);
  });

  test("disables rewrites after a missing-binary error", () => {
    let calls = 0;
    const rewrite = createRtkCommandRewriter(() => {
      calls += 1;
      throw { code: "ENOENT" };
    }, DEFAULT_CONFIG);

    expect(rewrite("git status")).toBe("git status");
    expect(rewrite("ls -la")).toBe("ls -la");
    expect(calls).toBe(1);
    expect(getRtkRuntimeState().disabled).toBe(true);
  });

  test("does not cache unexpected rewrite failures", () => {
    let calls = 0;
    const rewrite = createRtkCommandRewriter(() => {
      calls += 1;
      throw { status: 2 };
    }, DEFAULT_CONFIG);

    expect(rewrite("git diff")).toBe("git diff");
    expect(rewrite("git diff")).toBe("git diff");
    expect(calls).toBe(2);
  });

  test("skips empty commands", () => {
    let calls = 0;
    const rewrite = createRtkCommandRewriter(() => {
      calls += 1;
      return "noop";
    }, DEFAULT_CONFIG);

    expect(rewrite("   ")).toBe("   ");
    expect(calls).toBe(0);
  });

  test("bypasses dangerous and multiline commands", () => {
    resetRtkRuntimeState();
    let calls = 0;
    const rewrite = createRtkCommandRewriter((command) => {
      calls += 1;
      return `rtk ${command}`;
    }, DEFAULT_CONFIG);

    expect(rewrite("rm -rf build")).toBe("rm -rf build");
    expect(rewrite("echo hi | cat")).toBe("echo hi | cat");
    expect(rewrite("echo one\necho two")).toBe("echo one\necho two");
    expect(calls).toBe(0);
    expect(getRtkRuntimeState().bypasses).toBe(3);
    expect(getRtkRuntimeState().lastBypassReason).toBe("multiline");
  });

  test("evicts oldest cache entries when max size is reached", () => {
    let calls = 0;
    const rewrite = createRtkCommandRewriter((command) => {
      calls += 1;
      return `rtk ${command}`;
    }, DEFAULT_CONFIG);

    expect(rewrite("git status")).toBe("rtk git status");
    expect(rewrite("git diff")).toBe("rtk git diff");
    expect(rewrite("git log")).toBe("rtk git log");
    expect(rewrite("git status")).toBe("rtk git status");
    expect(calls).toBe(4);
    expect(getRtkRuntimeState().cacheSize).toBe(2);
  });
});
