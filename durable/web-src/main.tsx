import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./app.tsx";
import { Store, type Env, type Registration } from "./store.ts";
import { StoreContext } from "./use-store.ts";
import "./index.css";

const push: Env["push"] = "serviceWorker" in navigator && "PushManager" in window ? {
  async register() {
    const registration = await navigator.serviceWorker.register("/sw.js", { updateViaCache: "none" });
    await navigator.serviceWorker.ready;
    return registration as unknown as Registration;
  },
  requestPermission: () => Notification.requestPermission(),
} : undefined;

const store = new Store({
  fetch: (input, init) => fetch(input, init), WebSocket, origin: location.origin,
  setTimeout: (callback, ms) => window.setTimeout(callback, ms), clearTimeout: (id) => window.clearTimeout(id),
  uuid: () => crypto.randomUUID(), hidden: () => document.hidden, hash: () => location.hash, push,
});
window.addEventListener("hashchange", () => store.route(location.hash));
window.addEventListener("offline", () => store.offline());
window.addEventListener("online", () => store.online());
window.addEventListener("pagehide", () => store.pagehide());
window.addEventListener("pageshow", (event) => store.pageshow(event.persisted));
window.setInterval(() => void store.poll(), 5000);
store.start();

createRoot(document.getElementById("root")!).render(<StrictMode><StoreContext.Provider value={store}><App /></StoreContext.Provider></StrictMode>);
