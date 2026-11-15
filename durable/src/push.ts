import { createPrivateKey, createPublicKey, generateKeyPairSync, randomUUID, sign, verify, type KeyObject } from "node:crypto";
import { constants } from "node:fs";
import { link, open, unlink } from "node:fs/promises";
import { request } from "node:https";
import type { ClientRequest, IncomingMessage, RequestOptions } from "node:http";
import { join } from "node:path";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { defineDoc, type Harness } from "@earendil-works/pi-durable";

type Subscription = { id: string; endpoint: string; identity: string };
export const PushDoc = defineDoc<{ subscriptions: Subscription[] }>({
  kind: "etabli.push", version: 1, scope: "session", initial: () => ({ subscriptions: [] }), checkpointWhen: () => true,
});

export function pushEndpoint(value: unknown): string {
  if (typeof value !== "string" || value.length > 4096) throw new Error("Invalid push endpoint");
  const url = new URL(value);
  if (url.protocol !== "https:" || url.port || url.username || url.password || url.hash || !["fcm.googleapis.com", "updates.push.services.mozilla.com", "web.push.apple.com"].includes(url.hostname) || url.pathname === "/") throw new Error("Unsupported push endpoint");
  return url.href;
}

export type VapidKey = { privateKey: KeyObject; publicKey: string };
export async function loadVapid(path: string): Promise<VapidKey> {
  const read = async () => {
    const file = await open(path, constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
    try {
      const info = await file.stat();
      if (!info.isFile() || info.uid !== process.getuid?.() || (info.mode & 0o777) !== 0o600 || info.size > 2048) throw new Error("VAPID key must be an owned 0600 regular file");
      const pem = await file.readFile("utf8");
      const privateKey = createPrivateKey(pem);
      const jwk = privateKey.export({ format: "jwk" });
      if (jwk.kty !== "EC" || jwk.crv !== "P-256" || !jwk.d) throw new Error("VAPID key must use P-256");
      const pub = createPublicKey(pem).export({ format: "jwk" });
      const probe = Buffer.from("etabli-vapid-key-check");
      if (!verify("sha256", probe, createPublicKey(pem), sign("sha256", probe, privateKey))) throw new Error("VAPID private/public key mismatch");
      const publicKey = Buffer.concat([Buffer.from([4]), Buffer.from(pub.x!, "base64url"), Buffer.from(pub.y!, "base64url")]).toString("base64url");
      return { privateKey, publicKey };
    } finally { await file.close(); }
  };
  try { return await read(); } catch (error) { if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error; }
  const temporary = `${path}.${randomUUID()}.tmp`;
  const file = await open(temporary, "wx", 0o600);
  try {
    try { await file.writeFile(generateKeyPairSync("ec", { namedCurve: "prime256v1" }).privateKey.export({ type: "pkcs8", format: "pem" })); await file.sync(); }
    finally { await file.close(); }
    await link(temporary, path).catch((error: NodeJS.ErrnoException) => { if (error.code !== "EEXIST") throw error; });
  } finally { await unlink(temporary); }
  return read();
}

export function pushHeaders(key: VapidKey, endpoint: string, origin: string, now = Date.now()): Record<string, string> {
  const encode = (value: unknown) => Buffer.from(JSON.stringify(value)).toString("base64url");
  const data = `${encode({ typ: "JWT", alg: "ES256" })}.${encode({ aud: new URL(endpoint).origin, exp: Math.floor(now / 1000) + 43_200, sub: origin })}`;
  const signature = sign("sha256", Buffer.from(data), { key: key.privateKey, dsaEncoding: "ieee-p1363" }).toString("base64url");
  return { Authorization: `vapid t=${data}.${signature}, k=${key.publicKey}`, TTL: "3600", Urgency: "high", "Content-Length": "0" };
}

type PushTransport = (url: string, options: RequestOptions, callback: (response: IncomingMessage) => void) => ClientRequest;
export function sendPush(endpoint: string, headers: Record<string, string>, transport: PushTransport = request, deadlineMs = 10_000): Promise<number> {
  const url = pushEndpoint(endpoint);
  return new Promise((resolve, reject) => {
    // Native HTTPS does not follow redirects or inherit proxy environment variables.
    const outgoing = transport(url, { method: "POST", headers }, (response) => {
      const status = response.statusCode ?? 0;
      response.destroy();
      resolve(status);
    });
    const timer = setTimeout(() => outgoing.destroy(new Error("Push deadline exceeded")), deadlineMs);
    outgoing.once("close", () => clearTimeout(timer));
    outgoing.once("error", () => reject(new Error("Push delivery failed")));
    outgoing.end();
  });
}

export class Push {
  readonly harness: Harness;
  readonly key: VapidKey;
  readonly origin: string;
  readonly identities: readonly string[];
  private readonly send: typeof sendPush;
  constructor(harness: Harness, key: VapidKey, origin: string, identities: readonly string[], send = sendPush) {
    this.harness = harness; this.key = key; this.origin = origin; this.identities = identities; this.send = send;
  }

  static async open(harness: Harness, state: string, origin: string, identities: readonly string[]): Promise<Push> {
    return new Push(harness, await loadVapid(join(state, "vapid.pem")), origin, identities);
  }

  async subscribe(identity: string, input: unknown): Promise<{ subscribed: boolean }> {
    const endpoint = pushEndpoint(input);
    if (!this.identities.includes(identity)) throw new Error("Identity refused");
    return this.harness.commit(async (tx) => {
      const doc = await tx.doc(PushDoc);
      const existing = doc.subscriptions.find((row) => row.endpoint === endpoint);
      if (existing && existing.identity !== identity) throw new Error("Subscription belongs to another identity");
      if (!existing) {
        if (doc.subscriptions.length >= 64) throw new Error("Push subscription limit reached; remove a device");
        doc.subscriptions.push({ id: randomUUID(), endpoint, identity });
      }
      return { subscribed: true };
    }, context);
  }

  async unsubscribe(identity: string, input: unknown): Promise<{ deleted: boolean }> {
    const endpoint = pushEndpoint(input);
    return this.harness.commit(async (tx) => {
      const doc = await tx.doc(PushDoc);
      const index = doc.subscriptions.findIndex((row) => row.endpoint === endpoint && row.identity === identity);
      if (index !== -1) doc.subscriptions.splice(index, 1);
      return { deleted: index !== -1 };
    }, context);
  }

  async notify(): Promise<void> {
    const rows = (await this.harness.snapshot(PushDoc, context))?.subscriptions ?? [];
    const rejected = new Set<string>();
    await Promise.all(rows.map(async (row) => {
      if (!this.identities.includes(row.identity)) { rejected.add(row.id); return; }
      try {
        const status = await this.send(row.endpoint, pushHeaders(this.key, row.endpoint, this.origin));
        if (status === 404 || status === 410) rejected.add(row.id);
      } catch { /* Existing notification claim is at most once; retain transient failures. */ }
    }));
    if (rejected.size) await this.harness.commit(async (tx) => {
      const doc = await tx.doc(PushDoc);
      doc.subscriptions = doc.subscriptions.filter((row) => !rejected.has(row.id));
    }, context);
  }
}
