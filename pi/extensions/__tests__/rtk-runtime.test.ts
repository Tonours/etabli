import { describe, expect, test } from "bun:test";
import { delimiter } from "node:path";
import {
  createRtkCommandRewriter,
  createRtkSpawnHook,
  getRtkRuntimeState,
  prependPathToEnv,
  readRtkRewrite,
  resetRtkRuntimeState,
} from "../lib/rtk-runtime.ts";
import { rtkDataFlowReason } from "../../../workflow/runtime/rtk-data-flow.mjs";

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

  test("scopes rewrite cache entries by execution environment", () => {
    let calls = 0;
    const rewrite = createRtkCommandRewriter((command, env) => {
      calls += 1;
      return `rtk:${env?.PATH}:${command}`;
    }, DEFAULT_CONFIG);

    expect(rewrite("git status", { PATH: "/tmp/asdf-a" })).toBe("rtk:/tmp/asdf-a:git status");
    expect(rewrite("git status", { PATH: "/tmp/asdf-b" })).toBe("rtk:/tmp/asdf-b:git status");
    expect(rewrite("git status", { PATH: "/tmp/asdf-a" })).toBe("rtk:/tmp/asdf-a:git status");
    expect(calls).toBe(2);
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

  test("scopes missing-binary bypasses by execution environment", () => {
    let calls = 0;
    const rewrite = createRtkCommandRewriter((command, env) => {
      calls += 1;
      if (env?.PATH === "/tmp/missing") throw { code: "ENOENT" };
      return `rtk:${command}`;
    }, DEFAULT_CONFIG);

    expect(rewrite("git status", { PATH: "/tmp/missing" })).toBe("git status");
    expect(rewrite("git status", { PATH: "/tmp/found" })).toBe("rtk:git status");
    expect(rewrite("git diff", { PATH: "/tmp/missing" })).toBe("git diff");
    expect(calls).toBe(2);
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

  test("bypasses destructive rm flag variants", () => {
    resetRtkRuntimeState();
    let calls = 0;
    const rewrite = createRtkCommandRewriter((command) => {
      calls += 1;
      return `rtk ${command}`;
    }, DEFAULT_CONFIG);

    expect(rewrite("rm -fr build")).toBe("rm -fr build");
    expect(rewrite("rm -r -f build")).toBe("rm -r -f build");
    expect(rewrite("rm -Rf build")).toBe("rm -Rf build");
    expect(calls).toBe(0);
    expect(getRtkRuntimeState().bypasses).toBe(3);
    expect(getRtkRuntimeState().lastBypassReason).toBe("dangerous-command");
  });

  test("bypasses destructive rm long flag variants", () => {
    resetRtkRuntimeState();
    let calls = 0;
    const rewrite = createRtkCommandRewriter((command) => {
      calls += 1;
      return `rtk ${command}`;
    }, DEFAULT_CONFIG);

    expect(rewrite("rm --recursive --force build")).toBe("rm --recursive --force build");
    expect(rewrite("rm -r --force build")).toBe("rm -r --force build");
    expect(calls).toBe(0);
    expect(getRtkRuntimeState().bypasses).toBe(2);
    expect(getRtkRuntimeState().lastBypassReason).toBe("dangerous-command");
  });

  test("bypasses destructive git clean flag variants", () => {
    resetRtkRuntimeState();
    let calls = 0;
    const rewrite = createRtkCommandRewriter((command) => {
      calls += 1;
      return `rtk ${command}`;
    }, DEFAULT_CONFIG);

    expect(rewrite("git clean -fd")).toBe("git clean -fd");
    expect(rewrite("git clean -xdf")).toBe("git clean -xdf");
    expect(rewrite("git clean -d -f")).toBe("git clean -d -f");
    expect(calls).toBe(0);
    expect(getRtkRuntimeState().bypasses).toBe(3);
    expect(getRtkRuntimeState().lastBypassReason).toBe("dangerous-command");
  });

  test("bypasses destructive git clean long flag variants", () => {
    resetRtkRuntimeState();
    let calls = 0;
    const rewrite = createRtkCommandRewriter((command) => {
      calls += 1;
      return `rtk ${command}`;
    }, DEFAULT_CONFIG);

    expect(rewrite("git clean --force -d")).toBe("git clean --force -d");
    expect(rewrite("git clean --force --directory")).toBe("git clean --force --directory");
    expect(calls).toBe(0);
    expect(getRtkRuntimeState().bypasses).toBe(2);
    expect(getRtkRuntimeState().lastBypassReason).toBe("dangerous-command");
  });

  test("never rewrites a command with a leading or trailing non-ASCII blank", () => {
    resetRtkRuntimeState();
    let calls = 0;
    const rewrite = createRtkCommandRewriter((command) => {
      calls += 1;
      return `rtk ${command}`;
    }, DEFAULT_CONFIG);
    for (let pass = 0; pass < 2; pass += 1) {
      for (const command of ["git diff > /dev/null\u00a0", "\u00a0git status", "git status\u2003"]) {
        expect(rewrite(command)).toBe(command);
      }
    }
    expect(calls).toBe(0);
  });

  test("bypasses destructive commands after compact shell separators", () => {
    resetRtkRuntimeState();
    let calls = 0;
    const rewrite = createRtkCommandRewriter((command) => {
      calls += 1;
      return `rtk ${command}`;
    }, DEFAULT_CONFIG);

    expect(rewrite("true;rm -rf build")).toBe("true;rm -rf build");
    expect(rewrite("true&&git clean -fd")).toBe("true&&git clean -fd");
    expect(calls).toBe(0);
    expect(getRtkRuntimeState().bypasses).toBe(2);
    expect(getRtkRuntimeState().lastBypassReason).toBe("dangerous-command");
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

describe("rtkDataFlowReason", () => {
  test("flags stdout redirected to a file", () => {
    for (const command of ["grep localhost < /etc/hosts", "wc -l <file", "git apply < x.patch | head", "git diff > out.diff", "cat a >> b", "cmd 1>f", "cmd &> f", "git diff > \"patch.diff\"", "git diff >'x y'", "git diff > $OUT", "git diff >&out.patch", "git diff 3>out.patch 1>&3", "git diff >&3", "git diff HEAD~2>out.diff", "git log -10>out.log", "git diff >& out.patch", "git diff 3>out.patch 1>& 3", "git diff 2>out.patch 1>&2", "cmd >&2", "cmd 1>&2"]) {
      expect(rtkDataFlowReason(command)).toBe("redirect");
    }
    for (const command of ["git diff --src-prefix=$'it\\'s/' > /tmp/out.patch", "echo $\"x\" > f", "git diff --src-prefix=\"$(printf \"'\")\" > out.patch", "git diff --src-prefix=\"$(printf \"'\")\" | wc -l", "echo `date` > f", "diff <(a) b", "git diff > $(mktemp)", "git diff >(tee x)", "git diff 1<&2", "echo 'unterminated > f"]) {
      expect(rtkDataFlowReason(command)).toBe("unsupported-syntax");
    }
  });

  test("keeps commands that change shell state raw", () => {
    for (const command of ["head() { wc -l; }; git diff | head", "function head { wc -l; }; git diff | head", "export LESS=-O/tmp/out.patch; git diff | head", "alias head=wc; git diff | head", "FOO=1 git diff | head", "set -o noclobber; git diff | head", "builtin echo x | head", "hash -p /tmp/x head; git diff | head", "enable -n head; git diff | head", "git diff | LESS=-o/tmp/x less", "\"hash\" -p /usr/bin/wc head; git diff | head", "ha\\sh -p /usr/bin/wc head; git diff | head", "'export' LESS=x; git diff | head", "git diff | \"head\"", "command hash -p /usr/bin/wc head; git log -3 | head", "! hash -p /usr/bin/wc head; git diff | head", "time hash -p /usr/bin/wc head; git diff | head", ">/dev/null hash -p /usr/bin/wc head; git diff | head", "env -i FOO=1 hash -p x head; git diff | head", "nohup command -p alias head=wc; git diff | head", "eval 'head() { wc; }'; git diff | head", "exec bash; git diff | head", "command \"hash\" -p x head; git diff | head", "2>&1 hash -p /usr/bin/wc head; git log -3 | head", "if :; then hash -p /usr/bin/wc head; fi; git log -3 | head", "git log || echo x", "echo a | head && git diff > f", "cd x && git diff | head -5", "git status &", "(git diff)", "{ git diff; }", "git diff\ngit log", "while read l; do echo $l; done", "for f in a; do git diff $f; done | head", "2>/dev/null git status", "[[ -f x ]] && git status", "coproc git diff", "git diff > /dev/null(:s,null,../tmp/out.patch,)", "cmd |& wc -l", "a || b | wc", "env GIT_PAGER=cat git log -5", "time git status", "command git diff | head -5", "/usr/bin/env FOO=1 git log", "/bin/hash -p x head", "./", "//x", "git diff >\u00a0/dev/null", "git\u00a0diff | head", "git diff\u2003| head", "git log -1 --oneline \\\n| head -5", "grep \\.md x", "git diff a\\ b", "git status --short # '\nprintf REVIEW_SENTINEL\n# '", "git log 'a\nb'", "git status\r\ngit log", "git diff --src-prefix=\"${unset:-\"'\"}\" | wc -l # '", "git diff --src-prefix=\"${unset:-\"'\"}\" > /tmp/out.patch # '", "git log ${X:-a} | head", "git log $[1+1] | head"]) {
      expect(rtkDataFlowReason(command)).toBe("unsupported-syntax");
    }
  });

  test("flags pipes into a consumer that parses the output", () => {
    for (const command of ["git diff | wc -l", "ls -la | sort", "grep -rn x . | python3 -c 'print(1)'", "git diff | less -o /tmp/out.patch", "git diff | less -O/tmp/out.patch", "git diff | less --log-file=/tmp/out.patch", "git diff | more out.txt", "git diff | cat - out.txt", "git diff | head out.txt", "git diff | tail --follow=name x", "git diff | less 'x'", "git diff | less", "git diff | more", "git diff | head -n 5 6", "git diff | tail -f 5", "git diff | head 6"]) {
      expect(rtkDataFlowReason(command)).toBe("pipe");
    }
  });

  test("keeps display commands rewritable", () => {
    for (const command of ["git status", "git diff | head -50", "git diff | head -n 20", "git diff | head -c 100", "git log | tail -5", "git log | tail -n5 -f", "git diff | cat -n", "git log --format=%h -5", "git diff --stat=100", "docker ps --filter status=running", "git log '${literal}' | head -5", "git log $HOME | head -5", "scripts/verify-agentic-infra core", "./scripts/foo --x", "../bin/tool", "/usr/bin/git status", "awk -v n=1 '{print}' f", "git log --grep=fix | head -5", "jq .x f | head", "ls | cat", "cmd 2>/dev/null", "cmd 2>&1", "cmd > /dev/null", "grep \"a>b\" x", "cmd 2>&1 | head", "cmd >/dev/null 2>&1", "cmd 2> /dev/null", "cmd &>/dev/null", "echo 'Cost: $'", "echo \"$HOME\"", "echo '$(not run)'"]) {
      expect(rtkDataFlowReason(command)).toBeNull();
    }
  });
});

describe("data-flow bypass in the rewriter", () => {
  test("never rewrites a redirected or consumed command, even on a repeat sighting", () => {
    resetRtkRuntimeState();
    const calls: string[] = [];
    const rewrite = createRtkCommandRewriter((command) => {
      calls.push(command);
      return `rtk ${command}`;
    }, { ...DEFAULT_CONFIG, maxCacheEntries: 8 });
    for (let pass = 0; pass < 2; pass += 1) {
      expect(rewrite("git diff > out.diff")).toBe("git diff > out.diff");
      expect(rewrite("git diff | wc -l")).toBe("git diff | wc -l");
    }
    expect(calls).toEqual([]);
    expect(rewrite("git status")).toBe("rtk git status");
  });
});

describe("readRtkRewrite", () => {
  test("treats exit status 3 with a rewritten command on stdout as a rewrite", () => {
    const error = Object.assign(new Error("exit 3"), { status: 3, stdout: "rtk git status" });
    expect(readRtkRewrite(() => { throw error; })).toBe("rtk git status");
  });

  test("rethrows other failures so the caller keeps the raw command", () => {
    const noRewrite = Object.assign(new Error("exit 1"), { status: 1, stdout: "" });
    expect(() => readRtkRewrite(() => { throw noRewrite; })).toThrow("exit 1");
    const emptyThree = Object.assign(new Error("exit 3"), { status: 3, stdout: "" });
    expect(() => readRtkRewrite(() => { throw emptyThree; })).toThrow("exit 3");
  });
});
