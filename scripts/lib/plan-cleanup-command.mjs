export function implementedArchiveError(archive, planHash) {
  if (!/^# Implemented:/m.test(archive)) return "archive must start with an Implemented title";
  if (!/^- Source plan: `PLAN\.md`/m.test(archive)) return "archive must name root PLAN.md as source";
  if (!/^- Status: IMPLEMENTED\s*$/m.test(archive)) return "archive must declare Status: IMPLEMENTED";
  const expected = `- Source plan SHA-256: \`${planHash}\``;
  if (!archive.split(/\r?\n/).some((line) => line.trimEnd() === expected)) return "archive source-plan hash does not match current PLAN.md";
  return null;
}
