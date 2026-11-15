import { expect, spyOn, test } from "bun:test";
import { ScrollView, TuiAltScreen, VStack, type TuiInputListener } from "@earendil-works/pi-tui";
import type { ConversationId } from "@earendil-works/pi-durable";
import type { Run } from "../src/runs-doc.ts";
import { tui } from "../tui/app.ts";
import { TuiModel } from "../tui/model.ts";

test("app enters a live tail from a long list but preserves manual scroll during updates and editing", async () => {
  const descriptors = [process.stdin, process.stdout].map(stream => Object.getOwnPropertyDescriptor(stream, "isTTY"));
  for (const stream of [process.stdin, process.stdout]) Object.defineProperty(stream, "isTTY", { configurable: true, value: true });
  let key: TuiInputListener = () => undefined;
  let model!: TuiModel;
  let viewport!: ScrollView;
  let transcriptLines = 200;
  const run: Run = { id: "00000000-0000-0000-0000-000000000001", requestId: "scroll", repo: "Tonours/fixture", prompt: "fixture", conversationId: 1 as ConversationId, branch: "fixture", worktree: "unused", route: "answer", status: "implementing", reason: "", url: "", createdAt: 0, startedAt: 0, deadline: 0, maxTurns: 1, submissionId: "", notified: false };
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
      this.runs = Array.from({ length: 40 }, (_, i) => ({ ...run, id: i === 0 ? run.id : `fixture-${i}` }));
      this.selectedId ||= run.id;
      this.changed();
    }),
    spyOn(TuiModel.prototype, "transcript").mockImplementation(() => Array.from({ length: transcriptLines }, (_, i) => `line ${i}`).join("\n")),
  ];
  const done = tui("unused-scroll-test");
  try {
    expect(viewport.scrollTop).toBe(0);
    key("\r");
    expect(viewport.scrollTop).toBe(180);
    expect(viewport.isFollowingEnd).toBe(true);
    viewport.scrollBy(-30);
    transcriptLines = 220;
    model.changed();
    expect(viewport.scrollTop).toBe(150);
    key("s");
    model.cancel();
    expect(viewport.scrollTop).toBe(150);
    transcriptLines = 2;
    model.changed();
    key("\u001b");
    expect(viewport.scrollTop).toBe(0);
    transcriptLines = 200;
    key("\r");
    expect(viewport.scrollTop).toBe(180);
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
