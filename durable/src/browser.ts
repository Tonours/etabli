import { createHash, randomBytes } from "node:crypto";
import { readFile } from "node:fs/promises";
import type { IncomingMessage, ServerResponse } from "node:http";
import { remoteAuth, remoteIdentity, singleHeader, webOrigin } from "./auth.ts";
import type { Push } from "./push.ts";

const cookieName = "__Host-etabli";
const lifetime = 43_200_000;
const assets: Record<string, [string, string]> = {
  "/": ["index.html", "text/html; charset=utf-8"],
  "/app.js": ["app.js", "text/javascript; charset=utf-8"],
  "/style.css": ["style.css", "text/css; charset=utf-8"],
  "/sw.js": ["sw.js", "text/javascript; charset=utf-8"],
  "/manifest.webmanifest": ["manifest.webmanifest", "application/manifest+json"],
  "/icon-192.png": ["icon-192.png", "image/png"],
  "/icon-512.png": ["icon-512.png", "image/png"],
};
type Session = { identity: string; expires: number; revoke: Set<() => void> };
const digest = (value: string) => createHash("sha256").update(value).digest("hex");
const hasHeader = (request: IncomingMessage, name: string) => request.rawHeaders.some((value, i) => i % 2 === 0 && value.toLowerCase() === name);

export function browserJson(response: ServerResponse, status: number, value: unknown): void {
  response.writeHead(status, { "content-type": "application/json", "cache-control": "no-store", "x-content-type-options": "nosniff" });
  response.end(JSON.stringify(value));
}

export class Browser {
  private sessions = new Map<string, Session>();
  private bearer: ReturnType<typeof remoteAuth>;
  readonly origin: string;
  readonly identities: readonly string[];
  readonly push: Push | undefined;
  private readonly now: () => number;
  constructor(token: string, identities: readonly string[], origin: string, push?: Push, now = Date.now) {
    this.origin = webOrigin(origin);
    this.identities = identities;
    this.push = push;
    this.now = now;
    this.bearer = remoteAuth(token, identities);
  }

  private sameOrigin(request: IncomingMessage, required: boolean): boolean {
    if (hasHeader(request, "origin") && singleHeader(request, "origin") !== this.origin) return false;
    if (required && singleHeader(request, "origin") !== this.origin) return false;
    if (hasHeader(request, "sec-fetch-site") && singleHeader(request, "sec-fetch-site") !== "same-origin") return false;
    return true;
  }

  private session(request: IncomingMessage): Session | undefined {
    const cookie = singleHeader(request, "cookie");
    const values = cookie?.split(";").map((part) => part.trim()).filter((part) => part.startsWith(`${cookieName}=`));
    if (values?.length !== 1) return undefined;
    const value = values[0].slice(cookieName.length + 1);
    if (!/^[A-Za-z0-9_-]{43}$/.test(value)) return undefined;
    const session = this.sessions.get(digest(value));
    return session && session.expires > this.now() && session.identity === remoteIdentity(request, this.identities) ? session : undefined;
  }

  authorize(request: IncomingMessage, upgrade = false): 401 | 403 | undefined {
    if (hasHeader(request, "authorization")) return this.bearer(request);
    if (!remoteIdentity(request, this.identities)) return 403;
    if (!this.sameOrigin(request, upgrade || request.method !== "GET") || !upgrade && singleHeader(request, "x-etabli-client") !== "web-v1") return 403;
    return this.session(request) ? undefined : 401;
  }

  track(request: IncomingMessage, revoke: () => void): () => void {
    if (hasHeader(request, "authorization")) return () => {};
    const session = this.session(request);
    if (!session) { revoke(); return () => {}; }
    session.revoke.add(revoke);
    const timer = setTimeout(revoke, Math.max(1, session.expires - this.now()));
    timer.unref();
    return () => { clearTimeout(timer); session.revoke.delete(revoke); };
  }

  close(): void {
    for (const session of this.sessions.values()) for (const revoke of session.revoke) revoke();
    this.sessions.clear();
  }

  async handle(request: IncomingMessage, response: ServerResponse): Promise<boolean> {
    const path = request.url ?? "";
    const asset = Object.hasOwn(assets, path) ? assets[path] : undefined;
    if (asset) {
      if (!remoteIdentity(request, this.identities)) { browserJson(response, 403, { error: "Identity refused" }); return true; }
      if (request.method !== "GET") { browserJson(response, 405, { error: "Method refused" }); return true; }
      const content = await readFile(new URL(`../web/${asset[0]}`, import.meta.url));
      const wsOrigin = this.origin.replace(/^https:/, "wss:");
      response.writeHead(200, {
        "content-type": asset[1], "cache-control": "no-store", "x-content-type-options": "nosniff", "referrer-policy": "no-referrer",
        "content-security-policy": `default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self'; connect-src 'self' ${wsOrigin}; manifest-src 'self'; worker-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`,
      });
      response.end(content);
      return true;
    }
    if (path === "/v1/browser/session" && request.method === "POST") {
      const status = this.bearer(request);
      if (status) { browserJson(response, status, { error: "Authorization refused" }); return true; }
      if (!this.sameOrigin(request, true) || singleHeader(request, "x-etabli-client") !== "web-v1") { browserJson(response, 403, { error: "Origin refused" }); return true; }
      for (const [key, session] of this.sessions) if (session.expires <= this.now()) { for (const revoke of session.revoke) revoke(); this.sessions.delete(key); }
      if (this.sessions.size >= 64) { browserJson(response, 429, { error: "Session limit reached; sign out another client or wait for expiry" }); return true; }
      const previous = this.session(request);
      if (previous) this.remove(previous);
      const secret = randomBytes(32).toString("base64url");
      this.sessions.set(digest(secret), { identity: remoteIdentity(request, this.identities)!, expires: this.now() + lifetime, revoke: new Set() });
      response.setHeader("set-cookie", `${cookieName}=${secret}; Secure; HttpOnly; SameSite=Strict; Path=/; Max-Age=43200`);
      browserJson(response, 200, { ok: true, value: { expiresAt: this.now() + lifetime } });
      request.resume();
      return true;
    }
    if (!path.startsWith("/v1/browser/") && !path.startsWith("/v1/push/")) return false;
    const status = this.authorize(request);
    if (status) { browserJson(response, status, { error: "Authorization refused" }); request.resume(); return true; }
    if (path === "/v1/browser/session" && request.method === "DELETE") {
      const session = this.session(request);
      if (session) this.remove(session);
      response.setHeader("set-cookie", `${cookieName}=; Secure; HttpOnly; SameSite=Strict; Path=/; Max-Age=0`);
      browserJson(response, 200, { ok: true, value: { revoked: true } });
    } else if (path === "/v1/push/key" && request.method === "GET" && this.push) {
      browserJson(response, 200, { ok: true, value: { publicKey: this.push.key.publicKey } });
    } else if (path === "/v1/push/subscriptions" && ["POST", "DELETE"].includes(request.method!) && this.push) {
      try {
        let text = "";
        request.setEncoding("utf8");
        for await (const chunk of request) { text += String(chunk); if (text.length > 8192) throw new Error("Push request too large"); }
        const body: unknown = JSON.parse(text);
        if (!body || typeof body !== "object" || Array.isArray(body) || Object.keys(body).some((key) => key !== "endpoint")) throw new Error("Expected push endpoint");
        const identity = remoteIdentity(request, this.identities)!;
        const endpoint = (body as { endpoint?: unknown }).endpoint;
        const value = request.method === "POST" ? await this.push.subscribe(identity, endpoint) : await this.push.unsubscribe(identity, endpoint);
        browserJson(response, 200, { ok: true, value });
      } catch { browserJson(response, 400, { error: "Push subscription refused; use a supported HTTPS push endpoint within the device limit" }); }
    } else browserJson(response, path.includes("?") ? 400 : ["/v1/browser/session", "/v1/push/key", "/v1/push/subscriptions"].includes(path) ? 405 : 404, { error: "Browser route or method refused" });
    request.resume();
    return true;
  }

  private remove(session: Session): void {
    for (const [key, value] of this.sessions) if (value === session) this.sessions.delete(key);
    for (const revoke of session.revoke) revoke();
  }
}
