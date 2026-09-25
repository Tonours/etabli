/**
 * Single adapter for Pi's native skills loader + formatter.
 * The package root is ESM-only (no "require" export condition) and the deep
 * subpath is unexported, so bare require()/import() specifiers fail under
 * Node; the file-URL dynamic import below works on Node + Bun (verified:
 * identical 49-skill listing bytes on both runtimes). All native-loader
 * consumers import this module — never rebuild the URL elsewhere.
 * Throws a diagnosed error when the install layout is absent.
 */
export async function loadPiSkillsModule() {
  const here = new URL(import.meta.url);
  // scripts/lib/ -> repo root.
  const repoRoot = new URL("../../", here);
  const piIndex = new URL(
    "pi/node_modules/@earendil-works/pi-coding-agent/dist/index.js",
    repoRoot,
  );
  try {
    return await import(piIndex);
  } catch (error) {
    throw new Error(
      `cannot load Pi skills module at ${piIndex.pathname} (is pi/node_modules installed?): ${error.message}`,
    );
  }
}
