import { afterAll, afterEach, beforeAll, expect, test } from "bun:test";
import { GlobalRegistrator } from "@happy-dom/global-registrator";
import { act, cleanup, fireEvent, render } from "@testing-library/react";
import { App } from "../web-src/app.tsx";
import { StoreContext } from "../web-src/use-store.ts";
import { A, B, harness, listed, ok, settle } from "./web-harness.ts";

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
  expect(view.container.querySelector("#token")).toBeNull();
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
  expect(view.container.querySelector(".schedule-list b")).toBeNull();
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
  expect(root.querySelector(".run-actions")).toBeNull();
});

test("a queued run shows its creation time and gains Instructions once active", async () => {
  const { h, root } = await opened([listed(A, "queued", { startedAt: 0, createdAt: now - 300_000 })]);
  expect(root.querySelector(".run-head")!.textContent).toContain("created 5m ago");
  expect(panel(root).textContent).toContain("Waiting to start");
  expect(tabs(root)).toHaveLength(3);
  h.setRuns([listed(A, "planning", { startedAt: now })]);
  await act(() => h.store.listRuns());
  expect(tabs(root).map((node) => node.textContent)).toContain("Instructions");
  expect(root.querySelector(".run-head")!.textContent).toContain("started 0s ago");
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
  expect(root.querySelector(".inbox")).toBeNull();
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
  expect(root.querySelector(`a[data-run="${B}"] .hint`)).toBeNull();
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
