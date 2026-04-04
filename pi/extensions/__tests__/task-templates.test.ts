import { describe, it, expect } from "bun:test";

describe("task-templates", () => {
  it("should find template by name", () => {
    const templates = [
      { name: "new-feature", category: "dev" },
      { name: "bug-fix", category: "maintenance" },
    ];

    const found = templates.find(t => 
      t.name.toLowerCase() === "new-feature" ||
      t.name.toLowerCase().includes("feature")
    );

    expect(found?.name).toBe("new-feature");
  });

  it("should format task list for tilldone", () => {
    const tasks = ["Task 1", "Task 2", "Task 3"];
    const formatted = tasks.map(t => `"${t.replace(/"/g, '\"')}"`).join(", ");
    expect(formatted).toBe('"Task 1", "Task 2", "Task 3"');
  });
});
