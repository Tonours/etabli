import { afterAll, afterEach, beforeAll, expect, test } from "bun:test";
import { GlobalRegistrator } from "@happy-dom/global-registrator";
import { act, cleanup, fireEvent, render } from "@testing-library/react";
import { App } from "../web-src/app.tsx";
import { StoreContext } from "../web-src/use-store.ts";
import { A, B, deferred, harness, listed, ok, settle, type Reply } from "./web-harness.ts";

beforeAll(() => { GlobalRegistrator.register({ url: "https://fixture.invalid/" }); });
afterEach(() => { cleanup(); });
afterAll(async () => {
  await GlobalRegistrator.unregister();
  expect(Reflect.get(globalThis, "document")).toBeUndefined();
  expect(Reflect.get(globalThis, "window")).toBeUndefined();
});

function mount(h: ReturnType<typeof harness>) {
  return render(<StoreContext.Provider value={h.store}><App /></StoreContext.Provider>);
}
const flush = () => act(async () => { await settle(); await settle(); });

test("the token field is empty after submit, on failure and on success", async () => {
  const h = harness();
  const view = mount(h);
  await flush();
  const field = () => view.container.querySelector<HTMLInputElement>("#token")!;
  const restore = h.use(() => ({ status: 401, body: { ok: false, error: "Invalid token" } }));
  fireEvent.change(field(), { target: { value: "wrong-token" } });
  fireEvent.submit(field().form!);
  expect(field().value).toBe("");
  await flush();
  expect(view.container.textContent).toContain("Session unavailable. Reconnect with your daemon token.");
  restore();
  fireEvent.change(field(), { target: { value: "F".repeat(43) } });
  fireEvent.submit(field().form!);
  expect(field().value).toBe("");
  await flush();
  expect(!!view.container.querySelector("#token")).toBe(false);
  expect(JSON.stringify(h.store.get())).not.toContain("F".repeat(43));
});

test("Runs and Schedules each show one panel and set aria-pressed", async () => {
  const h = harness();
  await h.signIn();
  const view = mount(h);
  const button = (name: string) => [...view.container.querySelectorAll("nav button")].find((node) => node.textContent === name)!;
  fireEvent.click(button("Schedules")); await flush();
  expect([button("Schedules").getAttribute("aria-pressed"), button("Runs").getAttribute("aria-pressed")]).toEqual(["true", "false"]);
  const list = () => !!view.container.querySelector('section[aria-label="All runs"]');
  expect([!!view.container.querySelector("#schedules-title"), list()]).toEqual([true, false]);
  fireEvent.click(button("Runs")); await flush();
  expect([button("Runs").getAttribute("aria-pressed"), !!view.container.querySelector("#schedules-title"), list()]).toEqual(["true", false, true]);
});

test("the schedules list shows the empty text, then repo, cron in UTC, next due time and task", async () => {
  const h = harness();
  await h.signIn(); await h.store.showTab("schedules");
  const view = mount(h);
  expect(view.container.textContent).toContain("No scheduled tasks. Choose a repository and UTC time below.");
  h.use((call) => call.path === "/v1/schedules" ? ok([{ id: "s1", repo: "Tonours/fixture", prompt: "nightly <b>task</b>", cron: "0 9 * * 1-5", nextDue: Date.UTC(2026, 10, 18, 9) }]) : h.fallback(call));
  await act(() => h.store.loadSchedules());
  const row = view.container.querySelector(".schedule-list li")!.textContent!;
  for (const part of ["Tonours/fixture", "0 9 * * 1-5 UTC", "Next: 2026-11-18T09:00:00.000Z", "nightly <b>task</b>"]) expect(row).toContain(part);
  expect(!!view.container.querySelector(".schedule-list b")).toBe(false);
});

test("hostile markup in a prompt renders as text", async () => {
  const hostile = "Browser fixture: <img src=x onerror=alert(1)> must remain text. <dialog open>x</dialog>";
  const h = harness([listed(A, "implementing", { prompt: hostile, repo: "<img src=y>" })]);
  await h.signIn();
  const view = mount(h);
  act(() => h.store.route(`#${A}`));
  expect(view.container.textContent).toContain(hostile);
  expect(view.container.querySelectorAll("img, dialog")).toHaveLength(0);
});

const now = Date.now();
const tabs = (root: HTMLElement) => [...root.querySelectorAll<HTMLButtonElement>('[role="tab"]')];
const tab = (root: HTMLElement, name: string) => tabs(root).find((node) => node.textContent === name)!;
const panel = (root: HTMLElement) => root.querySelector<HTMLElement>('[role="tabpanel"][data-state="active"]')!;

async function opened(runs = [listed(A, "implementing", { startedAt: now - 120_000 }), listed(B)]) {
  const h = harness(runs);
  await h.signIn();
  const view = mount(h);
  act(() => h.store.route(`#${A}`));
  await flush();
  return { h, view, root: view.container };
}

test("run tabs expose aria and move with the arrow keys", async () => {
  const { root } = await opened();
  expect(tabs(root).map((node) => node.textContent)).toEqual(["Overview", "Activity", "Plan", "Instructions"]);
  expect(tab(root, "Overview").getAttribute("aria-selected")).toBe("true");
  expect(panel(root).getAttribute("aria-labelledby")).toBe(tab(root, "Overview").id);
  act(() => { tab(root, "Overview").focus(); });
  fireEvent.keyDown(tab(root, "Overview"), { key: "ArrowRight" });
  await flush();
  expect(document.activeElement).toBe(tab(root, "Activity"));
  fireEvent.mouseDown(tab(root, "Plan"), { button: 0 });
  await flush();
  expect(tab(root, "Plan").getAttribute("aria-selected")).toBe("true");
  expect(panel(root).textContent).toContain("Full task");
});

test("a draft survives a tab change", async () => {
  const { h, root } = await opened();
  act(() => h.store.setPanel("instructions"));
  act(() => h.store.setDraft("keep me"));
  act(() => h.store.setPanel("activity"));
  act(() => h.store.setPanel("instructions"));
  expect(root.querySelector<HTMLTextAreaElement>("#instruction")!.value).toBe("keep me");
});

test("a blocked run shows three tabs, its label and the next step", async () => {
  const { root } = await opened([listed(A, "blocked", { reason: "wall_clock_limit", startedAt: now - 3_600_000 })]);
  expect(tabs(root).map((node) => node.textContent)).toEqual(["Overview", "Activity", "Plan"]);
  const alert = panel(root).querySelector('[data-slot="alert"]')!.textContent!;
  expect(alert).toContain("Out of time");
  expect(alert).toContain("The run reached its time limit. Review its progress, then start a new run from the CLI.");
  expect(!!root.querySelector(".run-actions")).toBe(false);
});

test("a queued run shows its creation time and gains Instructions once active", async () => {
  const { h, root } = await opened([listed(A, "queued", { startedAt: 0, createdAt: now - 300_000 })]);
  expect(root.querySelector(".run-head")!.textContent).toContain("created 5m ago");
  expect(panel(root).textContent).toContain("Waiting to start");
  expect(tabs(root)).toHaveLength(3);
  h.setRuns([listed(A, "planning", { startedAt: now })]);
  await act(() => h.store.listRuns());
  expect(tabs(root).map((node) => node.textContent)).toContain("Instructions");
  expect(root.querySelector(".run-head")!.textContent).toMatch(/started \d+s ago/);
});

test("the overview excerpt follows activity and the queued mention opens Instructions", async () => {
  const { h, root } = await opened();
  expect(panel(root).textContent).toContain("No activity recorded yet.");
  act(() => h.open()[0]!.frame({ entries: [{ id: 1, model: [{ role: "assistant", content: "first step" }] }] }));
  expect(root.querySelector(".latest")!.textContent).toContain("first step");
  act(() => h.open()[0]!.frame({ entries: [{ id: 2, model: [{ role: "assistant", content: "second step" }] }], docs: { "pi.inbox": { items: [{ mode: "steer", content: "use bun" }] } } }));
  expect(root.querySelector(".latest")!.textContent).toContain("second step");
  const mention = root.querySelector(".inbox")!;
  expect(mention.textContent).toBe("Instruction queued · View");
  fireEvent.click(mention.querySelector("button")!);
  expect(tab(root, "Instructions").getAttribute("aria-selected")).toBe("true");
  expect(!!root.querySelector(".inbox")).toBe(false);
  expect(panel(root).textContent).toContain("use bun");
});

test("focus moves to Overview when the focused Instructions tab disappears", async () => {
  const { h, root } = await opened();
  act(() => { tab(root, "Instructions").focus(); });
  expect(document.activeElement?.textContent).toBe("Instructions");
  h.setRuns([listed(A, "aborted")]);
  await act(() => h.store.listRuns());
  expect(tab(root, "Instructions")).toBeUndefined();
  expect(document.activeElement?.textContent).toBe("Overview");
});

test("pull request links appear only for https URLs", async () => {
  const runs = [
    listed(A, "done", { reason: "published", url: "https://github.com/Tonours/fixture/pull/1" }),
    listed(B, "done", { reason: "published", url: "javascript:alert(1)" }),
    listed("cccccccc-3333-4333-8333-333333333333", "done", { reason: "published", url: "http://github.com/x" }),
  ];
  const { root } = await opened(runs);
  expect([...root.querySelectorAll<HTMLAnchorElement>(".pr-link")].map((node) => node.href)).toEqual(["https://github.com/Tonours/fixture/pull/1"]);
  expect([...panel(root).querySelectorAll("a")].map((node) => node.getAttribute("href"))).toEqual(["https://github.com/Tonours/fixture/pull/1"]);
});

test("a list row shows the label, the repository, the age and, when it needs you, the next step", async () => {
  const h = harness([listed(A, "blocked", { reason: "run_setup_failed", startedAt: now - 7_200_000, prompt: "Fix login\nmore" }), listed(B, "implementing", { startedAt: now - 60_000 })]);
  await h.signIn();
  const root = mount(h).container;
  expect(root.querySelector(".summary")!.textContent).toBe("1 need you · 1 working · 0 queued");
  const row = root.querySelector(`a[data-run="${A}"]`)!;
  expect(row.closest(".run-group")!.querySelector("h2")!.textContent).toBe("Needs you 1");
  for (const part of ["Fix login", "Setup failed", "Tonours/fixture · 2h", "The run could not start. Check the repository setup, then start a new run from the CLI."]) expect(row.textContent).toContain(part);
  expect(row.textContent).not.toContain("more");
  expect(!!root.querySelector(`a[data-run="${B}"] .hint`)).toBe(false);
  expect(root.querySelector(`a[data-run="${B}"]`)!.textContent).toContain("Implementing");
});

test("a focused row keeps focus across a poll that moves it to another group", async () => {
  const h = harness();
  await h.signIn();
  const root = mount(h).container;
  const row = () => root.querySelector<HTMLAnchorElement>(`a[data-run="${B}"]`)!;
  act(() => { row().focus(); });
  expect(row().closest(".run-group")!.querySelector("h2")!.textContent).toBe("In progress 2");
  h.setRuns([listed("cccccccc-3333-4333-8333-333333333333", "implementing", { startedAt: now }), listed(A), listed(B, "done", { reason: "published" })]);
  await act(() => h.store.listRuns());
  expect(row().closest(".run-group")!.querySelector("h2")!.textContent).toBe("Finished 1");
  expect(document.activeElement?.getAttribute("data-run")).toBe(B);
});

test("End, Home and arrows move selection and focus; every tab controls its labelled panel", async () => {
  const { root } = await opened();
  const key = async (from: string, name: string) => { fireEvent.keyDown(tab(root, from), { key: name }); await flush(); };
  act(() => { tab(root, "Overview").focus(); });
  await key("Overview", "ArrowRight");
  expect([document.activeElement?.textContent, tab(root, "Activity").getAttribute("aria-selected")]).toEqual(["Activity", "true"]);
  await key("Activity", "End");
  expect([document.activeElement?.textContent, tab(root, "Instructions").getAttribute("aria-selected")]).toEqual(["Instructions", "true"]);
  await key("Instructions", "Home");
  expect([document.activeElement?.textContent, tab(root, "Overview").getAttribute("aria-selected")]).toEqual(["Overview", "true"]);
  for (const node of tabs(root)) {
    const controlled = root.querySelector(`#${CSS.escape(node.getAttribute("aria-controls")!)}`)!;
    expect([controlled.getAttribute("role"), controlled.getAttribute("aria-labelledby")]).toEqual(["tabpanel", node.id]);
  }
  expect(root.querySelectorAll('[role="tabpanel"][data-state="active"]')).toHaveLength(1);
});

test("a read instruction leaves the inbox: mention and queued text go, one entry renders", async () => {
  const { h, root } = await opened();
  const socket = () => h.open()[0]!;
  act(() => socket().frame({ entries: [{ id: 1, model: [{ role: "assistant", content: "working" }] }], docs: { "pi.inbox": { items: [{ mode: "steer", content: "use bun please" }] } } }));
  act(() => h.store.setPanel("activity"));
  expect(root.querySelector(".inbox")!.textContent).toBe("Instruction queued · View");
  expect(root.querySelector("#instruction")!.closest('[role="tabpanel"]')!.textContent).toContain("use bun please");
  const frame = { entries: [{ id: 2, model: [{ role: "user", content: "use bun please" }] }], docs: { "pi.inbox": { items: [] } } };
  act(() => socket().frame(frame));
  act(() => socket().frame(frame));
  expect(!!root.querySelector(".inbox")).toBe(false);
  expect(root.querySelector("#instruction")!.closest('[role="tabpanel"]')!.textContent).not.toContain("use bun please");
  expect([...root.querySelectorAll(".activity-entry")].filter((node) => node.textContent!.includes("use bun please"))).toHaveLength(1);
  expect(root.querySelectorAll(".activity-entry")).toHaveLength(2);
});

test("an expanded tool call shows its complete arguments", async () => {
  const { h, root } = await opened();
  const command = `echo ${"x".repeat(295)}`;
  expect(command).toHaveLength(300);
  act(() => h.open()[0]!.frame({ entries: [{ id: 1, model: [{ role: "assistant", content: [{ type: "toolCall", name: "bash", arguments: { command } }] }] }] }));
  act(() => h.store.setPanel("activity"));
  const trigger = root.querySelector<HTMLButtonElement>(".tool-line")!;
  expect(trigger.textContent!.length).toBeLessThan(200);
  fireEvent.click(trigger);
  await flush();
  expect(root.querySelector(".tool pre")!.textContent).toContain(command);
});

for (const [status, reason] of [["blocked", "review_block_limit"], ["done", "published"], ["aborted", ""]] as const) {
  test(`an ended ${status} run has no Live wording, no Instructions and no run actions`, async () => {
    const { root } = await opened([listed(A, status, { reason, startedAt: now - 60_000 })]);
    expect(root.textContent).not.toContain("Live");
    expect(tab(root, "Instructions")).toBeUndefined();
    expect(!!root.querySelector(".run-actions")).toBe(false);
    expect(root.querySelector(".latest")!.textContent).toContain("No activity was recorded for this run.");
  });
}

test("Overview shows a steer outcome that arrives after the run ended, once, with the draft read-only", async () => {
  for (const reply of [ok({}), { status: 409, body: { ok: false, error: "Run ended" } }]) {
    const { h, root } = await opened();
    const gate = deferred<Reply>();
    const restore = h.use((call) => call.path.endsWith("/steer") ? gate.promise : h.fallback(call));
    act(() => h.store.setDraft("late words"));
    let sending!: Promise<void>;
    act(() => { sending = h.store.steer(); });
    h.setRuns([listed(A, "aborted")]);
    await act(() => h.store.listRuns());
    gate.resolve(reply);
    await act(async () => { await sending; });
    restore();
    const preserved = root.querySelectorAll(".preserved");
    expect(preserved).toHaveLength(1);
    expect(preserved[0]!.textContent).toContain(reply.status === 200 ? "Instruction accepted before the run ended" : "Instruction not delivered");
    expect(tab(root, "Instructions")).toBeUndefined();
    expect([...root.querySelectorAll("button")].some((node) => node.textContent === "Give instruction")).toBe(false);
    cleanup();
  }
});
