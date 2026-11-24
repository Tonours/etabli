/**
 * Fabricated Claude Code transcripts for tests/claude-usage-audit.test.mjs.
 * Nothing here comes from a real machine; MARKER must never reach the audit output.
 * The cli session streams message a2 twice (counted once, larger output kept),
 * carries a synthetic turn, an out-of-window turn, one malformed line, then a
 * JSON null line followed by a valid turn that must still count; that turn's Agent
 * calls carry an unknown type and model, which must print only as fixed classes. Subagent sub2
 * mixes Opus and Sonnet turns, one with a non-numeric token count. The sdk
 * session carries a non-string cwd, tool name and timestamp, two non-object usages,
 * Bash commands built to tempt a command-word parser (assignments, substitutions,
 * quotes), one rtk call behind cd and an assignment, two that only mention rtk inside a value, and a model named
 * like an Object property; none may drop later turns. A Bash call just before the
 * window returns inside it and must keep its bucket; an older Bash call with a
 * non-string command must not drop later rows. sess-resumed started before the
 * window: its in-window turn is not a first turn, and its effort is not a string. Its subagent
 * starts just inside the window: the parent's model comes from a turn before it. agent-locked's
 * meta file is made unreadable by the test. sess-stale's file was last written before the window,
 * yet its in-window subagent still finds the parent's model. b-split streams one cache write
 * unsplit, then split into the 1h bucket: it counts once, in 1h.
 * Two files without session ids are two sessions: the old one never marks the new one resumed.
 * MARKER also sits in printed metadata (model, effort, entrypoint, compaction trigger, meta
 * agentType and model, tool name): each must print as a class. The cli session switches to
 * Sonnet just before its subagents start, and a main-file tool_result answers a tool_use made
 * in a subagent file, so attribution cannot depend on file order.
 * The new one also carries a non-string compaction trigger and two id-less turns,
 * which cannot be deduplicated and count as parse errors, not turns.
 */
import { mkdirSync, utimesSync, writeFileSync } from "node:fs";
import { join } from "node:path";

export const MARKER = "FABRICATED_CONTENT_MARKER";

const usage = (input, cacheRead, write1h, output) => ({
  input_tokens: input,
  cache_read_input_tokens: cacheRead,
  cache_creation_input_tokens: write1h,
  cache_creation: { ephemeral_1h_input_tokens: write1h, ephemeral_5m_input_tokens: 0 },
  output_tokens: output,
});

function assistant({ sid, ts, id, model = "claude-opus-5-5", u, content = [], extra = {} }) {
  return { type: "assistant", sessionId: sid, timestamp: ts, requestId: `req-${id}`, uuid: `u-${id}`, cwd: "/tmp/fabricated-project", message: { id: `msg-${id}`, model, usage: u, content }, ...extra };
}

function toolResult({ sid, ts, uuid, toolUseId, chars }) {
  return { type: "user", sessionId: sid, timestamp: ts, uuid, message: { content: [{ type: "tool_result", tool_use_id: toolUseId, content: `${MARKER} ${"x".repeat(chars - MARKER.length - 1)}` }] } };
}

const jsonl = (rows) => rows.map((row) => (typeof row === "string" ? row : JSON.stringify(row))).join("\n") + "\n";

export function writeFixture(dir, now = Date.now()) {
  const at = (minutesAgo) => new Date(now - minutesAgo * 60e3).toISOString();
  const project = join(dir, "projects", "-tmp-fabricated-project");
  mkdirSync(join(project, "sess-cli", "subagents"), { recursive: true });

  const bashSizes = [4000, 4001, 15000, 15001, 200000];
  const cli = [
    { type: "user", sessionId: "sess-cli", timestamp: at(60), uuid: "u-first", entrypoint: "cli", cwd: "/tmp/fabricated-project", message: { content: `${MARKER} user prompt` } },
    assistant({ sid: "sess-cli", ts: at(59), id: "a1", u: usage(10, 0, 20000, 100), extra: { entrypoint: "cli" }, content: [{ type: "text", text: `${MARKER} assistant text` }, ...bashSizes.map((_, i) => ({ type: "tool_use", id: `bash-${i}`, name: "Bash", input: { command: `cat ${MARKER}-${i}.txt` } }))] }),
    ...bashSizes.map((chars, i) => toolResult({ sid: "sess-cli", ts: at(58), uuid: `u-res-${i}`, toolUseId: `bash-${i}`, chars })),
    assistant({ sid: "sess-cli", ts: at(57), id: "a2", u: usage(5, 20000, 1000, 50), content: [{ type: "tool_use", id: "agent-0", name: "Agent", input: { subagent_type: "general-purpose", prompt: `${MARKER} agent prompt` } }] }),
    assistant({ sid: "sess-cli", ts: at(57), id: "a2", u: usage(5, 20000, 1000, 80) }),
    assistant({ sid: "sess-cli", ts: at(56.5), id: "a-switch", model: "claude-sonnet-5-5", u: usage(1, 0, 0, 1) }),
    assistant({ sid: "sess-cli", ts: at(56), id: "a3", model: "<synthetic>", u: usage(1, 0, 0, 1) }),
    toolResult({ sid: "sess-cli", ts: at(55), uuid: "u-res-subread", toolUseId: "sub-read", chars: 40 }),
    `{"type":"assistant", ${MARKER} not json`,
    "null",
    assistant({ sid: "sess-cli", ts: at(50), id: "a4", u: usage(1, 0, 0, 7), content: [{ type: "tool_use", id: "agent-1", name: "Agent", input: { subagent_type: `unknown\n${MARKER}`, model: `${MARKER}-model` } }, { type: "tool_use", id: "agent-2", name: "Task", input: { subagent_type: "general-purpose", model: "claude-sonnet-5-5" } }] }),
  ];
  writeFileSync(join(project, "sess-cli.jsonl"), jsonl(cli));

  writeFileSync(join(project, "sess-cli", "subagents", "agent-sub1.jsonl"), jsonl([
    assistant({ sid: "sess-cli", ts: at(56), id: "s1", model: "claude-sonnet-5-5", u: usage(10, 0, 8000, 40), extra: { isSidechain: true }, content: [{ type: "tool_use", id: "sub-read", name: "Read", input: {} }] }),
    assistant({ sid: "sess-cli", ts: at(55), id: "s2", model: "claude-sonnet-5-5", u: usage(10, 8000, 500, 40), extra: { isSidechain: true } }),
  ]));
  writeFileSync(join(project, "sess-cli", "subagents", "agent-sub1.meta.json"), JSON.stringify({ agentType: "general-purpose" }));
  writeFileSync(join(project, "sess-cli", "subagents", "agent-sub2.meta.json"), JSON.stringify({ agentType: `${MARKER} type`, model: MARKER }));
  writeFileSync(join(project, "sess-cli", "subagents", "agent-sub2.jsonl"), jsonl([
    assistant({ sid: "sess-cli", ts: at(55), id: "s3", model: "claude-opus-5-5", u: usage(10, 0, 3000, 10), extra: { isSidechain: true } }),
    assistant({ sid: "sess-cli", ts: at(54), id: "s4", model: "claude-sonnet-5-5", u: { ...usage(0, 3000, 0, 5), input_tokens: MARKER }, extra: { isSidechain: true } }),
  ]));

  writeFileSync(join(project, "sess-resumed.jsonl"), jsonl([
    assistant({ sid: "sess-resumed", ts: new Date(now - 8 * 86400e3).toISOString(), id: "r0", u: usage(1, 0, 15000, 1), extra: { entrypoint: "cli" } }),
    assistant({ sid: "sess-resumed", ts: new Date(now - 30 * 86400e3).toISOString(), id: "old", u: usage(999, 0, 0, 999) }),
    assistant({ sid: "sess-resumed", ts: at(7 * 1440 + 60), id: "early", u: usage(1, 0, 0, 1), content: [{ type: "tool_use", id: "bash-early", name: "Bash", input: { command: "ls" } }] }),
    toolResult({ sid: "sess-resumed", ts: at(7 * 1440 - 60), uuid: "u-res-early", toolUseId: "bash-early", chars: 30000 }),
    { type: "assistant", sessionId: "sess-resumed", timestamp: at(8 * 1440), message: { id: "msg-oddcmd", content: [{ type: "tool_use", id: "bash-odd", name: "Bash", input: { command: { toString: null } } }] } },
    assistant({ sid: "sess-resumed", ts: at(20), id: "r1", u: usage(1, 90000, 0, 3), extra: { perTurnEffort: { toString: null } } }),
  ]));

  mkdirSync(join(project, "sess-resumed", "subagents"), { recursive: true });
  writeFileSync(join(project, "sess-resumed", "subagents", "agent-late.meta.json"), JSON.stringify({ agentType: "late-start" }));
  writeFileSync(join(project, "sess-resumed", "subagents", "agent-late.jsonl"), jsonl([
    assistant({ sid: "sess-resumed", ts: at(7 * 1440 - 30), id: "l1", model: "claude-opus-5-5", u: usage(0, 0, 0, 1), extra: { isSidechain: true } }),
  ]));
  writeFileSync(join(project, "sess-cli", "subagents", "agent-locked.jsonl"), jsonl([]));
  writeFileSync(join(project, "sess-cli", "subagents", "agent-locked.meta.json"), "{}");
  const stale = new Date(now - 8 * 86400e3);
  writeFileSync(join(project, "sess-stale.jsonl"), jsonl([
    assistant({ sid: "sess-stale", ts: stale.toISOString(), id: "st0", model: "claude-opus-5-5", u: usage(0, 0, 0, 1) }),
  ]));
  utimesSync(join(project, "sess-stale.jsonl"), stale, stale);
  mkdirSync(join(project, "sess-stale", "subagents"), { recursive: true });
  writeFileSync(join(project, "sess-stale", "subagents", "agent-stale.meta.json"), JSON.stringify({ agentType: "stale-parent" }));
  writeFileSync(join(project, "sess-stale", "subagents", "agent-stale.jsonl"), jsonl([
    assistant({ sid: "sess-stale", ts: at(30), id: "sa1", model: "claude-opus-5-5", u: usage(0, 0, 0, 1), extra: { isSidechain: true } }),
  ]));

  writeFileSync(join(project, "nosid-old.jsonl"), jsonl([
    { type: "user", timestamp: new Date(now - 9 * 86400e3).toISOString(), uuid: "u-nosid-old", message: { content: "x" } },
  ]));
  writeFileSync(join(project, "nosid-new.jsonl"), jsonl([
    { type: "assistant", timestamp: at(10), requestId: "req-n1", uuid: "u-n1", entrypoint: MARKER, message: { id: "msg-n1", model: "claude-opus-5-5", usage: usage(1, 0, 5000, 4) } },
    { type: "system", subtype: "compact_boundary", timestamp: at(9), uuid: "u-cb", compactMetadata: { trigger: { toString: null } } },
    { type: "system", subtype: "compact_boundary", timestamp: at(9), uuid: "u-cb2", compactMetadata: { trigger: MARKER } },
    { type: "assistant", timestamp: at(8), message: { model: "claude-opus-5-5", usage: usage(1, 0, 0, 6) } },
    { type: "assistant", timestamp: at(7), message: { model: "claude-opus-5-5", usage: usage(1, 0, 0, 6) } },
  ]));

  writeFileSync(join(project, "sess-sdk.jsonl"), jsonl([
    assistant({ sid: "sess-sdk", ts: at(30), id: "b1", model: "claude-sonnet-5-5", u: usage(10, 0, 40000, 20), extra: { entrypoint: "sdk-cli", cwd: 17 }, content: [{ type: "tool_use", id: "odd-0", name: ["mcp__fake__tool"], input: {} }, { type: "tool_use", id: "odd-1", name: `${MARKER} tool`, input: {} }] }),
    toolResult({ sid: "sess-sdk", ts: at(29), uuid: "u-odd-res", toolUseId: "odd-0", chars: 100 }),
    toolResult({ sid: "sess-sdk", ts: at(29), uuid: "u-odd1-res", toolUseId: "odd-1", chars: 100 }),
    assistant({ sid: "sess-sdk", ts: at(29), id: "b-falsy", model: "claude-sonnet-5-5", u: 0 }),
    assistant({ sid: "sess-sdk", ts: at(29), id: "b-assign", model: "claude-sonnet-5-5", u: "invalid", content: [{ type: "tool_use", id: "bash-assign", name: "Bash", input: { command: `API_TOKEN=x/${MARKER}` } }, { type: "tool_use", id: "bash-path", name: "Bash", input: { command: `$(cat ${MARKER})` } }] }),
    toolResult({ sid: "sess-sdk", ts: at(29), uuid: "u-assign-res", toolUseId: "bash-assign", chars: 40 }),
    toolResult({ sid: "sess-sdk", ts: at(29), uuid: "u-path-res", toolUseId: "bash-path", chars: 40 }),
    assistant({ sid: "sess-sdk", ts: at(29), id: "b-escaped", model: "claude-sonnet-5-5", u: null, content: [{ type: "tool_use", id: "bash-escaped", name: "Bash", input: { command: `export TOKEN=part1\\ rtk ls` } }] }),
    toolResult({ sid: "sess-sdk", ts: at(29), uuid: "u-escaped-res", toolUseId: "bash-escaped", chars: 40 }),
    assistant({ sid: "sess-sdk", ts: at(29), id: "b-subst", model: "claude-sonnet-5-5", u: null, content: [{ type: "tool_use", id: "bash-subst", name: "Bash", input: { command: "export LABEL=$(echo git )" } }, { type: "tool_use", id: "bash-cdsubst", name: "Bash", input: { command: "cd $(echo /tmp) && git status" } }, { type: "tool_use", id: "bash-cdquote", name: "Bash", input: { command: 'cd foo";"echo' } }, { type: "tool_use", id: "bash-ifs", name: "Bash", input: { command: "$(echo${IFS}/git )" } }, { type: "tool_use", id: "bash-rtk", name: "Bash", input: { command: "cd /tmp && FOO=1 rtk git status" } }, { type: "tool_use", id: "bash-notrtk", name: "Bash", input: { command: "export LABEL=$(echo rtk status)" } }] }),
    toolResult({ sid: "sess-sdk", ts: at(29), uuid: "u-subst-res", toolUseId: "bash-subst", chars: 40 }),
    toolResult({ sid: "sess-sdk", ts: at(29), uuid: "u-cdsubst-res", toolUseId: "bash-cdsubst", chars: 40 }),
    toolResult({ sid: "sess-sdk", ts: at(29), uuid: "u-cdquote-res", toolUseId: "bash-cdquote", chars: 40 }),
    toolResult({ sid: "sess-sdk", ts: at(29), uuid: "u-ifs-res", toolUseId: "bash-ifs", chars: 40 }),
    toolResult({ sid: "sess-sdk", ts: at(29), uuid: "u-rtk-res", toolUseId: "bash-rtk", chars: 40 }),
    toolResult({ sid: "sess-sdk", ts: at(29), uuid: "u-notrtk-res", toolUseId: "bash-notrtk", chars: 40 }),
    { type: "assistant", sessionId: "sess-sdk", timestamp: { toString: null }, message: { id: "msg-badts", model: "claude-sonnet-5-5", usage: usage(1, 0, 0, 1) } },
    assistant({ sid: "sess-sdk", ts: at(28), id: "b-split", model: "claude-sonnet-5-5", u: { input_tokens: 0, cache_creation_input_tokens: 10000, cache_read_input_tokens: 0, output_tokens: 1 } }),
    assistant({ sid: "sess-sdk", ts: at(28), id: "b-split", model: "claude-sonnet-5-5", u: usage(0, 0, 10000, 1) }),
    assistant({ sid: "sess-sdk", ts: at(28), id: "b3", model: "constructor", u: usage(1, 0, 0, 2), extra: { effort: MARKER } }),
    assistant({ sid: "sess-sdk", ts: at(29), id: "b2", model: "claude-sonnet-5-5", u: usage(10, 40000, 220000, 20) }),
  ]));

  return {
    // Counted turns: cli a1 a2 a-switch a4, subagents s1..s4, l1 and sa1, b-split, resumed r1, nosid n1, sdk b1 b3 b2.
    totalOutput: 100 + 80 + 1 + 7 + 40 + 40 + 10 + 5 + 3 + 4 + 20 + 2 + 20 + 1 + 1 + 1,
    totalInput: 10 + 5 + 1 + 1 + 10 + 10 + 10 + 0 + 1 + 1 + 10 + 1 + 10 + 0 + 0 + 0,
    // malformed json, null line, timestamp object, b-falsy, b-assign, two id-less turns, trigger object.
    parseErrors: 8,
    bashResultChars: [...bashSizes, 30000, 40, 40, 40, 40, 40, 40, 40, 40, 40].reduce((a, b) => a + b, 0),
    mainTurns: 10,
    subagentTurns: 6,
    firstTurnCtx: { cli: 20010, "sdk-cli": 40010 },
  };
}

/**
 * j_carriedVsUsed fixture. c1 (cli) carries Read twice by snapshot and once by deferred delta, Bash,
 * WebSearch, one server by tool name and another by instruction display name and tool name, and two
 * agent types; it calls Read three times (one streamed twice), the server, and three Agent types.
 * c2 (cli) carries Read, an invalid name and Explore, plus a sidechain snapshot naming NotebookEdit.
 * c3 (sdk-cli) has a snapshot without tools. old started before the window and calls Glob inside it.
 * c1's subagent calls Grep under c1's id; its own snapshot is not carried. gaps holds the A10 lines.
 * MARKER sits in a tool description and schema, an addedBlocks entry and an addedLines entry.
 */
export function writeCarriedFixture(dir, now = Date.now()) {
  const at = (minutesAgo) => new Date(now - minutesAgo * 60e3).toISOString();
  const project = join(dir, "projects", "-tmp-carried");
  mkdirSync(join(project, "c1", "subagents"), { recursive: true });
  const att = (sid, ts, attachment, extra = {}) => ({ type: "attachment", sessionId: sid, timestamp: ts, attachment, ...extra });
  const call = (id, name, input = {}) => ({ type: "tool_use", id, name, input });
  const turn = (sid, ts, id, content, extra = {}) => ({ type: "assistant", sessionId: sid, timestamp: ts, uuid: `u-${id}`, message: { id: `msg-${id}`, content }, ...extra });
  const user = (sid, ts, entrypoint) => ({ type: "user", sessionId: sid, timestamp: ts, uuid: `u-${sid}-first`, entrypoint, message: { content: `${MARKER} prompt` } });

  writeFileSync(join(project, "c1.jsonl"), jsonl([
    user("c1", at(60), "cli"),
    att("c1", at(60), { type: "prompt_snapshot", tools: [{ name: "Read", description: `${MARKER} description`, schema: { note: MARKER } }, { name: "Bash" }, { name: "mcp__srv_one__do" }] }),
    att("c1", at(59), { type: "prompt_snapshot", tools: [{ name: "Read" }] }),
    att("c1", at(59), { type: "deferred_tools_delta", addedNames: ["Read", "WebSearch", "mcp__claude_ai_Foo_Bar__x"], addedLines: [`${MARKER} line`] }),
    att("c1", at(59), { type: "mcp_instructions_delta", addedNames: ["claude.ai Foo Bar"], addedBlocks: [`${MARKER} block`] }),
    att("c1", at(59), { type: "agent_listing_delta", addedTypes: ["Explore", "general-purpose"], builtInTypes: ["Explore", "general-purpose"] }),
    turn("c1", at(58), "t1", [call("r1", "Read"), call("r2", "Read"), call("m1", "mcp__claude_ai_Foo_Bar__x")]),
    turn("c1", at(58), "t1", [call("r1", "Read")]),
    turn("c1", at(57), "t2", [call("r3", "Read"), call("ag1", "Agent", { subagent_type: "general-purpose" }), call("ag2", "Agent", { subagent_type: "reviewer" }), call("ag3", "Agent", { subagent_type: `${MARKER}-type` })]),
  ]));
  writeFileSync(join(project, "c1", "subagents", "agent-s1.jsonl"), jsonl([
    att("c1", at(50), { type: "prompt_snapshot", tools: [{ name: "Grep" }] }, { isSidechain: true }),
    turn("c1", at(50), "s1", [call("gr1", "Grep")], { isSidechain: true }),
  ]));
  writeFileSync(join(project, "c1", "subagents", "agent-s1.meta.json"), JSON.stringify({ agentType: "reviewer" }));
  writeFileSync(join(project, "c2.jsonl"), jsonl([
    user("c2", at(45), "cli"),
    att("c2", at(45), { type: "prompt_snapshot", tools: [{ name: "Read" }, { name: `${MARKER} bad name` }, { name: `mcp__${MARKER} bad name__x` }] }),
    att("c2", at(45), { type: "agent_listing_delta", addedTypes: ["Explore"] }),
    att("c2", at(45), { type: "deferred_tools_delta", addedNames: ["mcp__claude_ai_Baz_Qux__y"] }),
    att("c2", at(45), { type: "mcp_instructions_delta", addedNames: ["claude.ai Baz (Qux)", "team  tools"] }),
    att("c2", at(45), { type: "deferred_tools_delta", addedNames: ["mcp__team__tools__search"] }),
    att("c2", at(44), { type: "prompt_snapshot", tools: [{ name: "NotebookEdit" }] }, { isSidechain: true }),
    turn("c2", at(43), "t3", [call("ag4", "Agent", { subagent_type: "Plan" })]),
  ]));
  // Same agent file name as c1's: each meta file still names its own type.
  mkdirSync(join(project, "c2", "subagents"), { recursive: true });
  writeFileSync(join(project, "c2", "subagents", "agent-s1.jsonl"), jsonl([{ type: "user", sessionId: "c2", isSidechain: true, timestamp: at(43) }]));
  writeFileSync(join(project, "c2", "subagents", "agent-s1.meta.json"), JSON.stringify({ agentType: "Plan" }));
  // A session whose first line is two hours in the future never counts as started.
  writeFileSync(join(project, "future.jsonl"), jsonl([user("future", at(-120), "cli")]));
  writeFileSync(join(project, "c3.jsonl"), jsonl([
    user("c3", at(40), "sdk-cli"),
    att("c3", at(40), { type: "prompt_snapshot" }),
    att("c3", at(40), { type: "prompt_snapshot", tools: [] }),
  ]));
  writeFileSync(join(project, "old.jsonl"), jsonl([
    user("old", at(8 * 1440), "cli"),
    att("old", at(8 * 1440), { type: "prompt_snapshot", tools: [{ name: "Glob" }] }),
    turn("old", at(10), "o1", [call("g1", "Glob")]),
  ]));
  writeFileSync(join(project, "gaps.jsonl"), jsonl([
    `{"type":"user","sessionId":"gaps","timest`,
    { type: "assistant", sessionId: "gaps", timestamp: 123, message: { id: "msg-num", content: [] } },
    { type: "assistant", sessionId: "gaps", message: { id: "msg-nots", content: [call("n1", "Edit")] } },
    { type: "assistant", sessionId: "gaps", timestamp: "x", message: { id: "msg-badts", content: [call("n2", "Edit")] } },
    { type: "assistant", sessionId: "gaps", timestamp: at(5), message: { usage: usage(1, 0, 0, 1), content: [call("w1", "Write")] } },
  ]));
}

/** One tool_use id at 8 days and at 1 day before the run, in two main files; `oldInA` swaps them. */
export function writeDuplicateCallFixture(dir, oldInA, now = Date.now(), fork = false) {
  const at = (minutesAgo) => new Date(now - minutesAgo * 60e3).toISOString();
  const project = join(dir, "projects", "-tmp-dup");
  mkdirSync(project, { recursive: true });
  const line = (sid, minutesAgo) => ({ type: "assistant", sessionId: sid, timestamp: at(minutesAgo), uuid: `u-${sid}`, message: { id: `msg-${sid}`, content: [{ type: "tool_use", id: "dup-1", name: "Explore" }] } });
  // fork: the same call in two in-window sessions, fork-1 (cli) and fork-2 (no entrypoint), swapped between files.
  // Not fork: the 8-day copy sits in dup-a.jsonl when oldInA, else in dup-b.jsonl.
  const [a, b] = fork
    ? [[{ type: "user", sessionId: "fork-1", entrypoint: "cli", timestamp: at(60) }, line("fork-1", 60)], [line("fork-2", 30)]]
    : [[line("old", 8 * 1440)], [line("new", 1440)]];
  writeFileSync(join(project, "dup-a.jsonl"), jsonl(oldInA ? a : b));
  writeFileSync(join(project, "dup-b.jsonl"), jsonl(oldInA ? b : a));
}
