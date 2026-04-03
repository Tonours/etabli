const TASK_PREFIX_PATTERNS = [
  /^please\s+/i,
  /^pls\s+/i,
  /^can you\s+/i,
  /^could you\s+/i,
  /^would you\s+/i,
  /^will you\s+/i,
  /^i need to\s+/i,
  /^we need to\s+/i,
  /^need to\s+/i,
  /^i want to\s+/i,
  /^we should\s+/i,
  /^should\s+/i,
  /^let(?:')?s\s+/i,
  /^try to\s+/i,
  /^maybe\s+/i,
  /^probably\s+/i,
  /^just\s+/i,
];

const LEADING_HEDGE_PATTERNS = [/^maybe\s+/i, /^probably\s+/i, /^just\s+/i, /^kind of\s+/i];

function normalizeIntentText(text: string): string {
  return text.trim().replace(/\s+/g, " ").replace(/[.!?。]+$/u, "").trim();
}

function stripMatchingPrefixes(text: string, patterns: RegExp[]): string {
  let next = text;
  let changed = true;

  while (changed) {
    changed = false;
    for (const pattern of patterns) {
      const stripped = next.replace(pattern, "").trim();
      if (stripped !== next) {
        next = stripped;
        changed = true;
      }
    }
  }

  return next;
}

export function compileTodoIntent(text: string): string {
  const normalized = normalizeIntentText(text);
  if (!normalized) return "";

  const withoutWrappers = stripMatchingPrefixes(normalized, TASK_PREFIX_PATTERNS);
  const withoutHedges = stripMatchingPrefixes(withoutWrappers, LEADING_HEDGE_PATTERNS);
  return normalizeIntentText(withoutHedges || normalized);
}
