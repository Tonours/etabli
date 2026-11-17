import { expect, spyOn, test } from "bun:test";
import { ScrollView, TuiAltScreen, VStack, type TuiInputListener } from "@earendil-works/pi-tui";
import type { ConversationId } from "@earendil-works/pi-durable";
import type { Run } from "../src/runs-doc.ts";
import { tui } from "../tui/app.ts";
import { listView, TuiModel } from "../tui/model.ts";
import { order } from "../shared/runs-view.ts";

test("app enters a live tail from a long list but preserves manual scroll during updates and editing", async () => {
  const descriptors = [process.stdin, process.stdout].map(stream => Object.getOwnPropertyDescriptor(stream, "isTTY"));
  for (const stream of [process.stdin, process.stdout]) Object.defineProperty(stream, "isTTY", { configurable: true, value: true });
  let key: TuiInputListener = () => undefined;
  let model!: TuiModel;
  let viewport!: ScrollView;
  let transcriptLines = 200;
  const hour = 3_600_000;
  const run: Run = { id: "00000000-0000-0000-0000-000000000001", requestId: "scroll", repo: "Tonours/fixture", prompt: "fixture", conversationId: 1 as ConversationId, branch: "fixture", worktree: "unused", route: "answer", status: "implementing", reason: "", url: "", createdAt: 0, startedAt: 0, deadline: 0, maxTurns: 1, submissionId: "", notified: false };
  const status = (i: number): Run["status"] => i < 8 ? "blocked" : i < 28 ? "implementing" : "done";
  let rows: Run[] = Array.from({ length: 40 }, (_, i) => ({ ...run, id: i === 0 ? run.id : `fixture-${i}`, status: status(i), reason: "turn_limit", createdAt: Date.now() - (i + 1) * hour, startedAt: Date.now() - (i + 1) * hour }));
  const selectedLine = () => listView(model.runs, model.selectedId, Date.now()).selectedLine;
  const inside = () => selectedLine() >= viewport.scrollTop && selectedLine() < viewport.scrollTop + 20;
  // Only terminal I/O and backend data are substituted. The app's key handler,
  // render transitions and native ScrollView state run unchanged.
  const spies = [
    spyOn(TuiAltScreen.prototype, "start").mockImplementation(() => {}),
    spyOn(TuiAltScreen.prototype, "stop").mockImplementation(() => {}),
    spyOn(TuiAltScreen.prototype, "requestRender").mockImplementation(() => {}),
    spyOn(TuiAltScreen.prototype, "setFocus").mockImplementation(() => {}),
    spyOn(TuiAltScreen.prototype, "addInputListener").mockImplementation(listener => { key = listener; return () => {}; }),
    spyOn(TuiAltScreen.prototype, "setLayoutRoot").mockImplementation(root => {
      if (!(root instanceof VStack)) throw new Error("Expected app layout");
      viewport = root.children.find(child => child instanceof ScrollView) as ScrollView;
      viewport.updateLayout(viewport.render(80).length, 20, () => {});
    }),
    spyOn(TuiModel.prototype, "refresh").mockImplementation(async function (this: TuiModel) {
      model = this;
      this.runs = order(rows, Date.now()).runs;
      this.selectedId ||= this.runs[0].id;
      this.changed();
    }),
    spyOn(TuiModel.prototype, "transcript").mockImplementation(() => Array.from({ length: transcriptLines }, (_, i) => `line ${i}`).join("\n")),
  ];
  const done = tui("unused-scroll-test");
  try {
    expect(viewport.scrollTop).toBe(0);
    model.selectedId = model.runs[6].id;
    key("\u001b[B");
    key("\u001b[B");
    expect(model.selectedId).toBe(model.runs[8].id);
    expect(model.runs[8].status).toBe("implementing");
    expect(inside()).toBe(true);
    model.selectedId = model.runs[25].id;
    model.changed();
    const listViewport = viewport;
    const listTop = Math.max(0, selectedLine() - 10);
    expect(listTop).toBeGreaterThan(15);
    expect(listViewport.scrollTop).toBe(listTop);
    expect(inside()).toBe(true);
    model.selectedId = model.runs[38].id;
    model.changed();
    expect(inside()).toBe(true);
    const moved = model.selectedId;
    rows = rows.map(row => row.id === moved ? { ...row, status: "blocked" } : row);
    await model.refresh();
    expect(model.selectedId).toBe(moved);
    expect(model.runs.findIndex(row => row.id === moved)).toBeLessThan(10);
    expect(inside()).toBe(true);
    model.selectedId = model.runs[25].id;
    model.changed();
    expect(listViewport.scrollTop).toBe(listTop);
    key("\r");
    const runViewport = viewport;
    expect(runViewport).not.toBe(listViewport);
    expect(listViewport.scrollTop).toBe(listTop);
    expect(viewport.scrollTop).toBe(180);
    expect(viewport.isFollowingEnd).toBe(true);
    viewport.scrollBy(-30);
    transcriptLines = 220;
    model.changed();
    expect(viewport.scrollTop).toBe(150);
    key("s");
    model.cancel();
    expect(viewport.scrollTop).toBe(150);
    key("\u001b");
    expect(viewport).toBe(listViewport);
    expect(viewport.scrollTop).toBe(listTop);
    expect(runViewport.scrollTop).toBe(150);
    transcriptLines = 200;
    key("\r");
    expect(viewport).toBe(runViewport);
    expect(viewport.scrollTop).toBe(180);
    expect(listViewport.scrollTop).toBe(listTop);
  } finally {
    key("q");
    await done;
    for (const spy of spies) spy.mockRestore();
    [process.stdin, process.stdout].forEach((stream, i) => {
      const descriptor = descriptors[i];
      if (descriptor) Object.defineProperty(stream, "isTTY", descriptor);
      else Reflect.deleteProperty(stream, "isTTY");
    });
  }
});
