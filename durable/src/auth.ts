import { createHash, randomBytes, randomUUID, timingSafeEqual } from "node:crypto";
import { constants } from "node:fs";
import { link, open, unlink } from "node:fs/promises";
import type { IncomingMessage } from "node:http";

export async function readToken(path: string): Promise<string> {
  const file = await open(path, constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
  try {
    const info = await file.stat();
    if (!info.isFile() || (info.mode & 0o777) !== 0o600 || info.uid !== process.getuid?.() || info.size > 128) throw new Error("Token must be an owned 0600 regular file");
    const token = (await file.readFile("utf8")).trim();
    if (!/^[A-Za-z0-9_-]{43}$/.test(token)) throw new Error("Invalid token file");
    return token;
  } finally { await file.close(); }
}

export async function loadToken(path: string): Promise<string> {
  try { return await readToken(path); }
  catch (error) { if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error; }
  const temporary = `${path}.${randomUUID()}.tmp`;
  const file = await open(temporary, "wx", 0o600);
  try {
    try { await file.writeFile(`${randomBytes(32).toString("base64url")}\n`); await file.sync(); }
    finally { await file.close(); }
    await link(temporary, path).catch((error: NodeJS.ErrnoException) => { if (error.code !== "EEXIST") throw error; });
  } finally { await unlink(temporary); }
  return readToken(path);
}

export function webOrigin(raw: unknown): string {
  if (typeof raw !== "string") throw new Error("webOrigin must be an exact HTTPS origin");
  const url = new URL(raw);
  if (url.protocol !== "https:" || url.origin !== raw || url.username || url.password) throw new Error("webOrigin must be an exact HTTPS origin");
  return raw;
}

export function apiConfig(raw: unknown): { port: number; identities: string[]; webOrigin?: string } | undefined {
  if (raw === undefined) return undefined;
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) throw new Error("api must contain port and identities");
  const { port, identities, webOrigin: origin } = raw as Record<string, unknown>;
  if (!Number.isInteger(port) || typeof port !== "number" || port < 1 || port > 65535 || !Array.isArray(identities) || identities.length < 1 || identities.length > 32 || identities.some((value) => typeof value !== "string" || !/^[\x21-\x7e]{1,254}$/.test(value) || value.includes(","))) throw new Error("api requires a valid port and nonempty exact-login identities");
  return { port, identities, ...(origin === undefined ? {} : { webOrigin: webOrigin(origin) }) };
}

export function singleHeader(request: IncomingMessage, name: string): string | undefined {
  const values: string[] = [];
  for (let i = 0; i < request.rawHeaders.length; i += 2) if (request.rawHeaders[i].toLowerCase() === name) values.push(request.rawHeaders[i + 1]);
  return values.length === 1 ? values[0] : undefined;
}

export function remoteIdentity(request: IncomingMessage, identities: readonly string[]): string | undefined {
  const identity = singleHeader(request, "tailscale-user-login");
  return identity && identities.includes(identity) ? identity : undefined;
}

export function remoteAuth(token: string, identities: readonly string[]): (request: IncomingMessage) => 401 | 403 | undefined {
  if (!/^[A-Za-z0-9_-]{43}$/.test(token) || !identities.length) throw new Error("Remote authorization requires a token and identities");
  const expected = createHash("sha256").update(token).digest();
  return (request) => {
    const supplied = singleHeader(request, "authorization")?.match(/^Bearer ([A-Za-z0-9_-]{43})$/)?.[1] ?? "";
    if (!timingSafeEqual(createHash("sha256").update(supplied).digest(), expected)) return 401;
    if (!remoteIdentity(request, identities)) return 403;
    return undefined;
  };
}
