import { afterEach, describe, expect, test } from "bun:test";
import { chmodSync, mkdtempSync, mkdirSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve } from "node:path";
import { resolveDynamicKnowledgeContext, resolveObvaultRoot } from "../../../workflow/runtime/obvault-topic-resolver.mjs";

const temporaryRoots: string[] = [];

// Minimal `obvault route` stub: same JSON contract as
// tests/fixtures/obvault-meta/obvault, but a plain /bin/sh script so each
// spawnSync costs ~5ms instead of a ~45ms node startup.
const ROUTE_STUB = `#!/bin/sh
set -eu
if [ "\${1:-}" != "route" ] || [ "\${2:-}" != "--json" ]; then
  exit 1
fi
prompt="\${3-}"
if case "$prompt" in (*[Ff][Ii][Nn][Oo][Pp][Ss]*) true;; (*) false;; esac && [ -f "\${OBVAULT_ROOT:-/nonexistent}/kb/finops-cost-controls.md" ]; then
  printf '%s\\n' '{"abstained":false,"topics":["finops"],"query":"finops aws billing controls cloud cost","matched_notes":[{"path":"kb/finops-cost-controls.md"}]}'
elif case "$prompt" in (*[Bb][Ff][Ff]*) true;; (*) false;; esac; then
  printf '%s\\n' '{"abstained":false,"topics":["bff"],"query":"bff","matched_notes":[{"path":"kb/finops-cost-controls.md"}]}'
else
  printf '%s\\n' '{"abstained":true,"topics":[],"query":"","matched_notes":[]}'
fi
`;

function writeRouteStub(root: string) {
  mkdirSync(resolve(root, "_meta"));
  writeFileSync(resolve(root, "_meta/obvault"), ROUTE_STUB, { mode: 0o755 });
  chmodSync(resolve(root, "_meta/obvault"), 0o755);
}

function makeVault() {
  const root = mkdtempSync(resolve(tmpdir(), "etabli-obvault-router-"));
  temporaryRoots.push(root);
  mkdirSync(resolve(root, "kb"));
  mkdirSync(resolve(root, "ref"));
  writeFileSync(resolve(root, "AGENTS.md"), "# Test vault\n");
  writeFileSync(resolve(root, "kb/_index.md"), "# Index\n\n- [[finops-cost-controls]]\n");
  writeFileSync(resolve(root, "kb/finops-cost-controls.md"), `---
type: synthesis
status: verified
summary: "Cloud cost controls."
sources:
  - "repo:billing.md"
created: 2026-07-10
updated: 2026-07-10
tags:
  - finops
  - cloud-cost
aliases:
  - AWS billing controls
---
# FinOps Cost Controls
`);
  writeRouteStub(root);
  return root;
}

afterEach(() => {
  for (const root of temporaryRoots.splice(0)) rmSync(root, { recursive: true, force: true });
});

describe("dynamic Obvault topic resolver", () => {
  test("discovers a new verified topic without a built-in router rule", () => {
    const root = makeVault();
    const context = resolveDynamicKnowledgeContext('Donne-moi des idées FinOps"; rm -rf /', { roots: [root] });

    expect(context).toMatchObject({
      topics: ["finops"],
      query: "finops aws billing controls cloud cost",
      source: "obvault-metadata",
      matchedNotes: ["kb/finops-cost-controls.md"],
    });
    expect(context?.command).not.toContain("rm -rf");
  });

  test("keeps three-letter acronym topics such as bff", () => {
    const root = makeVault();
    expect(resolveDynamicKnowledgeContext("rotate the bff api key", { roots: [root] })).toMatchObject({
      topics: ["bff"],
      query: "bff",
    });
  });

  test("fails open for unrelated prompts and missing vaults", () => {
    const root = makeVault();
    expect(resolveDynamicKnowledgeContext("Bonjour, comment vas-tu ?", { roots: [root] })).toBeNull();
    expect(resolveDynamicKnowledgeContext("FinOps", { roots: [resolve(root, "missing")] })).toBeNull();
    expect(resolveObvaultRoot([root])).toBe(realpathSync(root));
  });

  test("observes note removal immediately without rebuilding an index", () => {
    const root = makeVault();
    expect(resolveDynamicKnowledgeContext("FinOps", { roots: [root] })).not.toBeNull();
    rmSync(resolve(root, "kb/finops-cost-controls.md"));
    expect(resolveDynamicKnowledgeContext("FinOps", { roots: [root] })).toBeNull();
  });

  test("treats an explicit OBVAULT_ROOT as exclusive, never falling back to ~/work/obvault", () => {
    const root = makeVault();
    const previous = process.env.OBVAULT_ROOT;
    process.env.OBVAULT_ROOT = resolve(root, "opted-out");
    try {
      // A machine that opts out must resolve to nothing even when a real vault
      // sits at the hardcoded fallback path.
      expect(resolveObvaultRoot()).toBeNull();
      expect(resolveDynamicKnowledgeContext("FinOps")).toBeNull();

      process.env.OBVAULT_ROOT = root;
      expect(resolveObvaultRoot()).toBe(realpathSync(root));
    } finally {
      if (previous === undefined) delete process.env.OBVAULT_ROOT;
      else process.env.OBVAULT_ROOT = previous;
    }
  });

  test("fails open when the metadata resolver times out", () => {
    const root = mkdtempSync(resolve(tmpdir(), "etabli-slow-obvault-router-"));
    temporaryRoots.push(root);
    mkdirSync(resolve(root, "_meta"));
    writeFileSync(resolve(root, "AGENTS.md"), "# Slow test vault\n");
    writeFileSync(resolve(root, "_meta/obvault"), "#!/bin/sh\nexec sleep 5\n");
    chmodSync(resolve(root, "_meta/obvault"), 0o755);

    expect(resolveDynamicKnowledgeContext("FinOps", { roots: [root], timeoutMs: 10 })).toBeNull();
  });
});
