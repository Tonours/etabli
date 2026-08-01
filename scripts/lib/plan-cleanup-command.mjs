/**
 * Recognize the only shell form permitted to remove a completed root PLAN.md.
 * The executable performs the state checks; this lexical gate only prevents
 * shell chaining, alternate paths, and arbitrary arguments.
 */
export function isNarrowPlanCleanupCommand(command) {
  const value = String(command || "").trim();
  if (!value || /[;&|<>`\n]/.test(value) || /\$\(/.test(value)) return false;
  return /^(?:node\s+|bun\s+|bash\s+)?(?:\.\/)?scripts\/plan-cleanup\s+--archive\s+(?:\.\/)?docs\/plan\/[A-Za-z0-9][A-Za-z0-9._-]*\.md$/.test(value);
}
