import test from "node:test";
import assert from "node:assert/strict";
import { TABS, newState, usageLines, viewLines, pageLines } from "../claude/mods/etabli/hooks/views.js";
import { captureTime, eventSummary, pageContent, viewOverview } from "../claude/mods/etabli/hooks/overview.js";

function projection(run = "run") {
  return { root: "/work", captured_at: "2026-10-01T00:00:00Z", selection: { run, valid: true, source: `.workflow/${run}/events.jsonl` },
    resume: { objective: "Resume objective", next_action: "Run validation", done: ["Implemented"], pending: ["Native UI"], git: {} },
    routing: { route: "implement", reason: "READY plan", source: "route_decided", contract: { path: "workflow/spec.md", changed: null } },
    journal: { total: 1, page: 0, pages: 1, items: [{ sequence: 1, ts: "t", event: "validation_run", detail: { command: "check", exit: 0 } }] },
    checkpoints: [{ sequence: 1, ts: "t", category: "push", target: "main", decision: "requested", state: "requested", consent_class: "permission_request" }],
    skills: { active_scope: "personal", scope_source: "fixture", items: [{ name: "review", path: "pi/skills/review/SKILL.md", available: true, source: "pi", scope: "shared", scope_active: true, invocation_condition: "Review changes" }] } };
}

let instance = 0;
async function harness() {
  const hooks = [];
  const { register } = await import(`../claude/mods/etabli/hooks/register.js?test=${++instance}`);
  register((name, matcher, handler) => hooks.push({ name, matcher: typeof matcher === "function" ? {} : matcher, handler: typeof matcher === "function" ? matcher : handler }));
  const context = { id: "session-a", cwd: "/work", calls: [], snapshot: projection(), process: null, usage: null };
  const element = (type) => (props) => ({ type, props, children: props.children || [] });
  const api = {
    plugin: { root: "/checkout/claude/mods/etabli" },
    session: { id: async () => context.id, cwd: async () => context.cwd, usage: async () => typeof context.usage === "function" ? context.usage() : context.usage },
    command: { register: async () => {}, list: async () => [{ name: "review", source: "user" }] },
    settings: { read: async () => ({ skillOverrides: { review: "user-invocable-only" }, env: { IGNORED_PRIVATE_SETTING: "never projected" } }) },
    process: { run: async (argv, init) => {
      context.calls.push({ argv, init });
      if (context.process) return context.process(argv, init);
      return { exitCode: 0, stdout: JSON.stringify(context.snapshot), stderr: "" };
    } },
    ui: { invalidate: async () => {}, open: async () => ({}), resolve: () => Object.fromEntries(["Box", "Text", "Button", "Input"].map((type) => [type, element(type)])) },
  };
  const raise = (name, event = {}, next = async () => ({ original: true })) => {
    const hook = hooks.find((hook) => hook.name === name && Object.entries(hook.matcher).every(([key, value]) => Array.isArray(value) ? value.includes(event[key]) : value === event[key]));
    assert.ok(hook, `registered hook for ${name}`);
    return hook.handler(api, event, next);
  };
  const render = () => raise("ui.render", { component: "Pane", requestId: "etabli" });
  const command = (args = "") => raise("command.run", { command: "etabli", args });
  return { context, api, raise, render, command };
}

function elements(tree) { return [tree, ...tree.children.filter((child) => typeof child === "object").flatMap(elements)]; }
function text(tree) { return elements(tree).filter((element) => element.type === "Text").flatMap((element) => element.children).join("\n"); }
function press(tree, key) { const button = elements(tree).find((element) => element.type === "Button" && element.props.key === key); assert.ok(button, key); return button.props.onPress(); }
const deferred = () => { let resolve; const promise = new Promise((done) => { resolve = done; }); return { promise, resolve }; };
// Source-aware regression assertions follow the public Details/page controls.
async function details(h) {
  let tree = await h.render();
  const toggle = elements(tree).find((element) => element.props.key === "details");
  if (toggle.props.label.startsWith("Voir")) { await press(tree, "details"); tree = await h.render(); }
  const position = () => elements(tree).filter((element) => element.type === "Text")
    .map((element) => element.children.join("").match(/^Page (\d+)\/(\d+)$/)).find(Boolean)?.slice(1).map(Number) || [1, 1];
  while (position()[0] > 1) { await press(tree, "prev"); tree = await h.render(); }
  const parts = [text(tree)];
  while (true) {
    const [current, total] = position();
    if (current >= total) break;
    await press(tree, "next"); tree = await h.render(); parts.push(text(tree));
  }
  while (position()[0] > 1) {
    await press(tree, "prev"); tree = await h.render();
  }
  return parts.join("\n");
}
const dossier = (hash, status = "captured") => ({ state: status, identity: { root: "/work", run: "run", base_sha: "base", head_sha: "head", snapshot_sha256: hash, files: [], excerpts: [] },
  complete: true, authority: "raw_evidence_only", captured_at: "t", freshness: "capture only", invalidation_reasons: [], invalidated_files: [], patch: "", patch_bytes: 0, patch_sha256: "patch", excerpts: [], proofs: [] });

test("all eight pure views present source-aware data and paginate every line", () => {
  const state = newState(); state.snapshot = projection();
  for (const [tab] of TABS) { state.tab = tab; assert.ok(viewLines(state).length, tab); }
  state.tab = "routing";
  assert.match(viewLines(state).join("\n"), /Route enregistrée : implement/);
  state.tab = "checkpoints";
  assert.match(viewLines(state).join("\n"), /requested/);
  assert.doesNotMatch(viewLines(state).join("\n"), /granted/);
  const lines = Array.from({ length: 35 }, (_, i) => String(i));
  assert.deepEqual([0, 1, 2].flatMap((page) => pageLines(lines, page).lines), lines);
});

test("unknown telemetry differs from actual zero and cache is not context or session totals", () => {
  const unknown = usageLines(null, null).join("\n");
  assert.match(unknown, /Cache lu : inconnu/);
  assert.match(unknown, /Contexte : inconnu/);
  const measured = usageLines({ context: { tokens: 0, window: 1000000, percent: 0 }, cost: { usd: 0 }, rateLimits: [{ kind: "five_hour", percentUsed: 0 }] },
    { turnId: "parent", usage: { model: "measured", input_tokens: 0, output_tokens: 0, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 } }).join("\n");
  assert.match(measured, /Cache lu : 0/);
  assert.match(measured, /Contexte : 0 \/ 1000000/);
  assert.match(measured, /five_hour : 0 %/);
  assert.match(measured, /ne mesurent pas la fenêtre/);
});

test("adapter opens human-only command, uses fixed argv bridge and exposes eight tabs", async () => {
  const h = await harness();
  assert.deepEqual(await h.command(), {});
  const tree = await h.render();
  assert.match(text(tree), /Resume objective/);
  for (const [key] of TABS) assert.ok(elements(tree).some((element) => element.props.key === key));
  assert.deepEqual(h.context.calls[0].argv.slice(0, 3), ["node", "/checkout/claude/mods/etabli/../../../scripts/lib/etabli-session.mjs", "snapshot"]);
  assert.equal(h.context.calls[0].init.cwd, "/work");
  await press(tree, "skills");
  assert.match(await details(h), /user-invocable-only/);
  assert.doesNotMatch(await details(h), /IGNORED_PRIVATE_SETTING/);
});

test("read failure surfaces an error with stale data and leaves tool results unchanged", async () => {
  const h = await harness(); await h.command();
  h.context.process = async () => ({ exitCode: 1, stdout: '{"error":"missing node helper"}', stderr: "" });
  await press(await h.render(), "refresh");
  assert.match(await details(h), /missing node helper/);
  assert.match(await details(h), /à recontrôler/);
  h.api.ui.invalidate = async () => { throw new Error("SDK paint unavailable"); };
  await press(await h.render(), "refresh");
  assert.match(await details(h), /SDK paint unavailable/);
  assert.doesNotMatch(await details(h), /Lecture en cours/);
  const result = { isError: true, result: "tool denied" };
  assert.equal(await h.raise("tool.call", { tool: "Bash" }, async () => result), result);
});

test("old helper completion cannot overwrite the next session", async () => {
  const h = await harness();
  const pending = deferred(), started = deferred();
  h.context.process = async () => { started.resolve(); return pending.promise; };
  const old = h.command(); await started.promise;
  h.context.id = "session-b";
  await h.raise("session.end", {});
  pending.resolve({ exitCode: 0, stdout: JSON.stringify(projection("old-run")), stderr: "" });
  await old;
  assert.doesNotMatch(await details(h), /old-run|Resume objective/);
});

test("a run selection in the same session fences an older concurrent refresh", async () => {
  const h = await harness();
  const pending = deferred(), started = deferred();
  h.context.process = async () => { started.resolve(); return pending.promise; };
  const old = h.command(); await started.promise;
  h.context.process = async () => ({ exitCode: 0, stdout: JSON.stringify(projection("new-run")), stderr: "" });
  await h.command("run new-run");
  pending.resolve({ exitCode: 0, stdout: JSON.stringify(projection("old-run")), stderr: "" }); await old;
  assert.match(await details(h), /new-run/);
  assert.doesNotMatch(await details(h), /old-run/);
});

test("a session change during native telemetry awaits cannot commit an earlier projection", async () => {
  const h = await harness();
  const pending = deferred(), started = deferred();
  h.context.usage = async () => { started.resolve(); return pending.promise; };
  const old = h.command(); await started.promise;
  h.context.id = "session-b"; await h.raise("session.end", {});
  pending.resolve({ context: { tokens: 123, window: 200000 } }); await old;
  assert.doesNotMatch(await details(h), /Resume objective/);
});

test("subagent usage does not replace parent cache measurements and delayed old-turn events are discarded", async () => {
  const h = await harness(); await h.command("usage");
  await h.raise("turn.complete", { turnId: "parent", usage: { cache_read_input_tokens: 7 } });
  await h.raise("turn.complete", { turnId: "child", agentId: "child", usage: { cache_read_input_tokens: 999 } });
  assert.match(await details(h), /Cache lu : 7/);
  const pending = deferred();
  const old = h.raise("turn.complete", { turnId: "old-parent", usage: { cache_read_input_tokens: 888 } }, () => pending.promise);
  await Promise.resolve(); await Promise.resolve();
  h.context.id = "session-b"; await h.raise("session.end", {}); pending.resolve({ text: "" }); await old;
  await h.command("usage");
  assert.match(await details(h), /Cache lu : inconnu/);
  assert.doesNotMatch(await details(h), /888/);
});

test("native Input callbacks retain base and excerpt arguments for explicit review capture", async () => {
  const h = await harness(); await h.command("review");
  let tree = await h.render();
  const input = (key) => elements(tree).find((element) => element.type === "Input" && element.props.key === key);
  input("base").props.onInput("main"); input("excerpt").props.onSubmit("app.mjs:1-4");
  let argv;
  h.context.process = async (args) => { argv = args; return { exitCode: 1, stdout: '{"error":"fixture no Git"}', stderr: "" }; };
  tree = await h.render(); await press(tree, "capture");
  assert.ok(argv.includes("main")); assert.ok(argv.includes("app.mjs:1-4"));
  assert.match(await details(h), /fixture no Git/);
  for (const [inputValue, expected] of [["", "HEAD"], [" main ", "main"]]) {
    tree = await h.render();
    elements(tree).find((element) => element.type === "Input" && element.props.key === "base").props.onInput(inputValue);
    await press(tree, "capture");
    assert.equal(argv[argv.indexOf("--base") + 1], expected);
  }
});

test("an externally changed active run cannot attach a diagnostic to the previous run", async () => {
  const h = await harness(); await h.command("diagnostic");
  h.context.process = async () => ({ exitCode: 0, stdout: JSON.stringify({ mode: "close", ready: true, project_root: "/work", run: "another-run" }), stderr: "" });
  await press(await h.render(), "close");
  const screen = await details(h);
  assert.match(screen, /active run changed/);
  assert.doesNotMatch(screen, /prêt true/);
});

test("missing closure prerequisites are a displayed diagnostic with remediation, not a bridge error", async () => {
  const h = await harness(); await h.command("diagnostic");
  h.context.process = async () => ({ exitCode: 0, stdout: JSON.stringify({ mode: "close", ready: false, project_root: "/work", run: "run", scope: "prospective-event-chain", error: "Missing fresh review", remediation: "Run the independent review first" }), stderr: "" });
  await press(await h.render(), "close");
  const screen = await details(h);
  assert.match(screen, /prêt false/);
  assert.match(screen, /independent review first/);
  assert.match(screen, /Clôture prospective uniquement/);
  assert.doesNotMatch(screen, /Erreur :/);
});

test("repeated rechecks retain the explicit capture baseline until the user captures again", async () => {
  const h = await harness(); await h.command("review");
  const previous = [];
  h.context.process = async (argv, init) => {
    previous.push(JSON.parse(init.stdin).previous);
    return { exitCode: 0, stdout: JSON.stringify(dossier(previous.length === 1 ? "original" : "changed", previous.length === 1 ? "captured" : "invalidated")), stderr: "" };
  };
  await press(await h.render(), "capture");
  await press(await h.render(), "recheck");
  await press(await h.render(), "recheck");
  assert.equal(previous[0], undefined);
  assert.equal(previous[1].snapshot_sha256, "original");
  assert.equal(previous[2].snapshot_sha256, "original");
  assert.match(await details(h), /Dossier : invalidated/);
  await press(await h.render(), "capture");
  assert.equal(previous.at(-1), undefined);
});

test("a new Git root under the same cwd discards the previous review baseline", async () => {
  const h = await harness(); await h.command("review");
  h.context.process = async () => ({ exitCode: 0, stdout: JSON.stringify(dossier("original")), stderr: "" });
  await press(await h.render(), "capture");
  h.context.snapshot = { ...projection(), root: "/new-root" };
  h.context.process = null;
  await press(await h.render(), "refresh");
  assert.match(await details(h), /Capturer explicitement/);
  assert.doesNotMatch(await details(h), /original/);
});

test("observer SDK failures preserve downstream results and never swallow downstream failures", async () => {
  const startup = await harness();
  startup.api.command.register = async () => { throw new Error("SDK registry unavailable"); };
  const started = { original: "session started" };
  assert.equal(await startup.raise("session.start", {}, async () => started), started);
  for (const name of ["session.measure", "turn.complete", "tool.call"]) {
    for (const failure of ["identity", "redraw"]) {
      const h = await harness(); await h.command();
      if (failure === "identity") h.api.session.id = async () => { throw new Error("SDK identity unavailable"); };
      else h.api.ui.invalidate = async () => { throw new Error("SDK paint unavailable"); };
      let calls = 0;
      const result = { original: true };
      assert.equal(await h.raise(name, {}, async () => { calls += 1; return result; }), result);
      assert.equal(calls, 1);
      const downstream = new Error("Core failure");
      await assert.rejects(h.raise(name, {}, async () => { throw downstream; }), (error) => error === downstream);
    }
  }
});

test("snapshot refresh cannot rehabilitate review freshness after observed activity", async () => {
  const h = await harness(); await h.command("review");
  h.context.process = async () => ({ exitCode: 0, stdout: JSON.stringify(dossier("original")), stderr: "" });
  await press(await h.render(), "capture");
  assert.match(await details(h), /Fraîcheur du dossier : vérifiée/);
  await h.raise("tool.call", {});
  h.context.process = null;
  await press(await h.render(), "refresh");
  assert.match(await details(h), /Fraîcheur du dossier : à recontrôler/);
  h.context.process = async () => ({ exitCode: 0, stdout: JSON.stringify(dossier("original", "unchanged-at-check")), stderr: "" });
  await press(await h.render(), "recheck");
  assert.match(await details(h), /Fraîcheur du dossier : vérifiée/);
});

test("unavailable executable or source checkout has an explicit bridge diagnostic without raw stderr", async () => {
  const h = await harness(); await h.command();
  h.context.process = async () => ({ exitCode: 127, stdout: "", stderr: "not projected" });
  await press(await h.render(), "refresh");
  const screen = await details(h);
  assert.match(screen, /check node on PATH and the source helper/);
  assert.doesNotMatch(screen, /Unexpected end|not projected/);
});

test("clear and resume command matchers discard review and parent cache even with unchanged identity", async () => {
  for (const command of ["clear", "resume"]) {
    const h = await harness(); await h.command("review");
    h.context.process = async () => ({ exitCode: 0, stdout: JSON.stringify(dossier("old")), stderr: "" });
    await press(await h.render(), "capture");
    await h.raise("turn.complete", { turnId: "old", usage: { cache_read_input_tokens: 99 } });
    const result = { text: "core command" };
    assert.equal(await h.raise("command.run", { command, args: "" }, async () => result), result);
    h.context.process = null;
    await h.command("review");
    assert.match(await details(h), /Capturer explicitement/);
    await h.command("usage");
    assert.match(await details(h), /Cache lu : inconnu/);
    assert.doesNotMatch(await details(h), /99/);
  }
});

test("historical run recovery labels the current plan objective as unbound to that historical run", () => {
  const state = newState(); state.snapshot = projection(); state.snapshot.selection.historical = true;
  const screen = viewLines(state).join("\n");
  assert.match(screen, /Objectif \(PLAN.md courant\)/);
  assert.match(screen, /run historique : non attestée/);
});


test("observed activity during a pending recheck cannot restore verified freshness", async () => {
  for (const event of ["tool.call", "turn.complete"]) {
    const h = await harness(); await h.command("review");
    h.context.process = async () => ({ exitCode: 0, stdout: JSON.stringify(dossier("original")), stderr: "" });
    await press(await h.render(), "capture");
    const started = deferred(), pending = deferred();
    h.context.process = async () => { started.resolve(); return pending.promise; };
    const recheck = press(await h.render(), "recheck"); await started.promise;
    await h.raise(event, { turnId: "activity" });
    pending.resolve({ exitCode: 0, stdout: JSON.stringify(dossier("original", "unchanged-at-check")), stderr: "" });
    await recheck;
    assert.match(await details(h), /Fraîcheur du dossier : à recontrôler/);
  }
});

test("new capture fences an old recheck before bind and freezes the requested base and excerpt", async () => {
  const h = await harness(); await h.command("review");
  const original = { ...dossier("original"), identity: { ...dossier("original").identity, base_sha: "old-base" } };
  h.context.process = async () => ({ exitCode: 0, stdout: JSON.stringify(original), stderr: "" });
  let tree = await h.render();
  elements(tree).find((element) => element.type === "Input" && element.props.key === "excerpt").props.onInput("app.mjs:1-1");
  await press(tree, "capture");
  tree = await h.render();
  elements(tree).find((element) => element.type === "Input" && element.props.key === "base").props.onInput("main");
  elements(tree).find((element) => element.type === "Input" && element.props.key === "excerpt").props.onInput("other.mjs:2-3");
  const started = deferred(), pending = deferred();
  let call = 0;
  h.context.process = async () => { if (++call === 1) { started.resolve(); return pending.promise; } return { exitCode: 0, stdout: JSON.stringify(dossier("new")), stderr: "" }; };
  const old = press(tree, "recheck"); await started.promise;
  const oldRequest = h.context.calls.at(-1);
  assert.equal(oldRequest.argv[oldRequest.argv.indexOf("--excerpt") + 1], "app.mjs:1-1");
  const bound = deferred(), bindStarted = deferred(); let ids = 0;
  h.api.session.id = async () => { if (++ids === 1) { bindStarted.resolve(); return bound.promise; } return h.context.id; };
  const fresh = press(tree, "capture"); await bindStarted.promise;
  pending.resolve({ exitCode: 0, stdout: JSON.stringify({ ...original, state: "invalidated", identity: { ...original.identity, snapshot_sha256: "changed" } }), stderr: "" }); await old;
  bound.resolve(h.context.id); await fresh;
  const request = h.context.calls.at(-1);
  assert.equal(request.argv[request.argv.indexOf("--base") + 1], "main");
  assert.equal(request.argv[request.argv.indexOf("--excerpt") + 1], "other.mjs:2-3");
  assert.equal(JSON.parse(request.init.stdin).previous, undefined);
});

test("snapshot refresh cannot rehabilitate an earlier diagnostic after observed activity", async () => {
  const h = await harness(); await h.command("diagnostic");
  h.context.process = async () => ({ exitCode: 0, stdout: JSON.stringify({ mode: "close", ready: true, project_root: "/work", run: "run", captured_at: "diagnostic-time" }), stderr: "" });
  await press(await h.render(), "close");
  assert.match(await details(h), /diagnostic-time ; fraîcheur vérifiée/);
  await h.raise("tool.call", {}); h.context.process = null;
  await press(await h.render(), "refresh");
  assert.match(await details(h), /diagnostic-time ; fraîcheur à recontrôler/);
});


test("an obsolete identity read cannot reset a newer project's captured dossier", async () => {
  const h = await harness(); await h.command("review");
  h.context.process = async () => ({ exitCode: 0, stdout: JSON.stringify(dossier("original")), stderr: "" });
  await press(await h.render(), "capture");
  const tree = await h.render(), pending = deferred(), started = deferred(); let cwdCalls = 0;
  h.api.session.cwd = async () => { if (++cwdCalls === 1) { started.resolve(); return pending.promise; } return h.context.cwd; };
  const old = press(tree, "recheck"); await started.promise;
  h.context.cwd = "/new-project";
  h.context.process = async (argv) => ({ exitCode: 0, stderr: "", stdout: JSON.stringify(argv[2] === "snapshot"
    ? { ...projection(), root: h.context.cwd }
    : { ...dossier("new-project"), identity: { ...dossier("new-project").identity, root: h.context.cwd } }) });
  await h.command("review"); await press(await h.render(), "capture");
  pending.resolve("/work"); await old;
  const screen = await details(h);
  assert.match(screen, /Dossier : captured/);
  assert.match(screen, /Snapshot SHA256 : new-project/);
  assert.match(screen, /Projet : \/new-project/);
});

test("a late command opening cannot cancel a later review capture", async () => {
  const h = await harness(); await h.command("review");
  const opened = deferred(), open = deferred(), started = deferred(), capture = deferred();
  h.api.ui.open = async () => { opened.resolve(); return open.promise; };
  const command = h.command("review"); await opened.promise;
  h.context.process = async (argv) => argv[2] === "review"
    ? (started.resolve(), capture.promise) : { exitCode: 0, stdout: JSON.stringify(projection()) };
  const review = press(await h.render(), "capture"); await started.promise;
  open.resolve({}); await command;
  capture.resolve({ exitCode: 0, stdout: JSON.stringify(dossier("newer-capture")) }); await review;
  const screen = await details(h);
  assert.match(screen, /Snapshot SHA256 : newer-capture/);
  assert.doesNotMatch(screen, /Lecture en cours|Capturer explicitement/);
});

test("an action before the first snapshot is refused and an open failure releases busy", async () => {
  const h = await harness(), opened = deferred(), open = deferred();
  h.api.ui.open = async () => { opened.resolve(); return open.promise; };
  const command = h.command("review"); await opened.promise;
  await press(await h.render(), "capture");
  assert.equal(h.context.calls.length, 0);
  assert.match(await details(h), /projection.*disponible/i);
  open.resolve({}); await command;
  h.api.ui.open = async () => { throw new Error("open unavailable"); };
  assert.deepEqual(await h.command("review"), {});
  assert.match(await details(h), /open unavailable/);
  assert.doesNotMatch(await details(h), /Lecture en cours/);
});

test("a newer explicit refresh labels its superseded capture as cancelled", async () => {
  const h = await harness(); await h.command("review");
  const started = deferred(), pending = deferred();
  h.context.process = async () => { started.resolve(); return pending.promise; };
  const capture = press(await h.render(), "capture"); await started.promise;
  h.context.process = null; await press(await h.render(), "refresh");
  pending.resolve({ exitCode: 0, stdout: JSON.stringify(dossier("cancelled")) }); await capture;
  assert.match(await details(h), /Capture annulée/);
  assert.doesNotMatch(await details(h), /Snapshot SHA256 : cancelled/);
});

test("a capture cancelled while identity binds retains the prior dossier and baseline", async () => {
  const h = await harness(); await h.command("review");
  h.context.process = async () => ({ exitCode: 0, stdout: JSON.stringify(dossier("original")) });
  await press(await h.render(), "capture");
  const tree = await h.render(), started = deferred(), identity = deferred();
  let calls = 0;
  h.api.session.id = async () => ++calls === 1 ? (started.resolve(), identity.promise) : h.context.id;
  const capture = press(tree, "capture"); await started.promise;
  h.context.process = null; await press(tree, "refresh");
  identity.resolve(h.context.id); await capture;
  const screen = await details(h);
  assert.match(screen, /Capture annulée/);
  assert.match(screen, /Snapshot SHA256 : original/);
  h.context.process = async (_argv, init) => {
    assert.equal(JSON.parse(init.stdin).previous.snapshot_sha256, "original");
    return { exitCode: 0, stdout: JSON.stringify(dossier("rechecked", "unchanged-at-check")) };
  };
  await press(await h.render(), "recheck");
  assert.match(await details(h), /unchanged-at-check/);
});

test("failed or cancelled replacement capture keeps the last dossier until a success commits", async () => {
  const h = await harness(); await h.command("review");
  h.context.process = async () => ({ exitCode: 0, stdout: JSON.stringify(dossier("original")) });
  await press(await h.render(), "capture");
  const started = deferred(), pending = deferred();
  h.context.process = async () => { started.resolve(); return pending.promise; };
  const capture = press(await h.render(), "capture"); await started.promise;
  h.context.process = null; await press(await h.render(), "refresh");
  pending.resolve({ exitCode: 0, stdout: JSON.stringify(dossier("discarded")) }); await capture;
  assert.match(await details(h), /Capture annulée/);
  assert.match(await details(h), /Snapshot SHA256 : original/);
  h.context.process = async () => ({ exitCode: 1, stdout: JSON.stringify({ error: "Base ref unresolvable: mian" }) });
  await press(await h.render(), "capture");
  const screen = await details(h);
  assert.match(screen, /dossier précédent conservé/); assert.match(screen, /Snapshot SHA256 : original/);
  h.context.process = async (_argv, init) => {
    assert.equal(JSON.parse(init.stdin).previous.snapshot_sha256, "original");
    return { exitCode: 0, stdout: JSON.stringify(dossier("unchanged", "unchanged-at-check")) };
  };
  await press(await h.render(), "recheck");
  h.context.process = async (_argv, init) => {
    assert.equal(JSON.parse(init.stdin).previous, undefined);
    return { exitCode: 0, stdout: JSON.stringify(dossier("replacement")) };
  };
  await press(await h.render(), "capture");
  assert.match(await details(h), /Capture de référence SHA256 : replacement/);
});

test("large Unicode journal and proof details have labeled bounded display without altering raw evidence", () => {
  const state = newState(); state.snapshot = projection();
  const detail = { command: "é🙂".repeat(10_000) }, raw = JSON.stringify(detail);
  state.snapshot.journal.items[0].detail = detail; state.tab = "journal";
  const journalLine = viewLines(state).find((line) => line.startsWith('{"command"'));
  assert.ok(Array.from(journalLine).length < 260); assert.match(journalLine, /détail tronqué.*journal/);
  assert.equal(JSON.stringify(detail), raw); assert.doesNotMatch(journalLine, /\ufffd/);
  state.review = { ...dossier("proof"), proofs: [{ sequence: 1, ts: "t", event: "validation_run", binding: "unattested", detail }] };
  state.tab = "review";
  const proofLine = viewLines(state).find((line) => line.startsWith('{"command"'));
  assert.ok(Array.from(proofLine).length < 260); assert.match(proofLine, /détail tronqué.*journal/);
  assert.equal(JSON.stringify(state.review.proofs[0].detail), raw);
  state.review.excerpts = [{ path: "app.mjs", start: 1, end: 1, file_sha256: "file", excerpt_sha256: "excerpt", text: detail.command }];
  const excerptLine = viewLines(state).find((line) => line.startsWith("é"));
  assert.ok(Array.from(excerptLine).length < 260); assert.match(excerptLine, /extrait tronqué.*fichier/);
  assert.equal(state.review.excerpts[0].text, detail.command);
});

test("a delayed snapshot cannot overwrite a newer native measurement", async () => {
  const h = await harness(); await h.command("usage");
  h.context.usage = { context: { tokens: 10 } };
  const started = deferred(), commands = deferred();
  h.api.command.list = async () => { started.resolve(); return commands.promise; };
  const refresh = press(await h.render(), "refresh"); await started.promise;
  await h.raise("session.measure", { context: { tokens: 50 }, cost: { usd: 0 } });
  commands.resolve([]); await refresh;
  assert.match(await details(h), /Contexte : 50/);
  assert.match(await details(h), /Coût déclaré par Claude : 0/);
});

test("late measurement completion cannot replace a later measurement in the same session", async () => {
  const h = await harness(); await h.command("usage");
  const entered = deferred(), next = deferred();
  const old = h.raise("session.measure", { context: { tokens: 11 } }, () => { entered.resolve(); return next.promise; });
  await entered.promise;
  await h.raise("session.measure", { context: { tokens: 22 } });
  next.resolve({ original: "old result" }); assert.deepEqual(await old, { original: "old result" });
  assert.match(await details(h), /Contexte : 22/);
});

test("parent cache order is independent from usage reads and excludes subagents", async () => {
  const h = await harness(); await h.command("usage");
  const started = deferred(), pending = deferred();
  h.context.usage = async () => { started.resolve(); return pending.promise; };
  const old = h.raise("turn.complete", { turnId: "older", usage: { cache_read_input_tokens: 11 } }); await started.promise;
  h.context.usage = { context: { tokens: 22 } };
  await h.raise("turn.complete", { turnId: "newer", usage: { cache_read_input_tokens: 22 } });
  await h.raise("turn.complete", { turnId: "child", agentId: "child", usage: { cache_read_input_tokens: 99 } });
  pending.resolve({ context: { tokens: 11 } }); await old;
  const screen = await details(h);
  assert.match(screen, /Dernier tour principal : newer/);
  assert.match(screen, /Cache lu : 22/); assert.match(screen, /Contexte : 22/);
});

test("a parent usage read after next uses its read order while retaining the parent cache", async () => {
  const h = await harness(); await h.command("usage");
  const entered = deferred(), next = deferred();
  const parent = h.raise("turn.complete", { turnId: "parent", usage: { cache_read_input_tokens: 8 } }, () => { entered.resolve(); return next.promise; });
  await entered.promise;
  await h.raise("session.measure", { context: { tokens: 33 } });
  await h.raise("turn.complete", { agentId: "child", usage: { cache_read_input_tokens: 99 } });
  h.context.usage = { context: { tokens: 44 } }; next.resolve({ original: true }); await parent;
  assert.match(await details(h), /Cache lu : 8/);
  assert.match(await details(h), /Contexte : 44/);
});

test("a UI request while a measurement binds does not discard that measurement", async () => {
  const h = await harness(); await h.command("usage");
  const started = deferred(), identity = deferred(); let calls = 0;
  h.api.session.id = async () => { if (++calls === 1) { started.resolve(); return identity.promise; } return h.context.id; };
  const measurement = h.raise("session.measure", { context: { tokens: 66 } }); await started.promise;
  await press(await h.render(), "refresh");
  identity.resolve(h.context.id); await measurement;
  assert.match(await details(h), /Contexte : 66/);
});

test("null and failed snapshot usage reads keep known telemetry", async () => {
  for (const read of [null, async () => { throw new Error("usage unavailable"); }]) {
    const h = await harness(); await h.command("usage");
    await h.raise("session.measure", { context: { tokens: 77 } }); h.context.usage = read;
    await press(await h.render(), "refresh");
    assert.match(await details(h), /Contexte : 77/);
  }
});

test("recheck uses the original requested ref and preserves its baseline on any failure", async () => {
  const h = await harness(); await h.command("review");
  let tree = await h.render();
  elements(tree).find((e) => e.props.key === "base").props.onInput(" main ");
  h.context.process = async () => ({ exitCode: 0, stdout: JSON.stringify(dossier("original")) });
  await press(tree, "capture"); tree = await h.render();
  elements(tree).find((e) => e.props.key === "base").props.onInput("another-ref");
  for (const error of ["base ref unresolvable: main", "Review metadata exceeds 1 MiB", "bridge unavailable"]) {
    h.context.process = async () => ({ exitCode: 1, stdout: JSON.stringify({ error }) });
    await press(await h.render(), "recheck");
    const request = h.context.calls.at(-1), screen = await details(h);
    assert.equal(request.argv[request.argv.indexOf("--base") + 1], "main");
    assert.equal(JSON.parse(request.init.stdin).previous.snapshot_sha256, "original");
    assert.match(screen, /Dossier : invalidated/); assert.match(screen, /Capture de référence SHA256 : original/);
    assert.ok(screen.includes(error));
  }
});

test("no-baseline recheck refuses silently recapturing and missing-run projections allow diagnosis", async () => {
  const h = await harness(); h.context.snapshot.selection = { run: null, valid: false };
  await h.command("review"); const count = h.context.calls.length;
  await press(await h.render(), "recheck"); assert.equal(h.context.calls.length, count);
  assert.match(await details(h), /Aucun dossier capturé/);
  h.context.process = async (argv) => ({ exitCode: 0, stdout: JSON.stringify(argv[2] === "review"
    ? { ...dossier("no-run"), identity: { ...dossier("no-run").identity, run: null } }
    : { mode: "preflight", ready: false, project_root: "/work", run: null, checks: [] }) });
  await press(await h.render(), "capture"); assert.match(await details(h), /Dossier : captured/);
  await press(await h.render(), "diagnostic"); await press(await h.render(), "preflight");
  assert.match(await details(h), /Diagnostic : preflight/);
});

test("a large patch cannot bury excerpt or proof lines and labels both preview bounds", () => {
  const state = newState(); state.snapshot = projection(); state.tab = "review";
  state.review = { ...dossier("large"), patch: "+line\n".repeat(16000), patch_bytes: 2_000_000,
    patch_preview_bytes: 96000, patch_preview_truncated: true,
    excerpts: [{ path: "app.mjs", start: 1, end: 1, text: "explicit excerpt" }],
    proofs: [{ sequence: 1, ts: "t", event: "validation_run", binding: "unattested", detail: { command: "proof" } }] };
  const lines = viewLines(state), screen = lines.join("\n");
  assert.ok(lines.findIndex((s) => s.includes("explicit excerpt")) < 28);
  assert.ok(lines.findIndex((s) => s.includes("Preuve #1")) < 28);
  assert.match(screen, /Aperçu.*tronqué/i); assert.match(screen, /Affichage.*limité/i);
  assert.ok(lines.length < 100);
});

test("a long file list cannot bury the bounded diff preview", () => {
  const state = newState(); state.snapshot = projection(); state.tab = "review";
  state.review = { ...dossier("files"), patch: "+visible diff\n",
    identity: { ...dossier("files").identity, files: Array.from({ length: 5000 }, (_, index) => ({ path: `file-${index}.mjs`, status: "available", sha256: "hash" })) } };
  const lines = viewLines(state);
  const preview = lines.indexOf("+visible diff"), firstFile = lines.findIndex((line) => line.includes("file-0.mjs"));
  assert.ok(preview >= 0 && preview < 28);
  assert.ok(firstFile > preview);
  assert.equal(lines.filter((line) => line.startsWith("available file-")).length, 5000);
});

test("tool completion stales review and diagnostic after changing or reselecting the same-project run", async () => {
  for (const run of ["other", "run"]) {
    const h = await harness(); await h.command();
    const pending = deferred(), entered = deferred(), result = { original: run };
    const tool = h.raise("tool.call", {}, () => { entered.resolve(); return pending.promise; }); await entered.promise;
    h.context.snapshot = projection(run); await h.command(`run ${run}`);
    h.context.process = async (argv) => ({ exitCode: 0, stdout: JSON.stringify(argv[2] === "review"
      ? { ...dossier("during-tool"), identity: { ...dossier("during-tool").identity, run } }
      : { mode: "preflight", ready: true, project_root: "/work", run, captured_at: "during-tool" }) });
    await press(await h.render(), "review"); await press(await h.render(), "capture");
    assert.match(await details(h), /Fraîcheur du dossier : vérifiée/);
    await press(await h.render(), "diagnostic"); await press(await h.render(), "preflight");
    assert.match(await details(h), /during-tool ; fraîcheur vérifiée/);
    let paints = 0; h.api.ui.invalidate = async () => { paints += 1; };
    pending.resolve(result); assert.equal(await tool, result); assert.equal(paints, 1);
    assert.match(await details(h), /during-tool ; fraîcheur à recontrôler/);
    assert.match(await details(h), /Capture :.*fraîcheur à recontrôler/);
    await press(await h.render(), "review");
    assert.match(await details(h), /Fraîcheur du dossier : à recontrôler/);
  }
});

test("tool completion during a replacement run snapshot remains visible to its freshness fence", async () => {
  const h = await harness(); await h.command();
  const toolPending = deferred(), toolEntered = deferred(), snapshotPending = deferred(), snapshotEntered = deferred();
  const tool = h.raise("tool.call", {}, () => { toolEntered.resolve(); return toolPending.promise; }); await toolEntered.promise;
  h.context.process = async () => { snapshotEntered.resolve(); return snapshotPending.promise; };
  const selection = h.command("run other"); await snapshotEntered.promise;
  toolPending.resolve({ original: true }); await tool;
  snapshotPending.resolve({ exitCode: 0, stdout: JSON.stringify(projection("other")) }); await selection;
  assert.match(await details(h), /Capture :.*fraîcheur à recontrôler/);
});

test("tool completion excludes a newly bound session or cwd and does not repaint it", async () => {
  for (const field of ["id", "cwd"]) {
    const h = await harness(); await h.command();
    const pending = deferred(), entered = deferred();
    const tool = h.raise("tool.call", {}, () => { entered.resolve(); return pending.promise; }); await entered.promise;
    h.context[field] = field === "id" ? "session-b" : "/other";
    await h.command(); let paints = 0; h.api.ui.invalidate = async () => { paints += 1; };
    pending.resolve({ original: true }); await tool;
    assert.equal(paints, 0);
    assert.match(await details(h), /Capture :.*fraîcheur vérifiée uniquement/);
  }
});

test("a tool started before first binding keeps that first scope through run replacement", async () => {
  const h = await harness(), pending = deferred(), entered = deferred();
  const tool = h.raise("tool.call", {}, () => { entered.resolve(); return pending.promise; }); await entered.promise;
  await h.command(); h.context.snapshot = projection("other"); await h.command("run other");
  pending.resolve({ original: true }); await tool;
  assert.match(await details(h), /Capture :.*fraîcheur à recontrôler/);
});

test("unknown-origin activity stales an in-place first bind but does not cross an unbound reset", async () => {
  for (const reset of [false, true]) {
    const h = await harness(), pending = deferred(), entered = deferred();
    const tool = h.raise("tool.call", {}, () => { entered.resolve(); return pending.promise; }); await entered.promise;
    if (reset) await h.raise("command.run", { command: "clear" });
    await h.command(); pending.resolve({ original: true }); await tool;
    assert.match(await details(h), reset
      ? /Capture :.*fraîcheur vérifiée uniquement/ : /Capture :.*fraîcheur à recontrôler/);
  }
});

test("a live cwd change cannot disqualify the tool's still-bound original project", async () => {
  const h = await harness(); await h.command();
  const pending = deferred(), entered = deferred();
  const tool = h.raise("tool.call", {}, () => { entered.resolve(); return pending.promise; }); await entered.promise;
  await h.command("run run"); const tree = await h.render();
  h.context.cwd = "/tool-new-cwd"; pending.resolve({ original: true }); await tool;
  // Keep the old bound pane: rendering would itself bind the new live cwd.
  h.context.cwd = "/work";
  assert.match(await details(h), /Capture :.*fraîcheur à recontrôler/);
  assert.ok(tree);
});

test("tool observations make no identity reads and never await or expose paint failure", async () => {
  for (const paint of [() => { throw new Error("synchronous paint failure"); }, () => Promise.reject(new Error("rejected paint")), () => new Promise(() => {})]) {
    const h = await harness(); await h.command();
    h.api.session.id = () => { throw new Error("tool must not read id"); };
    h.api.session.cwd = () => { throw new Error("tool must not read cwd"); };
    h.api.ui.invalidate = paint;
    let calls = 0, unhandled = 0;
    const listener = () => { unhandled += 1; }; process.on("unhandledRejection", listener);
    const result = { original: "unchanged" }, downstream = new Error("underlying tool failure");
    const promptly = async (promise) => {
      let timer; try { return await Promise.race([promise, new Promise((_, reject) => { timer = setTimeout(() => reject(new Error("observation delayed tool")), 100); })]); }
      finally { clearTimeout(timer); }
    };
    try {
      assert.equal(await promptly(h.raise("tool.call", {}, async () => { calls += 1; return result; })), result);
      await assert.rejects(promptly(h.raise("tool.call", {}, async () => { calls += 1; throw downstream; })), (error) => error === downstream);
      await new Promise(setImmediate); assert.equal(unhandled, 0); assert.equal(calls, 2);
    } finally { process.off("unhandledRejection", listener); }
  }
});

test("summary starts with state and next action while source records remain reachable without rereading", async () => {
  const h = await harness(); await h.command();
  let tree = await h.render();
  const summary = text(tree);
  assert.match(summary, /Travail en cours/);
  assert.ok(summary.indexOf("Prochaine action") < summary.indexOf("Objectif du plan"));
  assert.doesNotMatch(summary, /events\.jsonl|SHA256|route_decided/);
  assert.ok(elements(tree).some((element) => element.props.key === "details" && element.props.hotkey === "d"));
  const reads = h.context.calls.length;
  assert.match(await details(h), /Source : \.workflow\/run\/events\.jsonl/);
  assert.equal(h.context.calls.length, reads, "opening and paging details only changes presentation");
  tree = await h.render(); await press(tree, "routing");
  assert.match(text(await h.render()), /Implémentation/);
  assert.ok(elements(await h.render()).some((element) => element.props.key === "details" && element.props.label.startsWith("Voir")));
});

test("journal summaries show the failed check and preserve its full original record in Details", async () => {
  const h = await harness();
  h.context.snapshot.journal.items[0].detail = { command: "node tests/check.mjs", exit: 2, evidence: "failure receipt" };
  await h.command("journal");
  const summary = text(await h.render());
  assert.match(summary, /Vérification · échec \(2\)/);
  assert.match(summary, /node tests\/check.mjs/);
  assert.doesNotMatch(summary, /"exit":2/);
  assert.match(await details(h), /"exit":2/);
});

test("all overview views leave canonical observations unchanged", () => {
  const state = newState(); state.snapshot = projection();
  const before = JSON.stringify(state.snapshot);
  for (const [tab] of TABS) {
    state.tab = tab;
    const overview = viewOverview(state);
    assert.ok(overview.title && overview.lines.length, tab);
  }
  assert.equal(JSON.stringify(state.snapshot), before);
});

test("summary keeps missing measurements unknown and observed zero visible", () => {
  const state = newState(); state.tab = "usage";
  let summary = viewOverview(state).lines.join("\n");
  assert.match(summary, /Contexte : inconnu/); assert.match(summary, /Cache lu : inconnu/);
  state.usage = { context: { tokens: 0, window: 100, percent: 0 }, cost: { usd: 0 }, rateLimits: [] };
  state.turn = { usage: { input_tokens: 0, output_tokens: 0, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 } };
  summary = viewOverview(state).lines.join("\n");
  assert.match(summary, /Contexte : 0 \/ 100/); assert.match(summary, /Cache lu : 0 tokens/);
  assert.match(summary, /Coût déclaré par Claude : 0 USD/);
  assert.match(summary, /ne mesurent pas le contexte actuel/);
});

test("human checkpoint overview distinguishes historical requests, agreements and unlinked decisions", () => {
  const state = newState(); state.snapshot = projection(); state.tab = "checkpoints";
  state.snapshot.checkpoints.push({ sequence: 2, ts: "t", state: "granted", target: "main", orphan_decision: true });
  const summary = viewOverview(state).lines.join("\n");
  assert.match(summary, /#1 · Demandé/); assert.match(summary, /#2 · Accord enregistré/);
  assert.match(summary, /aucune permission actuelle/); assert.match(summary, /décision sans demande liée/);
  assert.doesNotMatch(summary, /permission actuelle accordée\.$/);
});

test("a stale or unknown diagnostic cannot read as ready and prospective closure names its scope", () => {
  const state = newState(); state.snapshot = projection(); state.tab = "diagnostic";
  state.diagnostic = { mode: "close", captured_at: "time", ready: true };
  assert.equal(viewOverview(state).title, "Résultat à recontrôler");
  state.diagnosticStale = false; state.diagnostic.ready = undefined;
  assert.equal(viewOverview(state).title, "Résultat inconnu");
  state.diagnostic.ready = false; state.diagnostic.checks = [{ name: "node", status: "missing", remediation: "Installer Node" }];
  const summary = viewOverview(state);
  assert.equal(summary.title, "Préconditions manquantes");
  assert.match(summary.lines.join("\n"), /Action : Installer Node/);
  assert.match(summary.lines.join("\n"), /archive et nettoyage non vérifiés/);
});

test("review overview foregrounds invalidation, incomplete files and unattested proof binding", () => {
  const state = newState(); state.snapshot = projection(); state.tab = "review"; state.reviewStale = false;
  state.review = { ...dossier("initial", "invalidated"), complete: false, invalidation_reasons: ["Git base moved"],
    invalidated_files: ["guard.ts"], patch_preview_truncated: true, proofs: [{ revision: null }] };
  let summary = viewOverview(state);
  assert.equal(summary.title, "Dossier invalidé");
  assert.match(summary.lines.join("\n"), /Git base moved|guard.ts/);
  assert.match(summary.lines.join("\n"), /Lecture des fichiers : incomplète/);
  assert.match(summary.lines.join("\n"), /aperçu tronqué/);
  assert.match(summary.lines.join("\n"), /sans révision attestée/);
  assert.match(summary.lines.join("\n"), /aucun verdict de revue/);
  state.review.state = "incomplete";
  assert.equal(viewOverview(state).title, "Dossier incomplet");
});

test("skill overview prioritizes current scope without hiding unavailable sources or disabled overrides", () => {
  const state = newState(); state.snapshot = projection(); state.tab = "skills";
  state.overrides = { review: "off" };
  state.snapshot.skills.items[0].available = false;
  state.snapshot.skills.items.push({ name: "other", scope: "forest", scope_active: false, available: true });
  state.snapshot.skills.items.push({ name: "unobserved", scope: "shared", source: "claude" });
  const summary = viewOverview(state).lines.join("\n");
  assert.match(summary, /source indisponible.*désactivé/);
  assert.match(summary, /source inconnue.*périmètre inconnu/);
  assert.match(summary, /hors périmètre, accessibles dans Détails/);
  assert.doesNotMatch(summary, /other ·/);
  assert.match(viewLines(state).join("\n"), /other/);
});

test("narrow paging retains long records and wide Unicode without broken surrogate pairs", () => {
  const lines = ["Action : Relire le changement avant de poursuivre la validation.", "哈".repeat(80), "🧪".repeat(20), "a".repeat(200)];
  const pages = pageContent(lines, 0, 32, 7).pages;
  const shown = Array.from({ length: pages }, (_, page) => pageContent(lines, page, 32, 7).lines).flat();
  assert.equal(shown.join("").replace(/\s/g, ""), lines.join("").replace(/\s/g, ""));
  assert.ok(shown.every((line) => Array.from(line).reduce((width, character) => width + (character.codePointAt(0) >= 0x2e80 ? 2 : 1), 0) <= 32));
  assert.doesNotMatch(shown.join(""), /\ufffd/);
  assert.equal(pageContent(lines, 999, 32, 7).page, pages - 1);
});

test("summary clipping is explicit while complete next action remains available in Details", () => {
  const state = newState(); state.snapshot = projection();
  state.snapshot.resume.next_action = "Action importante ".repeat(40);
  assert.match(viewOverview(state).lines.join("\n"), /… \(Détails\)/);
  assert.ok(viewLines(state).some((line) => line.includes(state.snapshot.resume.next_action)));
  assert.equal(captureTime(undefined), "inconnue");
  assert.equal(captureTime("unobserved timestamp"), "unobserved timestamp");
  assert.match(eventSummary({ sequence: 1, event: "adversary_completed", detail: { verdict: "BLOCK" } }).join("\n"), /bloqué/);
});

test("critical review status stays visible through detail pagination", async () => {
  const h = await harness(); await h.command("review");
  h.context.process = async () => ({ exitCode: 0, stdout: JSON.stringify({ ...dossier("old", "invalidated"),
    invalidation_reasons: ["Revision changed"], patch: "line\n".repeat(100) }), stderr: "" });
  await press(await h.render(), "capture");
  let tree = await h.render(); assert.match(text(tree), /Dossier invalidé/);
  await press(tree, "details"); tree = await h.render(); await press(tree, "next");
  assert.match(text(await h.render()), /Dossier invalidé/);
});

test("known diagnostic and invalidation codes have a human explanation while Details retains exact evidence", () => {
  const state = newState(); state.snapshot = projection(); state.tab = "diagnostic"; state.diagnosticStale = false;
  state.diagnostic = { mode: "close", ready: false, error: "profile autonomous-completed missing adversary_completed",
    remediation: "Use scripts/workflow-event validate for evidence details" };
  assert.match(viewOverview(state).lines.join("\n"), /Étape manquante : Revue contradictoire/);
  assert.match(viewLines(state).join("\n"), /profile autonomous-completed missing adversary_completed/);
  state.tab = "review"; state.review = { ...dossier("old", "invalidated"), invalidation_reasons: ["snapshot_sha256 changed"] };
  assert.match(viewOverview(state).lines.join("\n"), /ne correspond plus à la capture de référence/);
  assert.match(viewLines(state).join("\n"), /snapshot_sha256 changed/);
  state.review.invalidation_reasons = ["Unknown external failure"];
  assert.match(viewOverview(state).lines.join("\n"), /Unknown external failure/);
});
