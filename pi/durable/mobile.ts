import { createConnection, type Socket } from 'node:net';
import { lstat } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { BACKGROUND_CONTEXT as ctx } from '@earendil-works/chord/context';
import type { Host } from './host.ts';
import type { ConnectorToExtension } from '../../../pi-mobile/packages/protocol/src/index.ts';
import type { ConversationId } from '@earendil-works/pi-durable';

export class MobileBridge {
  readonly host: Host;
  readonly path: string;
  #socket: Socket | null = null;
  #retry: NodeJS.Timeout | null = null;
  #publish: NodeJS.Timeout | null = null;
  #closed = false;
  #unsubscribe: (() => void) | null = null;
  constructor(host: Host, path: string) { this.host = host; this.path = path; }
  async start() {
    this.#unsubscribe = this.host.onChange(() => {
      if (!this.#publish) this.#publish = setTimeout(() => { this.#publish = null; void this.publish().catch(() => this.#socket?.destroy()); }, 30);
    });
    await this.connect();
  }
  async connect() {
    if (this.#closed) return;
    try {
      const stat = await lstat(this.path);
      if (!stat.isSocket() || stat.uid !== process.getuid?.()) throw new Error('Pi Mobile bridge socket must belong to this user');
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
      this.#retry = setTimeout(() => { void this.connect().catch(() => this.close()); }, 1000); return;
    }
    const socket = createConnection(this.path);
    this.#socket = socket; socket.setEncoding('utf8');
    let buffer = '';
    socket.once('connect', async () => {
      try {
        const state = await this.host.snapshot();
        this.send({ type: 'hello', pid: process.pid, sessionId: state.sessionId, sessionFile: null, cwd: state.state.cwd, model: state.state.model, piVersion: '1.0.0-durable', durableAdmission: true, conversationId: state.conversationId });
        await this.publish();
      } catch { socket.destroy(); }
    });
    socket.on('data', data => {
      buffer += data;
      if (buffer.length > 1024 * 1024) { socket.destroy(); return; }
      let index: number;
      while ((index = buffer.indexOf('\n')) >= 0) {
        const line = buffer.slice(0, index); buffer = buffer.slice(index + 1);
        let request: ConnectorToExtension;
        try { request = JSON.parse(line) as ConnectorToExtension; } catch { socket.destroy(); return; }
        void this.handle(request).catch(() => socket.destroy());
      }
    });
    socket.once('close', () => { if (!this.#closed) this.#retry = setTimeout(() => { void this.connect().catch(() => this.close()); }, 1000); });
    socket.on('error', () => socket.destroy());
  }
  send(message: unknown) { if (this.#socket && !this.#socket.destroyed) this.#socket.write(JSON.stringify(message) + '\n'); }
  async publish() {
    const snapshot = await this.host.snapshot();
    this.send({ type: 'event', sessionId: snapshot.sessionId, seq: snapshot.seq, event: { kind: 'durable_state', snapshot } });
  }
  async handle(request: ConnectorToExtension) {
    if (request.type === 'snapshot_request') { this.send({ ...await this.host.snapshot(), type: 'snapshot', reqId: request.reqId }); return; }
    if (request.type === 'send') {
      try {
        const state = await this.host.snapshot();
        const id = request.admissionId ?? randomUUID();
        const receipt = await this.host.admit(id, { session: state.sessionId, conversation: (request.conversationId ?? state.conversationId) as ConversationId, text: request.text, deliverAs: request.deliverAs });
        this.send({ type: 'send_result', reqId: request.reqId, outcome: receipt.status, detail: null, admissionId: id, durableAdmission: Boolean(request.admissionId) });
      } catch (error) { this.send({ type: 'send_result', reqId: request.reqId, outcome: 'failed', detail: error instanceof Error ? error.message : 'Admission failed', durableAdmission: false }); }
      return;
    }
    if (request.type === 'abort') {
      await this.host.root.abort(ctx, { background: true });
      this.send({ type: 'abort_result', reqId: request.reqId, ok: true, detail: null });
    }
  }
  close() {
    this.#closed = true; this.#unsubscribe?.();
    if (this.#retry) clearTimeout(this.#retry);
    if (this.#publish) clearTimeout(this.#publish);
    this.#socket?.destroy();
  }
}
