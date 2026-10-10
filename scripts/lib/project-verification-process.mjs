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

function processGroupIdentities(group) {
  if (!group) return [];
  return execFileSync("ps", ["-axo", "pid=,pgid=,stat=,lstart="], {
    encoding: "utf8", env: { ...process.env, LC_ALL: "C" },
  }).trim().split("\n").filter(Boolean).map((line) => {
    const match = line.match(/^\s*(\d+)\s+(\d+)\s+(\S+)\s+(.+?)\s*$/);
    assert.ok(match, "Process identity is unavailable");
    return { pid: Number(match[1]), group: Number(match[2]), live: !/^[ZX]/.test(match[3]), birth: match[4].replace(/\s+/g, " ") };
  }).filter((member) => member.group === group);
}

export function processGroupMembers(group) {
  return processGroupIdentities(group).map((member) => member.pid);
}

const defaultCleanupGraceMs = 10000;

function cleanupGraceFromEnv() {
  const raw = process.env.ETABLI_CLEANUP_GRACE_MS;
  const text = typeof raw === "string" ? raw.trim() : "";
  if (!/^[1-9]\d*$/.test(text)) return defaultCleanupGraceMs;
  const value = Number(text);
  if (!Number.isSafeInteger(value) || value > 2147483647) return defaultCleanupGraceMs;
  return value;
}

export function createVerificationProcesses({
  cwd,
  runRoot,
  originRoot,
  environment,
  binding,
  installedPaths = [],
  observeGroup = processGroupIdentities,
  sendGroupSignal = (group, signal) => process.kill(-group, signal),
  sendMemberSignal = (pid, signal) => process.kill(pid, signal),
  closeGraceMs = 2000,
  cleanupGraceMs = cleanupGraceFromEnv(),
}) {
  for (const grace of [closeGraceMs, cleanupGraceMs])
    assert.ok(Number.isSafeInteger(grace) && grace > 0 && grace <= 2147483647, "Shutdown grace must be in Node timer range 1..2147483647");
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
    assert.ok(Number.isSafeInteger(command.timeout_ms) && command.timeout_ms > 0 && command.timeout_ms <= 2147483647, "Command timeout must be in Node timer range 1..2147483647");
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
    let stdout = Buffer.alloc(0), timedOut = false, spawnError, intentional = false;
    let timeout, escalation, completionTimer, resolveDone;
    const handle = {
      child, role, service, ready: false, unexpectedExit: false,
      reaped: false, exited: false, closed: false, settled: false,
      retired: false, identityLost: false, completionForced: false,
      handedOff: false, leaderReaped: false, leaderBirth: undefined, groupMembers: [],
    };
    owned.add(handle);
    handle.done = new Promise((done) => { resolveDone = done; });
    child.stdout.on("data", (bytes) => {
      if (!engine) stdout = Buffer.concat([stdout, bytes]);
    });
    child.stderr.on("data", () => {}); // No raw diagnostics or agent output are exported.
    const asynchronously = (action) => {
      try { action(); }
      catch (error) { handle.groupError = error; }
    };
    const handoff = (members) => {
      if (handle.handedOff || handle.retired || !handle.leaderBirth) return;
      handle.handedOff = true;
      const leader = members.find((member) => member.pid === child.pid);
      if (leader && (handle.leaderReaped || leader.birth !== handle.leaderBirth)) {
        handle.retired = true;
        handle.identityLost = true;
        return;
      }
      handle.groupMembers = members;
      handle.retired = !members.length;
    };
    // Birth observations are sampled; ps/signal is not an atomic kernel lease.
    const observedMembers = () => {
      if (handle.retired || !child.pid) return [];
      if (handle.groupError) throw handle.groupError;
      const members = observeGroup(child.pid);
      if (!handle.handedOff && !handle.exited) {
        const leader = members.find((member) => member.pid === child.pid);
        if (leader?.live) {
          if (handle.leaderBirth && leader.birth !== handle.leaderBirth) {
            handle.retired = true;
            handle.identityLost = true;
            handle.exited = true;
            if (service && !intentional) handle.unexpectedExit = true;
            return [];
          }
          handle.leaderBirth ??= leader.birth;
          handle.groupMembers = members;
          return members;
        }
        if (leader && !handle.leaderReaped) handle.leaderBirth ??= leader.birth;
        if (!handle.leaderBirth) return []; // A newborn miss stays pending.
        handle.exited = true;
        if (service && !intentional) handle.unexpectedExit = true;
        handoff(members);
      }
      if (!handle.handedOff) handoff(members);
      if (!handle.handedOff || handle.retired) return [];
      const anchored = members.some((member) => handle.groupMembers.some(
        (known) => known.pid === member.pid && known.birth === member.birth,
      ));
      if (!members.length || (handle.leaderReaped && members.some((member) => member.pid === child.pid)) || !anchored) {
        handle.retired = true;
        handle.identityLost = members.length > 0;
        return [];
      }
      return members;
    };
    handle.groupAlive = () => observedMembers().length > 0;
    const signalOwned = (signal) => {
      const members = observedMembers();
      if (handle.retired) return;
      if (!handle.handedOff) {
        const leader = members.find((member) => member.pid === child.pid);
        if (!leader?.live || leader.birth !== handle.leaderBirth) return;
        const previouslyIntentional = intentional;
        intentional = true;
        try { sendGroupSignal(child.pid, signal); }
        catch (error) {
          intentional = previouslyIntentional;
          if (error.code === "ESRCH") handle.retired = true;
          else throw error;
        }
        return;
      }
      for (const known of handle.groupMembers) {
        const current = observedMembers().find((member) => member.pid === known.pid && member.birth === known.birth);
        if (!current?.live) continue;
        try { sendMemberSignal(current.pid, signal); }
        catch (error) { if (error.code !== "ESRCH") throw error; }
      }
    };
    handle.kill = () => signalOwned("SIGKILL");
    const clearCallbacks = () => {
      clearTimeout(timeout);
      clearTimeout(escalation);
      clearTimeout(completionTimer);
      shutdown.signal.removeEventListener("abort", abort);
    };
    const finish = (code, signal) => {
      if (handle.settled) return;
      const receipt = {
        protocol: assertionProtocol, ...binding, role,
        ...(scenarioId ? { scenario_id: scenarioId } : {}),
        argv: command.argv, cwd, pid: child.pid ?? null,
        started_at: started, ended_at: new Date().toISOString(),
        exit_code: code, signal, timed_out: timedOut,
        completion_forced: handle.completionForced,
        timeout_ms: command.timeout_ms, stdout_sha256: sha256(stdout),
        ...(spawnError ? { spawn_error: spawnError } : {}),
        ...(service ? {
          owned_shutdown: intentional, ready_observed: handle.ready,
          unexpected_exit: handle.unexpectedExit,
        } : {}),
      };
      handle.settled = true;
      handle.receipt = receipt;
      clearCallbacks();
      resolveDone({receipt, stdout, ok: !spawnError && !handle.completionForced &&
        code === 0 && signal === null && !timedOut && (cleanup || !shutdown.signal.aborted)});
    };
    handle.forceCompletion = () => {
      if (handle.settled) return;
      handle.completionForced = true; // Latch before releasing pipes can emit close.
      try { handle.kill(); }
      catch (error) { handle.groupError = error; }
      finally {
        for (const stream of [child.stdout, child.stderr]) asynchronously(() => stream.destroy());
        try { child.unref(); }
        finally { finish(child.exitCode, child.signalCode); }
      }
    };
    handle.stop = () => {
      try { signalOwned("SIGTERM"); }
      finally {
        if (!handle.settled) {
          // Leave time to observe KILL completion within the total close grace.
          escalation ??= setTimeout(() => asynchronously(handle.kill), Math.max(1, Math.floor(closeGraceMs / 2)));
          completionTimer ??= setTimeout(handle.forceCompletion, closeGraceMs);
        }
      }
    };
    timeout = setTimeout(() => { timedOut = true; asynchronously(handle.stop); }, command.timeout_ms);
    const abort = () => asynchronously(handle.stop);
    if (!cleanup) shutdown.signal.addEventListener("abort", abort, { once: true });
    child.once("error", (error) => { spawnError = error.code || "spawn_failed"; });
    child.once("exit", () => {
      handle.exited = true;
      handle.leaderReaped = true;
      if (service && !intentional) handle.unexpectedExit = true;
      asynchronously(() => { if (!handle.handedOff && !handle.retired) handoff(observeGroup(child.pid)); });
    });
    child.once("close", (code, signal) => {
      handle.closed = true;
      if (!child.pid) handle.retired = true;
      finish(code, signal);
    });
    handle.clearEscalation = () => { clearTimeout(escalation); clearTimeout(completionTimer); };
    asynchronously(observedMembers);
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
          !handle.service || (!handle.exited && !handle.settled),
          "Owned service exited before cleanup",
        );
    },
    async stopAll() {
      const handles = [...owned];
      const deadline = Date.now() + cleanupGraceMs;
      const forcePending = () => { for (const handle of handles) handle.forceCompletion(); };
      let expired = false;
      const completionDeadline = setTimeout(() => { expired = true; forcePending(); }, cleanupGraceMs);
      try {
        for (const handle of handles) if (!handle.settled || handle.groupAlive()) handle.stop();
        await Promise.all(handles.map((handle) => handle.done));
        while (!expired && Date.now() < deadline && handles.some((handle) => handle.groupAlive())) {
          for (const handle of handles) if (handle.groupAlive()) handle.kill();
          await delay(50);
        }
        for (const handle of handles)
          handle.reaped = !handle.groupAlive() && (!handle.child.pid || handle.handedOff) &&
            !handle.identityLost && !handle.completionForced;
        return handles.map((handle) => ({pid: handle.child.pid ?? null, reaped: handle.reaped}));
      } catch (error) {
        forcePending();
        throw error;
      } finally {
        clearTimeout(completionDeadline);
        for (const handle of handles) handle.clearEscalation();
      }
    },
    dispose() {
      for (const [signal, listener] of listeners)
        process.removeListener(signal, listener);
    },
  };
}
