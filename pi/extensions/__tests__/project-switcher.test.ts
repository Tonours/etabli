import { describe, it, expect } from "bun:test";

describe("project-switcher", () => {
  it("should extract project name from path", () => {
    const paths = [
      { path: "/home/user/projects/my-app", expected: "my-app" },
      { path: "/work/etabli-pi-claude-workflow-optimization", expected: "etabli-pi-claude-workflow-optimization" },
      { path: "./local-project", expected: "local-project" },
    ];

    for (const { path, expected } of paths) {
      const name = path.split("/").pop() || "unnamed";
      expect(name).toBe(expected);
    }
  });

  it("should sort projects by last visited", () => {
    const projects = [
      { name: "old", lastVisited: "2024-01-01T00:00:00Z" },
      { name: "new", lastVisited: "2024-01-03T00:00:00Z" },
      { name: "mid", lastVisited: "2024-01-02T00:00:00Z" },
    ];

    const sorted = projects.sort((a, b) => 
      new Date(b.lastVisited).getTime() - new Date(a.lastVisited).getTime()
    );

    expect(sorted[0].name).toBe("new");
    expect(sorted[1].name).toBe("mid");
    expect(sorted[2].name).toBe("old");
  });
});
