import { expect, test } from "bun:test";
import { BLOCK_LIMIT, CLIP_AT, CLIP_KEEP, clip, entryBlock, excerpt, queued, type Entry } from "../web-src/activity.ts";
import { A, harness } from "./web-harness.ts";

const said = (id: number, text = `step ${id}`): Entry => ({ id, model: [{ role: "assistant", content: text }] });
const range = (from: number, to: number) => Array.from({ length: to - from + 1 }, (_, index) => said(from + index));

async function watching() {
  const h = harness();
  await h.signIn();
  h.store.route(`#${A}`);
  return h;
}

test("the same frame applied twice adds its entries once", async () => {
  const h = await watching();
  const frame = { entries: [said(1), said(2)] };
  h.store.applyFrame(frame);
  h.store.applyFrame(frame);
  expect(h.store.get().activity.blocks.map((block) => block.id)).toEqual(["entry-1", "entry-2"]);
});

test("following trims to the last 300 blocks; reading earlier keeps them until following again", async () => {
  const h = await watching();
  h.store.applyFrame({ entries: range(1, BLOCK_LIMIT + 1) });
  let activity = h.store.get().activity;
  expect([activity.blocks.length, activity.blocks[0]!.id, activity.omitted]).toEqual([BLOCK_LIMIT, "entry-2", true]);
  h.store.follow(false, 120);
  h.store.applyFrame({ entries: [said(BLOCK_LIMIT + 2)] });
  activity = h.store.get().activity;
  expect([activity.blocks.length, activity.blocks[0]!.id, activity.offset]).toEqual([BLOCK_LIMIT + 1, "entry-2", 120]);
  h.store.follow(true, 0);
  activity = h.store.get().activity;
  expect([activity.blocks.length, activity.blocks[0]!.id, activity.follow]).toEqual([BLOCK_LIMIT, "entry-3", true]);
});

test("exactly 300 blocks are kept whole", async () => {
  const h = await watching();
  h.store.applyFrame({ entries: range(1, BLOCK_LIMIT) });
  expect([h.store.get().activity.blocks.length, h.store.get().activity.omitted]).toEqual([BLOCK_LIMIT, false]);
});

test("a window starting after the last seen entry adds a gap marker; a first window marks earlier activity omitted", async () => {
  const h = await watching();
  h.store.applyFrame({ entries: [said(5)], before: 4 });
  expect([h.store.get().activity.omitted, h.store.get().activity.blocks.some((block) => block.gap)]).toEqual([true, false]);
  h.store.applyFrame({ entries: [said(6)], before: 5 });
  expect(h.store.get().activity.blocks.some((block) => block.gap)).toBe(false);
  h.store.applyFrame({ entries: [said(9)], before: 8 });
  expect(h.store.get().activity.blocks.map((block) => block.id)).toEqual(["entry-5", "entry-6", "gap-8", "entry-9"]);
});

test("text is clipped only above the limit, keeping head and tail", () => {
  const exact = "x".repeat(CLIP_AT);
  expect(clip(exact)).toBe(exact);
  const long = `${"a".repeat(CLIP_KEEP)}${"m".repeat(5)}${"z".repeat(CLIP_KEEP)}`;
  expect(clip(long)).toBe(`${"a".repeat(CLIP_KEEP)}\n… 5 characters not shown …\n${"z".repeat(CLIP_KEEP)}`);
});

test("write inbox items are not shown as queued instructions", () => {
  expect(queued({ docs: { "pi.inbox": { items: [{ mode: "write", content: "internal" }, { mode: "steer", content: "steer me" }, { mode: "followUp", content: [{ type: "text", text: "then this" }] }] } } })).toEqual(["steer me", "then this"]);
  expect(queued({ docs: {} })).toEqual([]);
});

test("tool calls summarize their arguments and the excerpt uses the last part", () => {
  const block = entryBlock({ id: 1, model: [{ role: "assistant", timestamp: 7, content: [{ type: "text", text: "Running tests" }, { type: "toolCall", name: "bash", arguments: { command: "bun test" } }] }] })!;
  expect(block.time).toBe(7);
  expect(block.parts[1]).toEqual({ kind: "tool", name: "bash", summary: '{"command":"bun test"}', body: '{\n  "command": "bun test"\n}' });
  expect(excerpt(block)).toBe('bash {"command":"bun test"}');
  expect(entryBlock({ id: 2, kind: "meta" })).toBeUndefined();
});
