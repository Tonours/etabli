/**
 * Recognize the shell forms permitted to remove root PLAN.md.
 * The executable performs the state checks; this lexical gate only prevents
 * shell chaining, alternate paths, and arbitrary arguments.
 *
 * Modes:
 * - --archive docs/plan/<implemented>.md  (validated implemented archive)
 * - --discard <reason-slug>               (abandon/unrelated plan, no archive)
 */
const RUNNER = String.raw`(?:node\s+|bun\s+|bash\s+)?`;
const CLEANUP_BIN = String.raw`(?:(?:\.\/)?scripts\/plan-cleanup|\/(?:[A-Za-z0-9._-]+\/)*plan-cleanup)`;
const ARCHIVE_ARGS = String.raw`--archive\s+(?:\.\/)?docs\/plan\/[A-Za-z0-9][A-Za-z0-9._-]*\.md`;
const DISCARD_ARGS = String.raw`--discard\s+[a-z0-9][a-z0-9_-]{0,80}`;
const NARROW_PLAN_CLEANUP = new RegExp(
  `^${RUNNER}${CLEANUP_BIN}\\s+(?:${ARCHIVE_ARGS}|${DISCARD_ARGS})$`,
);

export function isNarrowPlanCleanupCommand(command) {
  const value = String(command || "").trim();
  if (!value || /[;&|<>`\n]/.test(value) || /\$\(/.test(value)) return false;
  return NARROW_PLAN_CLEANUP.test(value);
}
