import { afterEach, describe, expect, test } from "bun:test";
import { chmodSync, mkdtempSync, mkdirSync, realpathSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve } from "node:path";
import { resolveDynamicKnowledgeContext, resolveObvaultRoot } from "../../../workflow/runtime/obvault-topic-resolver.mjs";

const temporaryRoots: string[] = [];

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
  symlinkSync(resolve(import.meta.dir, "../../../../obvault/_meta"), resolve(root, "_meta"), "dir");
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

  test("fails open when the metadata resolver times out", () => {
    const root = mkdtempSync(resolve(tmpdir(), "etabli-slow-obvault-router-"));
    temporaryRoots.push(root);
    mkdirSync(resolve(root, "_meta"));
    writeFileSync(resolve(root, "AGENTS.md"), "# Slow test vault\n");
    writeFileSync(resolve(root, "_meta/obvault"), "#!/usr/bin/env node\nsetTimeout(() => {}, 5000);\n");
    chmodSync(resolve(root, "_meta/obvault"), 0o755);

    expect(resolveDynamicKnowledgeContext("FinOps", { roots: [root], timeoutMs: 20 })).toBeNull();
  });
});
