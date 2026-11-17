import type { ListedRun } from "../shared/runs-view.ts";

export type Run = ListedRun & { repo: string; route: string; deadline: number; maxTurns: number };
export type Schedule = { id: string; repo: string; prompt: string; cron: string; nextDue: number };
export type Plan = { enabled: boolean; status: string; sections: Record<string, string> } | null;
export type Method = "GET" | "POST" | "DELETE";
export type Fetch = (path: string, init: RequestInit) => Promise<Response>;

/** A reply that belongs to an earlier session; callers drop it instead of showing it. */
export class StaleReply extends Error {
  constructor() { super("Session changed. Reconnect to continue."); }
}

/** Same request contract as the hand-written client: one generation per session, 401/403 ends it. */
export function createApi(fetcher: Fetch, generation: () => number, unauthorized: () => void) {
  return async function api<T>(path: string, method: Method = "GET", value?: unknown, authorization?: string): Promise<T> {
    const version = generation();
    let response: Response;
    try {
      response = await fetcher(path, {
        method, credentials: "same-origin", cache: "no-store", redirect: "error",
        headers: { "X-Etabli-Client": "web-v1", ...(value ? { "Content-Type": "application/json" } : {}), ...(authorization ? { Authorization: `Bearer ${authorization}` } : {}) },
        ...(value ? { body: JSON.stringify(value) } : {}),
      });
    } catch { throw new Error("Connection lost. Check your network and reconnect."); }
    const body = await response.json().catch(() => null) as { ok?: boolean; value?: T; error?: string } | null;
    if (version !== generation()) throw new StaleReply();
    if (response.status === 401 || response.status === 403) { unauthorized(); throw new Error("Session unavailable. Reconnect with your daemon token."); }
    if (!response.ok) throw new Error(body?.error || (response.status >= 500 ? "Daemon unavailable. Check your connection and retry." : "Request refused."));
    if (!body || body.ok !== true) throw new Error("Invalid daemon response. Reconnect to retry.");
    return body.value as T;
  };
}
