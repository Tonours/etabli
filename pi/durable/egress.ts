import type { Message } from '@earendil-works/pi-ai';
import { basename, relative } from 'node:path';

export function assertReadable(path: string, cwd: string) {
  const name = basename(path).toLowerCase();
  if (/^(auth\.json|capability|owner\.lock|session\.sqlite(?:-.*)?|credentials.*|\.env(?:\..*)?|.*\.(?:pem|key)|id_(?:rsa|ed25519))$/.test(name) || /(?:^|\/)(?:\.ssh|\.aws|\.gnupg)(?:\/|$)/.test(path)) {
    throw new Error('Credential files are excluded from agent tools; use the configured provider credential store');
  }
  const local = relative(cwd, path);
  if (local === '..' || local.startsWith('../') || local.startsWith('/')) throw new Error('Tool target is outside the current workspace');
}

export function redact(text: string): string {
  let parsed: unknown;
  try { parsed = JSON.parse(text); }
  catch { return redactText(text); }
  const filtered = redactedJson(parsed);
  return filtered === JSON.stringify(parsed) ? redactText(text) : filtered;
}

function redactText(text: string): string {
  return text
    .replace(/-----BEGIN [^-]*PRIVATE KEY-----[\s\S]*?-----END [^-]*PRIVATE KEY-----/g, '[private key removed]')
    .replace(/\b(?:sk-[a-zA-Z0-9_-]{16,}|gh[pousr]_[a-zA-Z0-9_]{16,}|github_pat_[a-zA-Z0-9_]{16,})\b/g, '[credential removed]')
    .replace(/\b([a-z][a-z0-9+.-]*:\/\/)[^\s/@]+@/gi, '$1[credential removed]@')
    .replace(/\b(bearer\s+)[a-zA-Z0-9._~+\/-]+/gi, '$1[credential removed]')
    .replace(/((?:api[_-]?key|(?:auth[_-]?)?token|password|secret)["']?\s*[=:]\s*)("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')/gi, (_match, prefix, value) => `${prefix}${value[0]}[credential removed]${value[0]}`)
    // Escaped JSON fragments lack a parseable boundary: remove the rest of that line.
    .replace(/((?:api[_-]?key|(?:auth[_-]?)?token|password|secret)(?:\\*["'])?\s*[=:]\s*)(\\+["'])[^\r\n]*/gi, '$1$2[credential removed]$2')
    .replace(/((?:api[_-]?key|(?:auth[_-]?)?token|password|secret)(?:\\*["'])?\s*[=:]\s*)(?!\[credential removed\])[^\s"'\\,;}]+/gi, '$1[credential removed]');
}

export function redactedJson(value: unknown) { return JSON.stringify(value, (key, part) => /^(?:api[_-]?key|(?:auth[_-]?)?token|password|secret)$/i.test(key) ? '[credential removed]' : typeof part === 'string' ? redact(part) : part); }

export function egress(provider: string, allowed: string[], messages: readonly Message[]): Message[] {
  if (!allowed.includes(provider)) throw new Error(`Provider ${provider} is outside this session's allowed providers`);
  return JSON.parse(redactedJson(messages)) as Message[];
}
