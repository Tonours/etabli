/**
 * Fabricated Claude Code transcripts for tests/claude-usage-audit.test.mjs.
 * Nothing here comes from a real machine; MARKER must never reach the audit output.
 * The cli session streams message a2 twice (counted once, larger output kept),
 * carries a synthetic turn, an out-of-window turn, one malformed line, then a
 * JSON null line followed by a valid turn that must still count. Subagent sub2
 * mixes Opus and Sonnet turns, one with a non-numeric token count. The sdk
 * session carries a non-string cwd, tool name and timestamp and a model named
 * like an Object property; none may drop later turns. A Bash call just before the
 * window returns inside it and must keep its bucket; an older Bash call with a
 * non-string command must not drop later rows. sess-resumed started before the
 * window: its in-window turn is not a first turn, and its effort is not a string.
 */
import { mkdirSync, writeFileSync } from "node:fs";
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
    assistant({ sid: "sess-cli", ts: at(56), id: "a3", model: "<synthetic>", u: usage(1, 0, 0, 1) }),
    `{"type":"assistant", ${MARKER} not json`,
    "null",
    assistant({ sid: "sess-cli", ts: at(50), id: "a4", u: usage(1, 0, 0, 7) }),
  ];
  writeFileSync(join(project, "sess-cli.jsonl"), jsonl(cli));

  writeFileSync(join(project, "sess-cli", "subagents", "agent-sub1.jsonl"), jsonl([
    assistant({ sid: "sess-cli", ts: at(56), id: "s1", model: "claude-sonnet-5-5", u: usage(10, 0, 8000, 40), extra: { isSidechain: true } }),
    assistant({ sid: "sess-cli", ts: at(55), id: "s2", model: "claude-sonnet-5-5", u: usage(10, 8000, 500, 40), extra: { isSidechain: true } }),
  ]));
  writeFileSync(join(project, "sess-cli", "subagents", "agent-sub1.meta.json"), JSON.stringify({ agentType: "general-purpose" }));
  writeFileSync(join(project, "sess-cli", "subagents", "agent-sub2.jsonl"), jsonl([
    assistant({ sid: "sess-cli", ts: at(55), id: "s3", model: "claude-opus-5-5", u: usage(10, 0, 3000, 10), extra: { isSidechain: true } }),
    assistant({ sid: "sess-cli", ts: at(54), id: "s4", model: "claude-sonnet-5-5", u: { ...usage(0, 3000, 0, 5), input_tokens: MARKER }, extra: { isSidechain: true } }),
  ]));

  writeFileSync(join(project, "sess-resumed.jsonl"), jsonl([
    assistant({ sid: "sess-resumed", ts: new Date(now - 8 * 86400e3).toISOString(), id: "r0", u: usage(1, 0, 15000, 1), extra: { entrypoint: "cli" } }),
    assistant({ sid: "sess-resumed", ts: new Date(now - 30 * 86400e3).toISOString(), id: "old", u: usage(999, 0, 0, 999) }),
    assistant({ sid: "sess-resumed", ts: at(7 * 1440 + 1), id: "early", u: usage(1, 0, 0, 1), content: [{ type: "tool_use", id: "bash-early", name: "Bash", input: { command: "ls" } }] }),
    toolResult({ sid: "sess-resumed", ts: at(7 * 1440 - 1), uuid: "u-res-early", toolUseId: "bash-early", chars: 30000 }),
    { type: "assistant", sessionId: "sess-resumed", timestamp: at(8 * 1440), message: { id: "msg-oddcmd", content: [{ type: "tool_use", id: "bash-odd", name: "Bash", input: { command: { toString: null } } }] } },
    assistant({ sid: "sess-resumed", ts: at(20), id: "r1", u: usage(1, 90000, 0, 3), extra: { perTurnEffort: { toString: null } } }),
  ]));

  writeFileSync(join(project, "sess-sdk.jsonl"), jsonl([
    assistant({ sid: "sess-sdk", ts: at(30), id: "b1", model: "claude-sonnet-5-5", u: usage(10, 0, 40000, 20), extra: { entrypoint: "sdk-cli", cwd: 17 }, content: [{ type: "tool_use", id: "odd-0", name: ["mcp__fake__tool"], input: {} }] }),
    toolResult({ sid: "sess-sdk", ts: at(29), uuid: "u-odd-res", toolUseId: "odd-0", chars: 100 }),
    { type: "assistant", sessionId: "sess-sdk", timestamp: { toString: null }, message: { id: "msg-badts", model: "claude-sonnet-5-5", usage: usage(1, 0, 0, 1) } },
    assistant({ sid: "sess-sdk", ts: at(28), id: "b3", model: "constructor", u: usage(1, 0, 0, 2) }),
    assistant({ sid: "sess-sdk", ts: at(29), id: "b2", model: "claude-sonnet-5-5", u: usage(10, 40000, 220000, 20) }),
  ]));

  return {
    bashSizes,
    bashResultChars: [...bashSizes, 30000].reduce((a, b) => a + b, 0),
    mainTurns: 7,
    subagentTurns: 4,
    firstTurnCtx: { cli: 20010, "sdk-cli": 40010 },
  };
}
