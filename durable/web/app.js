const $ = (id) => document.getElementById(id);
let selected;
let socket;
let retry;
let signedIn = false;
let generation = 0;
let registration;
let publicKey;
let scheduleRequest;
let steerRequest;
const terminal = (run) => ["done", "blocked", "aborted"].includes(run.status);
const message = (text = "") => { $("message").textContent = text; };

function clearSession() {
  signedIn = false;
  generation++;
  selected = undefined;
  scheduleRequest = undefined; steerRequest = undefined; publicKey = undefined;
  socket?.close(); socket = undefined;
  clearTimeout(retry);
  $("token").value = "";
  $("instruction").value = "";
  $("prompt").value = "";
  $("repo").value = "";
  $("cron").value = "";
  for (const id of ["runs", "schedules", "stream", "plan", "run-prompt", "run-title", "run-state", "connection"]) $(id).replaceChildren();
  $("workspace").hidden = true; $("logout").hidden = true; $("login").hidden = false; $("detail").hidden = true;
}

async function api(path, method = "GET", value, authorization) {
  const version = generation;
  let response;
  try {
    response = await fetch(path, {
      method, credentials: "same-origin", cache: "no-store", redirect: "error",
      headers: { "X-Etabli-Client": "web-v1", ...(value ? { "Content-Type": "application/json" } : {}), ...(authorization ? { Authorization: `Bearer ${authorization}` } : {}) },
      ...(value ? { body: JSON.stringify(value) } : {}),
    });
  } catch { throw new Error("Connection lost. Check your network and reconnect."); }
  const body = await response.json();
  if (version !== generation) throw new Error("Session changed. Reconnect to continue.");
  if (response.status === 401 || response.status === 403) { clearSession(); throw new Error("Session unavailable. Reconnect with your daemon token."); }
  if (!response.ok) throw new Error(body.error || "Request refused.");
  return body.value;
}

function action(id, handler) {
  $(id).addEventListener("click", async () => {
    $(id).disabled = true; message();
    try { await handler(); } catch (error) { message(error.message); }
    finally { $(id).disabled = false; }
  });
}

function form(id, handler) {
  $(id).addEventListener("submit", async (event) => {
    event.preventDefault(); const button = $(id).querySelector("button[type=submit]");
    if (button.disabled) return;
    button.disabled = true; message();
    try { await handler(); } catch (error) { message(error.message); }
    finally { button.disabled = false; }
  });
}

async function listRuns() {
  const runs = await api("/v1/runs");
  $("runs").replaceChildren();
  if (!runs.length) { const li = document.createElement("li"); li.textContent = "No runs yet. Submit a task from the CLI to get started."; $("runs").append(li); }
  for (const run of [...runs].reverse()) {
    const li = document.createElement("li"), button = document.createElement("button"), title = document.createElement("strong"), status = document.createElement("small");
    title.textContent = run.repo; status.textContent = `${run.status} · ${new Date(run.createdAt).toLocaleString()}`;
    button.setAttribute("aria-current", String(run.id === selected));
    button.append(title, status); button.addEventListener("click", () => openRun(run.id).catch((error) => message(error.message)));
    li.append(button); $("runs").append(li);
  }
}

function updateRun(run) {
  $("run-title").textContent = run.repo;
  $("run-state").textContent = run.status;
  $("run-prompt").textContent = run.prompt;
  $("abort").disabled = terminal(run);
  $("steer-form").hidden = terminal(run);
}

function contentText(content) {
  if (typeof content === "string") return content;
  return (content ?? []).map((part) => part.text ?? (part.type === "toolCall" ? `${part.name} ${JSON.stringify(part.arguments)}` : part.type === "image" ? "[image]" : "")).filter(Boolean).join("\n");
}

function renderStream(view) {
  const text = [];
  if (view.before) text.push("Earlier entries are outside this live window.");
  for (const entry of view.entries ?? []) {
    for (const part of entry.model ?? []) {
      const value = contentText(part.content);
      if (value) text.push(`${part.role === "assistant" ? "Assistant" : part.role === "user" ? "You" : part.toolName ?? "Tool"}\n${value}`);
    }
  }
  const live = view.docs?.["pi.live"] ?? view.live;
  if (live?.generation?.message) text.push(`Assistant (streaming)\n${contentText(live.generation.message.content)}`);
  for (const tool of live?.tools ?? []) if (tool.output) text.push(`${tool.name ?? "Tool"} (running)\n${contentText(tool.output)}`);
  $("stream").textContent = (text.join("\n\n") || "Waiting for run output…").slice(-200_000);
}

function renderPlan(plan) {
  $("plan").textContent = plan?.enabled ? [`Status: ${plan.status}`, ...Object.entries(plan.sections).map(([name, content]) => `${name}\n${content}`)].join("\n\n") : "This run has no plan yet.";
}

async function openRun(id) {
  selected = id; socket?.close(); clearTimeout(retry);
  $("abort-confirm").hidden = true;
  const value = await api(`/v1/runs/${id}`);
  if (selected !== id) return;
  updateRun(value.run); renderStream(value);
  $("detail").hidden = false;
  const plan = await api(`/v1/runs/${id}/plan`);
  if (selected !== id) return;
  renderPlan(plan);
  await listRuns();
  watch(id);
}

function watch(id) {
  if (!signedIn || selected !== id) return;
  const current = new WebSocket(`${location.origin.replace(/^http/, "ws")}/v1/runs/${id}/watch`);
  socket = current; $("connection").textContent = "Connecting to live stream…";
  current.addEventListener("open", () => { if (socket === current) $("connection").textContent = "Live stream connected"; });
  current.addEventListener("message", (event) => {
    if (socket !== current) return;
    try {
      const frame = JSON.parse(event.data);
      if (frame.kind === "value") renderStream(frame.value);
    } catch { message("The live stream returned an unreadable frame."); }
  });
  current.addEventListener("close", () => {
    if (socket !== current || !signedIn || selected !== id) return;
    $("connection").textContent = "Stream disconnected. Reconnecting…";
    retry = setTimeout(async () => {
      try { const value = await api(`/v1/runs/${id}`); if (selected === id) { updateRun(value.run); watch(id); } }
      catch (error) { message(error.message); }
    }, 2000);
  });
}

async function schedules() {
  const rows = await api("/v1/schedules");
  $("schedules").replaceChildren();
  if (!rows.length) { const li = document.createElement("li"); li.textContent = "No scheduled tasks. Choose a repository and UTC time below."; $("schedules").append(li); }
  for (const row of rows) {
    const li = document.createElement("li"), title = document.createElement("strong"), time = document.createElement("p"), button = document.createElement("button");
    title.textContent = row.repo; time.textContent = `${row.cron} UTC · Next: ${new Date(row.nextDue).toISOString()}\n${row.prompt}`;
    button.textContent = "Delete schedule";
    button.addEventListener("click", async () => { button.disabled = true; try { await api(`/v1/schedules/${row.id}`, "DELETE"); await schedules(); } catch (error) { message(error.message); button.disabled = false; } });
    li.append(title, time, button); $("schedules").append(li);
  }
}

async function setupPush() {
  if (!("serviceWorker" in navigator) || !("PushManager" in window)) {
    $("push-state").textContent = "Push is unavailable here. On iPhone or iPad, add Etabli to the Home Screen and open it there first.";
    $("subscribe").disabled = true; return;
  }
  registration = await navigator.serviceWorker.register("/sw.js", { updateViaCache: "none" });
  await navigator.serviceWorker.ready;
  publicKey = (await api("/v1/push/key")).publicKey;
  const subscription = await registration.pushManager.getSubscription();
  $("subscribe").hidden = !!subscription; $("unsubscribe").hidden = !subscription;
  if (subscription) {
    await api("/v1/push/subscriptions", "POST", { endpoint: subscription.endpoint });
    $("push-state").textContent = "Notifications enabled for this device. Run contents stay private.";
  }
}

async function connected() {
  await listRuns(); signedIn = true;
  $("workspace").hidden = false; $("logout").hidden = false; $("login").hidden = true;
  await setupPush().catch((error) => { $("push-state").textContent = error.message; });
}

form("login-form", async () => {
  let token = $("token").value; $("token").value = "";
  try { await api("/v1/browser/session", "POST", undefined, token); } finally { token = ""; }
  await connected();
});
form("steer-form", async () => {
  const content = $("instruction").value, id = selected;
  if (!steerRequest || steerRequest.content !== content || steerRequest.id !== id) steerRequest = { id, content, requestId: crypto.randomUUID() };
  await api(`/v1/runs/${id}/steer`, "POST", { content, requestId: steerRequest.requestId });
  if (selected === id) $("instruction").value = "";
  steerRequest = undefined; message("Instruction sent.");
});
form("schedule-form", async () => {
  const value = { repo: $("repo").value, prompt: $("prompt").value, cron: $("cron").value };
  const input = JSON.stringify(value);
  if (scheduleRequest?.input !== input) scheduleRequest = { input, requestId: crypto.randomUUID() };
  await api("/v1/schedules", "POST", { ...value, requestId: scheduleRequest.requestId });
  scheduleRequest = undefined; $("prompt").value = ""; await schedules();
});
action("refresh", listRuns);
action("logout", async () => { await api("/v1/browser/session", "DELETE"); clearSession(); message("Signed out."); });
action("abort", async () => { $("abort-confirm").hidden = false; });
action("abort-no", async () => { $("abort-confirm").hidden = true; });
action("abort-yes", async () => { const id = selected; await api(`/v1/runs/${id}/abort`, "POST"); $("abort-confirm").hidden = true; await openRun(id); });
action("runs-tab", async () => { $("runs-panel").hidden = false; $("schedules-panel").hidden = true; $("runs-tab").setAttribute("aria-pressed", "true"); $("schedules-tab").setAttribute("aria-pressed", "false"); await listRuns(); });
action("schedules-tab", async () => { $("runs-panel").hidden = true; $("schedules-panel").hidden = false; $("runs-tab").setAttribute("aria-pressed", "false"); $("schedules-tab").setAttribute("aria-pressed", "true"); await schedules(); });
action("subscribe", async () => {
  if (!registration || !publicKey) throw new Error("Notification setup is unavailable. Reconnect to retry.");
  // Request permission directly in the click gesture, before any network/worker await.
  if (await Notification.requestPermission() !== "granted") throw new Error("Notifications were not allowed. Change the browser permission to enable them.");
  const key = Uint8Array.from(atob(publicKey.replace(/-/g, "+").replace(/_/g, "/")), (char) => char.charCodeAt(0));
  const subscription = await registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: key });
  await api("/v1/push/subscriptions", "POST", { endpoint: subscription.endpoint });
  $("subscribe").hidden = true; $("unsubscribe").hidden = false; $("push-state").textContent = "Notifications enabled for this device.";
});
action("unsubscribe", async () => {
  const subscription = await registration?.pushManager.getSubscription();
  if (subscription) { await api("/v1/push/subscriptions", "DELETE", { endpoint: subscription.endpoint }); await subscription.unsubscribe(); }
  $("subscribe").hidden = false; $("unsubscribe").hidden = true; $("push-state").textContent = "Notifications disabled for this device.";
});
window.addEventListener("offline", () => message("You are offline. Reconnect to watch and control runs."));
window.addEventListener("online", () => { if (signedIn && selected) openRun(selected).catch((error) => message(error.message)); });
window.addEventListener("pagehide", () => { const previous = socket; socket = undefined; previous?.close(); clearTimeout(retry); });
window.addEventListener("pageshow", (event) => { if (event.persisted) { clearSession(); connected().catch((error) => message(error.message)); } });
let refreshing = false;
setInterval(async () => {
  if (!signedIn || document.hidden || refreshing) return;
  refreshing = true;
  try {
    await listRuns();
    const id = selected;
    if (id) {
      const value = await api(`/v1/runs/${id}`);
      if (selected === id) updateRun(value.run);
      if ($("plan-details").open) {
        const plan = await api(`/v1/runs/${id}/plan`);
        if (selected === id) renderPlan(plan);
      }
    }
  } catch (error) { message(error.message); }
  finally { refreshing = false; }
}, 5000);
connected().catch((error) => { if (signedIn) message(error.message); });
