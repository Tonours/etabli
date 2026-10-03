import assert from "node:assert/strict";
import { execFileSync, spawn } from "node:child_process";
import { isAbsolute, resolve, sep } from "node:path";
import { assertionProtocol } from "./project-verification-assertions.mjs";
import { sha256 } from "./project-verification-source.mjs";
import { setTimeout as delay } from "node:timers/promises";

export function verificationEnvironment(source = process.env) {
  return Object.fromEntries(
    [
      "PATH",
      "HOME",
      "USER",
      "LOGNAME",
      "TMPDIR",
      "TEMP",
      "TMP",
      "LANG",
      "LC_ALL",
      "TZ",
      "SYSTEMROOT",
    ]
      .filter((name) => source[name] !== undefined)
      .map((name) => [name, source[name]]),
  );
}

export function processGroupMembers(group) {
  if (!group) return [];
  return execFileSync("ps", ["-axo", "pid=,pgid="], { encoding: "utf8" })
    .trim()
    .split("\n")
    .map((line) => line.trim().split(/\s+/).map(Number))
    .filter(([, pgid]) => pgid === group)
    .map(([pid]) => pid);
}

function leaderIsLive(pid) {
  if (!pid) return false;
  return execFileSync("ps", ["-axo", "pid=,stat="], { encoding: "utf8" })
    .trim()
    .split("\n")
    .some((line) => {
      const [candidate, state] = line.trim().split(/\s+/);
      return Number(candidate) === pid && !/^[ZX]/.test(state);
    });
}

export function createVerificationProcesses({
  cwd,
  runRoot,
  originRoot,
  environment,
  binding,
  installedPaths = [],
}) {
  const owned = new Set();
  const shutdown = new AbortController();
  const listeners = new Map(
    ["SIGINT", "SIGTERM"].map((signal) => [
      signal,
      () => shutdown.abort(new Error(`Verification interrupted by ${signal}`)),
    ]),
  );
  for (const [signal, listener] of listeners) process.on(signal, listener);
  function safeArguments(argv) {
    if (!isAbsolute(argv[0]) && /[\\/]/.test(argv[0]))
      assert.ok(
        resolve(cwd, argv[0]).startsWith(cwd + sep),
        "Project executable must belong to owned source",
      );
    if (
      isAbsolute(argv[0]) &&
      originRoot &&
      argv[0].startsWith(originRoot + sep)
    )
      assert.ok(
        [cwd, runRoot, ...installedPaths].some((root) =>
          argv[0].startsWith(root + sep),
        ),
        "Origin project executable must run from owned source or an explicitly selected installed runtime",
      );
    for (const argument of argv.slice(1)) {
      assert.ok(
        !argument.split(/[\\/]/).includes(".."),
        "Command argument must not escape owned source",
      );
      if (isAbsolute(argument))
        assert.ok(
          [cwd, runRoot, ...installedPaths].some(
            (root) => argument === root || argument.startsWith(root + sep),
          ),
          "Absolute project argument must use owned source/runtime or explicitly selected installed tools",
        );
    }
  }
  function start(
    command,
    role,
    {
      scenarioId,
      service = false,
      engine = false,
      env = environment,
      cleanup = false,
    } = {},
  ) {
    if (!cleanup) shutdown.signal.throwIfAborted();
    safeArguments(command.argv);
    const started = new Date().toISOString();
    const child = spawn(command.argv[0], command.argv.slice(1), {
      cwd,
      env,
      shell: false,
      detached: true,
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = Buffer.alloc(0),
      timedOut = false,
      spawnError,
      intentional = false;
    const handle = {
      child,
      role,
      service,
      ready: false,
      unexpectedExit: false,
      reaped: false,
      exited: false,
      closed: false,
    };
    owned.add(handle);
    child.stdout.on("data", (bytes) => {
      if (!engine) stdout = Buffer.concat([stdout, bytes]);
    });
    child.stderr.on("data", () => {}); // No raw diagnostics or agent output are exported.
    const signalGroup = (signal) => {
      if (!child.pid) return;
      try {
        process.kill(-child.pid, signal);
      } catch (error) {
        if (error.code !== "ESRCH" && processGroupMembers(child.pid).length)
          throw error;
      }
    };
    let escalation;
    handle.stop = () => {
      if (
        service &&
        !intentional &&
        !handle.exited &&
        !leaderIsLive(child.pid)
      ) {
        handle.exited = true;
        handle.unexpectedExit = true;
      }
      if (!handle.exited) intentional = true;
      signalGroup("SIGTERM");
      escalation ??= setTimeout(() => signalGroup("SIGKILL"), 2000);
    };
    const timeout = setTimeout(() => {
      timedOut = true;
      handle.stop();
    }, command.timeout_ms);
    const abort = () => handle.stop();
    if (!cleanup)
      shutdown.signal.addEventListener("abort", abort, { once: true });
    child.once("error", (error) => {
      spawnError = error.code || "spawn_failed";
    });
    child.once("exit", () => {
      handle.exited = true;
      if (service && !intentional) handle.unexpectedExit = true;
    });
    handle.done = new Promise((done) =>
      child.once("close", (code, signal) => {
        handle.closed = true;
        clearTimeout(timeout);
        clearTimeout(escalation);
        shutdown.signal.removeEventListener("abort", abort);
        if (service && !intentional) handle.unexpectedExit = true;
        const receipt = {
          protocol: assertionProtocol,
          ...binding,
          role,
          ...(scenarioId ? { scenario_id: scenarioId } : {}),
          argv: command.argv,
          cwd,
          pid: child.pid ?? null,
          started_at: started,
          ended_at: new Date().toISOString(),
          exit_code: code,
          signal,
          timed_out: timedOut,
          timeout_ms: command.timeout_ms,
          stdout_sha256: sha256(stdout),
          ...(spawnError ? { spawn_error: spawnError } : {}),
          ...(service
            ? {
                owned_shutdown: intentional,
                ready_observed: handle.ready,
                unexpected_exit: handle.unexpectedExit,
              }
            : {}),
        };
        handle.receipt = receipt;
        done({
          receipt,
          stdout,
          ok: !spawnError && code === 0 && signal === null && !timedOut,
        });
      }),
    );
    handle.clearEscalation = () => clearTimeout(escalation);
    return handle;
  }
  return {
    signal: shutdown.signal,
    start,
    async command(spec, role, options) {
      return start(spec, role, options).done;
    },
    assertServices() {
      for (const handle of owned)
        assert.ok(
          !handle.service || (!handle.exited && !handle.closed),
          "Owned service exited before cleanup",
        );
    },
    async stopAll() {
      const alive = (handle) =>
        processGroupMembers(handle.child.pid).length > 0;
      for (const handle of owned) if (alive(handle)) handle.stop();
      await Promise.all([...owned].map((handle) => handle.done));
      const deadline = Date.now() + 10000;
      while ([...owned].some(alive) && Date.now() < deadline) {
        for (const handle of owned)
          if (alive(handle)) {
            try {
              process.kill(-handle.child.pid, "SIGKILL");
            } catch (error) {
              if (error.code !== "ESRCH" && alive(handle)) throw error;
            }
          }
        await delay(50);
      }
      for (const handle of owned) handle.reaped = !alive(handle);
      for (const handle of owned) handle.clearEscalation();
      return [...owned].map((handle) => ({
        pid: handle.child.pid ?? null,
        reaped: handle.reaped,
      }));
    },
    dispose() {
      for (const [signal, listener] of listeners)
        process.removeListener(signal, listener);
    },
  };
}
