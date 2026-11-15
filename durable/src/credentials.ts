import { chmod, link, lstat, mkdir, open, readFile, realpath, rename, unlink } from "node:fs/promises";
import { dirname, join } from "node:path";
import { randomUUID } from "node:crypto";
import lockfile from "proper-lockfile";
import type { AuthOperationOptions, Credential, CredentialInfo, CredentialStore } from "@earendil-works/pi-ai";

type Credentials = Record<string, Credential>;

class CredentialCallbackError extends Error {
  constructor() { super("Credential update callback failed"); }
}

export class SharedCredentialStore implements CredentialStore {
  readonly path: string;
  readonly waitMs: number;

  constructor(path: string, waitMs = 15_000) {
    this.path = path;
    this.waitMs = waitMs;
  }

  private async locked<T>(fn: (path: string, current: Credentials) => Promise<T>, options?: AuthOperationOptions): Promise<T> {
    let release: (() => Promise<void>) | undefined;
    try {
      options?.signal?.throwIfAborted();
      await mkdir(dirname(this.path), { recursive: true, mode: 0o700 });
      const exists = await lstat(this.path).then(() => true, (error: NodeJS.ErrnoException) => {
        if (error.code !== "ENOENT") throw error;
        return false;
      });
      if (!exists) {
        const temporary = join(dirname(this.path), `.auth-init-${randomUUID()}.tmp`);
        const initial = await open(temporary, "wx", 0o600);
        try {
          await initial.writeFile("{}\n");
          await initial.sync();
        } finally { await initial.close(); }
        try {
          await link(temporary, this.path).catch((error: NodeJS.ErrnoException) => { if (error.code !== "EEXIST") throw error; });
        } finally { await unlink(temporary); }
      }
      const path = await realpath(this.path);
      const deadline = Date.now() + this.waitMs;
      while (!release) {
        options?.signal?.throwIfAborted();
        try {
          release = await lockfile.lock(path, { realpath: true, stale: 30_000, update: 5_000, retries: 0 });
        } catch (error) {
          if ((error as NodeJS.ErrnoException).code !== "ELOCKED" || Date.now() >= deadline) throw error;
          await new Promise<void>((resolve) => setTimeout(resolve, 25));
        }
      }
      options?.signal?.throwIfAborted();
      const parsed: unknown = JSON.parse(await readFile(path, "utf8"));
      if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error();
      return await fn(path, parsed as Credentials);
    } catch (error) {
      if (error instanceof CredentialCallbackError) throw error;
      throw new Error(options?.signal?.aborted ? "Credential operation cancelled" : "Credential storage unavailable");
    } finally {
      await release?.().catch(() => undefined);
    }
  }

  private async persist(path: string, values: Credentials): Promise<void> {
    const temporary = join(dirname(path), `.auth-${randomUUID()}.tmp`);
    try {
      const file = await open(temporary, "wx", 0o600);
      try {
        await file.writeFile(`${JSON.stringify(values, null, 2)}\n`);
        await file.sync();
      } finally {
        await file.close();
      }
      await rename(temporary, path);
      await chmod(path, 0o600);
      const directory = await open(dirname(path), "r");
      try { await directory.sync(); } finally { await directory.close(); }
    } finally {
      await unlink(temporary).catch(() => undefined);
    }
  }

  read(providerId: string, options?: AuthOperationOptions): Promise<Credential | undefined> {
    return this.locked(async (_path, current) => current[providerId], options);
  }

  list(options?: AuthOperationOptions): Promise<readonly CredentialInfo[]> {
    return this.locked(async (_path, current) => Object.entries(current).map(([providerId, credential]) => ({ providerId, type: credential.type })), options);
  }

  modify(providerId: string, fn: (current: Credential | undefined) => Promise<Credential | undefined>, options?: AuthOperationOptions): Promise<Credential | undefined> {
    return this.locked(async (path, current) => {
      let value: Credential | undefined;
      try { value = await fn(current[providerId]); }
      catch { throw new CredentialCallbackError(); }
      if (value !== undefined) {
        current[providerId] = value;
        await this.persist(path, current);
      }
      return current[providerId];
    }, options);
  }

  delete(providerId: string, options?: AuthOperationOptions): Promise<void> {
    return this.locked(async (path, current) => {
      delete current[providerId];
      await this.persist(path, current);
    }, options);
  }
}
