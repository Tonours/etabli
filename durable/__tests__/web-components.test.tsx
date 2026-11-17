import { afterAll, afterEach, beforeAll, expect, test } from "bun:test";
import { GlobalRegistrator } from "@happy-dom/global-registrator";
import { act, cleanup, fireEvent, render } from "@testing-library/react";
import { App } from "../web-src/app.tsx";
import { StoreContext } from "../web-src/use-store.ts";
import { A, harness, listed, ok, settle } from "./web-harness.ts";

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
  expect([!!view.container.querySelector("#schedules-title"), !!view.container.querySelector("#runs-title")]).toEqual([true, false]);
  fireEvent.click(button("Runs")); await flush();
  expect([button("Runs").getAttribute("aria-pressed"), !!view.container.querySelector("#schedules-title"), !!view.container.querySelector("#runs-title")]).toEqual(["true", false, true]);
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
