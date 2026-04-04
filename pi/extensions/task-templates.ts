/**
 * Task Templates
 *
 * Predefined templates for common task patterns.
 * Reduces repetition and ensures consistency.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";

interface TaskTemplate {
  name: string;
  description: string;
  tasks: string[];
  category: string;
}

const templates: TaskTemplate[] = [
  {
    name: "new-feature",
    description: "Standard flow for implementing a new feature",
    category: "development",
    tasks: [
      "Explore codebase and understand existing patterns",
      "Create DRAFT PLAN.md with goal and scope",
      "Run plan-review to harden the plan",
      "Implement slice 1: Setup and scaffolding",
      "Implement slice 2: Core functionality",
      "Implement slice 3: Edge cases and error handling",
      "Run validation checks",
      "Update documentation",
      "Final review and handoff",
    ],
  },
  {
    name: "bug-fix",
    description: "Structured approach to fixing bugs",
    category: "maintenance",
    tasks: [
      "Reproduce the bug and understand the issue",
      "Identify root cause through code analysis",
      "Create minimal reproduction test case",
      "Implement fix with minimal changes",
      "Verify fix resolves the issue",
      "Check for regressions",
      "Update tests if needed",
      "Document the fix in commit message",
    ],
  },
  {
    name: "refactor",
    description: "Safe refactoring workflow",
    category: "maintenance",
    tasks: [
      "Identify code smells and improvement areas",
      "Ensure existing tests pass",
      "Create backup/rollback plan",
      "Refactor incrementally with small steps",
      "Run tests after each change",
      "Verify no behavioral changes",
      "Update documentation",
      "Clean up deprecated code",
    ],
  },
  {
    name: "review-cycle",
    description: "Processing code review feedback",
    category: "review",
    tasks: [
      "Read all review comments carefully",
      "Categorize feedback: critical, suggestion, nitpick",
      "Address critical issues first",
      "Implement agreed-upon changes",
      "Respond to comments",
      "Re-request review when ready",
      "Follow up on unresolved items",
    ],
  },
  {
    name: "pi-extension",
    description: "Creating a new Pi extension",
    category: "pi-dev",
    tasks: [
      "Define extension purpose and API",
      "Create extension file in pi/extensions/",
      "Implement extension logic with TypeScript",
      "Add tests in pi/extensions/__tests__/",
      "Build and verify compilation",
      "Update documentation",
      "Register extension in Pi settings if needed",
    ],
  },
  {
    name: "nvim-plugin",
    description: "Adding Neovim integration",
    category: "nvim-dev",
    tasks: [
      "Define plugin purpose and commands",
      "Create Lua module in nvim/lua/plugins/ or nvim/lua/config/",
      "Implement core functionality",
      "Add user commands and keymaps",
      "Test in Neovim",
      "Update CHEATSHEET.md",
      "Verify lazy loading works correctly",
    ],
  },
  {
    name: "ops-workflow",
    description: "Improving OPS workflow integration",
    category: "workflow",
    tasks: [
      "Identify friction point in current workflow",
      "Analyze OPS snapshot structure",
      "Design extension to bridge the gap",
      "Implement Pi extension for data export",
      "Implement Neovim module for data display",
      "Add validation and tests",
      "Update workflow documentation",
      "Verify cross-runtime compatibility",
    ],
  },
];

function findTemplate(name: string): TaskTemplate | undefined {
  return templates.find(
    (t) =>
      t.name.toLowerCase() === name.toLowerCase() ||
      t.name.toLowerCase().includes(name.toLowerCase())
  );
}

function formatTemplate(template: TaskTemplate): string {
  const lines: string[] = [];
  lines.push(`# ${template.name}`);
  lines.push(`Category: ${template.category}`);
  lines.push("");
  lines.push(template.description);
  lines.push("");
  lines.push("Tasks:");
  for (let i = 0; i < template.tasks.length; i++) {
    lines.push(`${i + 1}. ${template.tasks[i]}`);
  }
  return lines.join("\n");
}

export default function (pi: ExtensionAPI) {
  // Command to list templates
  pi.registerCommand("templates", {
    description: "List available task templates",
    handler: async (_args, ctx) => {
      const lines: string[] = [];
      lines.push("📋 Task Templates");
      lines.push("");

      const categories = [...new Set(templates.map((t) => t.category))];

      for (const category of categories) {
        lines.push(`${category}:`);
        const categoryTemplates = templates.filter((t) => t.category === category);
        for (const t of categoryTemplates) {
          lines.push(`  ${t.name} - ${t.description}`);
        }
        lines.push("");
      }

      lines.push("Use `/template-use <name>` to create tasks from template");

      pi.sendMessage({
        customType: "template-list",
        content: lines.join("\n"),
        display: true,
      });

      ctx.ui.notify(`${templates.length} templates available`, "info");
    },
  });

  // Command to use a template
  pi.registerCommand("template-use", {
    description: "Create TillDone tasks from a template",
    handler: async (args, ctx) => {
      const name = args.trim();
      if (!name) {
        ctx.ui.notify("Usage: /template-use <template-name>", "warning");
        return;
      }

      const template = findTemplate(name);
      if (!template) {
        ctx.ui.notify(
          `Template "${name}" not found. Use /templates to see available templates.`,
          "error"
        );
        return;
      }

      // Generate tilldone command
      const taskList = template.tasks.map((t) => `"${t.replace(/"/g, '\"')}"`).join(", ");
      const command = `tilldone new-list "${template.name}" texts:[${taskList}]`;

      const lines: string[] = [];
      lines.push(formatTemplate(template));
      lines.push("");
      lines.push("---");
      lines.push("Run this command to create the tasks:");
      lines.push(command);

      pi.sendMessage({
        customType: "template-use",
        content: lines.join("\n"),
        display: true,
      });

      ctx.ui.notify(`Template "${template.name}" ready - ${template.tasks.length} tasks`, "info");
    },
  });

  // Tool to get template
  pi.registerTool({
    name: "task_template_get",
    label: "Task Template Get",
    description: "Get a task template by name. Returns the template tasks ready for tilldone.",
    parameters: Type.Object({
      name: Type.String({ description: "Template name (or partial match)" }),
    }),
    async execute(_toolCallId, args, _signal, _onUpdate, _ctx) {
      const { name } = args as { name: string };
      const template = findTemplate(name);

      if (!template) {
        const available = templates.map((t) => ({ name: t.name, category: t.category }));
        return {
          content: [
            {
              type: "text" as const,
              text: `Template "${name}" not found. Available templates:\n${templates.map((t) => `  - ${t.name} (${t.category})`).join("\n")}`,
            },
          ],
          details: { found: false, available },
        };
      }

      const taskList = template.tasks.map((t) => `"${t.replace(/"/g, '\"')}"`).join(", ");

      return {
        content: [
          {
            type: "text" as const,
            text: `Template: ${template.name}\n${template.description}\n\nTasks:\n${template.tasks.map((t, i) => `${i + 1}. ${t}`).join("\n")}\n\nUse: tilldone new-list "${template.name}" texts:[${taskList}]`,
          },
        ],
        details: {
          found: true,
          template: {
            name: template.name,
            category: template.category,
            tasks: template.tasks,
          },
          tilldoneCommand: `tilldone new-list "${template.name}" texts:[${taskList}]`,
        },
      };
    },
  });

  // Tool to list templates
  pi.registerTool({
    name: "task_template_list",
    label: "Task Template List",
    description: "List all available task templates",
    parameters: Type.Object({}),
    async execute() {
      const lines: string[] = [];
      lines.push("Available task templates:");
      lines.push("");

      const categories = [...new Set(templates.map((t) => t.category))];
      for (const category of categories) {
        lines.push(`${category}:`);
        const categoryTemplates = templates.filter((t) => t.category === category);
        for (const t of categoryTemplates) {
          lines.push(`  ${t.name}: ${t.description} (${t.tasks.length} tasks)`);
        }
        lines.push("");
      }

      return {
        content: [{ type: "text" as const, text: lines.join("\n") }],
        details: {
          templates: templates.map((t) => ({
            name: t.name,
            category: t.category,
            taskCount: t.tasks.length,
          })),
        },
      };
    },
  });
}
