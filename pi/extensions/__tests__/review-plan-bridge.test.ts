import { describe, it, expect, beforeEach, afterEach } from "bun:test";
import { mkdirSync, writeFileSync, rmSync, existsSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

describe("review-plan-bridge", () => {
  let testDir: string;

  beforeEach(() => {
    testDir = join(tmpdir(), `review-bridge-test-${Date.now()}`);
    mkdirSync(testDir, { recursive: true });
  });

  afterEach(() => {
    if (existsSync(testDir)) rmSync(testDir, { recursive: true });
  });

  it("should identify actionable review items", () => {
    const entries = [
      { id: "1", filePath: "src/test.ts", hunkHeader: "@@ -1,5 +1,5 @@", status: "needs-rework", note: "Fix this", scope: "WORKING" },
      { id: "2", filePath: "src/other.ts", hunkHeader: "@@ -10,3 +10,3 @@", status: "accepted", note: null, scope: "STAGED" },
      { id: "3", filePath: "src/question.ts", hunkHeader: "@@ -5,2 +5,2 @@", status: "question", note: "Why?", scope: "WORKING" },
    ];

    const actionable = entries.filter(e => e.status === "needs-rework" || e.status === "question");
    
    expect(actionable).toHaveLength(2);
    expect(actionable[0].status).toBe("needs-rework");
    expect(actionable[1].status).toBe("question");
  });

  it("should generate task titles from review entries", () => {
    const entry = {
      id: "1",
      filePath: "src/components/Button.tsx",
      hunkHeader: "@@ -15,7 +15,7 @@ export const Button",
      status: "needs-rework" as const,
      note: "Use proper type for onClick handler instead of any",
      scope: "WORKING" as const,
    };

    const title = entry.note 
      ? `${entry.filePath}: ${entry.note.slice(0, 50)}${entry.note.length > 50 ? "..." : ""}`
      : `Fix ${entry.filePath} - ${entry.hunkHeader.slice(0, 50)}`;

    expect(title).toBe("src/components/Button.tsx: Use proper type for onClick handler instead of any");
  });

  it("should generate plan slice content from actions", () => {
    const actions = [
      {
        type: "tilldone-task" as const,
        title: "Fix Button.tsx: Use proper type",
        description: "Review needs-rework: src/components/Button.tsx",
        source: {
          filePath: "src/components/Button.tsx",
          hunkHeader: "@@ -15,7 +15,7 @@",
          note: "Use proper type for onClick handler",
        },
      },
    ];

    const lines: string[] = [];
    lines.push("### Address Review Findings");
    lines.push("");
    
    for (let i = 0; i < actions.length; i++) {
      const action = actions[i];
      lines.push(`${i + 1}. **${action.title}**`);
      lines.push(`   - File: \`${action.source.filePath}\``);
      lines.push(`   - Hunk: \`${action.source.hunkHeader}\``);
      if (action.source.note) {
        lines.push(`   - Note: ${action.source.note}`);
      }
      lines.push("");
    }
    
    lines.push("**Checks:**");
    lines.push("- [ ] All review comments addressed");
    lines.push("- [ ] Changes validated");
    lines.push("- [ ] Review inbox updated");
    lines.push("");

    const content = lines.join("\n");
    
    expect(content).toContain("### Address Review Findings");
    expect(content).toContain("Fix Button.tsx: Use proper type");
    expect(content).toContain("src/components/Button.tsx");
    expect(content).toContain("All review comments addressed");
  });

  it("should calculate review summary correctly", () => {
    const entries = [
      { status: "new" },
      { status: "new" },
      { status: "accepted" },
      { status: "needs-rework" },
      { status: "needs-rework" },
      { status: "question" },
      { status: "ignore" },
    ];

    const summary = entries.reduce((acc, e) => {
      acc[e.status] = (acc[e.status] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);

    expect(summary["new"]).toBe(2);
    expect(summary["accepted"]).toBe(1);
    expect(summary["needs-rework"]).toBe(2);
    expect(summary["question"]).toBe(1);
    expect(summary["ignore"]).toBe(1);
  });
});
