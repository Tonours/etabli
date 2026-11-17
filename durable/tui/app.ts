import { indexedColor, Input, matchesKey, ProcessTerminal, ScrollView, styleText, Text, TuiAltScreen, truncateToWidth, VStack, type TextStyle } from "@earendil-works/pi-tui";
import type { Remote } from "../src/client.ts";
import { listView, safe, TuiModel, type Part } from "./model.ts";

const STYLES: Record<NonNullable<Part["tone"]>, TextStyle> = { alert: { fg: indexedColor(1) }, ok: { fg: indexedColor(2) }, info: { fg: indexedColor(4) }, muted: { dim: true } };
const paint = (part: Part) => part.tone ? styleText(part.text, STYLES[part.tone], "256color") : part.text;

export class SafeInput extends Input {
  override handleInput(data: string): void {
    super.handleInput(data);
    const value = safe(this.getValue()).slice(0, 64_000);
    if (value !== this.getValue()) this.setValue(value);
  }
}

export async function tui(state: string, remote?: Remote): Promise<void> {
  if (!process.stdin.isTTY || !process.stdout.isTTY) throw new Error("The TUI requires an interactive terminal");
  const terminal = new ProcessTerminal();
  const ui = new TuiAltScreen(terminal, true, undefined, { mouse: false, copyOnSelect: false });
  const header = new Text("Etabli durable");
  const body = new Text("", 0, 0);
  const footer = new Text("", 0, 0);
  const detail = new Text("", 1, 0);
  const input = new SafeInput({ prompt: "steer> " });
  const listScroll = new ScrollView(body, { primary: true, scrollbar: "hidden" });
  const runScroll = new ScrollView(body, { follow: "end", primary: true, scrollbar: "hidden" });
  const model = new TuiModel(state, remote, render);
  let editing = false;
  let followingRun = false;
  let finish!: () => void;
  const done = new Promise<void>((resolve) => { finish = resolve; });
  let quitting = false;

  function render(): void {
    if (quitting) return;
    const run = model.selected;
    const scroll = model.mode === "list" ? listScroll : runScroll;
    let showDetail = false;
    if (model.mode === "list") {
      followingRun = false;
      const view = listView(model.runs, model.selectedId, Date.now());
      header.setText("Etabli durable — runs");
      body.setText(view.lines.map((line) => truncateToWidth(line.map(paint).join(""), Math.max(1, terminal.columns))).join("\n") || (model.error ? "" : "No runs yet."));
      detail.setText(view.detail.join("\n"));
      showDetail = view.detail.length > 0;
      footer.setText(model.hints());
      scroll.scrollTo(Math.max(0, view.selectedLine - Math.floor(scroll.viewportHeight / 2)));
    } else {
      header.setText(model.header().join("\n"));
      body.setText(model.transcript());
      if (!followingRun) { scroll.scrollToEnd(); followingRun = true; }
      footer.setText(model.notice ? `${model.notice}\n${model.hints()}` : model.hints());
    }
    if (model.pending) footer.setText("Sending… · Ctrl-C quit");
    if (model.error) footer.setText(`${safe(model.error)}\n${model.mode === "abort" ? `y ${model.actionError ? "retry" : "confirm"} · Esc cancel` : model.mode === "steer" ? `Enter ${model.actionError ? "retry" : "send"} · Esc cancel` : "r refresh · q quit"}`);
    if (model.mode === "steer" && !editing) input.setValue(model.draft);
    if (model.mode !== "steer" && editing) {
      if (model.keepInput) { model.draft = safe(input.getValue()); model.keepInput = false; }
      input.setValue("");
    }
    editing = model.mode === "steer";
    ui.setLayoutRoot(new VStack([
      header,
      { component: scroll, basis: 0, grow: 1, minSize: 1 },
      ...(showDetail ? [detail] : []),
      ...(editing ? [input] : []),
      footer,
    ]));
    ui.setFocus(editing ? input : null);
    ui.requestRender();
  }

  const quit = () => { if (!quitting) { quitting = true; model.close(); finish(); } };
  input.onSubmit = () => { model.draft = safe(input.getValue()); void model.send(); };
  input.onEscape = () => { model.draft = safe(input.getValue()); model.cancel(); };
  const removeListener = ui.addInputListener((data) => {
    if (matchesKey(data, "ctrl+c")) { quit(); return { consume: true }; }
    if (model.pending) return { consume: true };
    if (model.mode === "steer") return;
    if (data === "q") { quit(); return { consume: true }; }
    if (matchesKey(data, "escape")) model.cancel();
    else if (model.mode === "abort") { if (data === "y") void model.send(); }
    else if (model.mode === "list" && matchesKey(data, "up")) model.move(-1);
    else if (model.mode === "list" && matchesKey(data, "down")) model.move(1);
    else if (model.mode === "list" && matchesKey(data, "enter")) model.select();
    else if (data === "r") void model.refresh();
    else if (model.mode === "run" && data === "s") model.begin("steer");
    else if (model.mode === "run" && data === "a") model.begin("abort");
    else return;
    return { consume: true };
  });
  process.once("SIGINT", quit);
  process.once("SIGTERM", quit);
  try {
    render();
    ui.start();
    void model.refresh();
    await done;
  } finally {
    model.close();
    removeListener();
    process.removeListener("SIGINT", quit);
    process.removeListener("SIGTERM", quit);
    ui.stop({ preserveScreen: true });
  }
}
