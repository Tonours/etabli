import { describe, expect, test } from "bun:test";
import minimalFooter from "../minimal-footer.ts";

type FooterFactory = (
  tui: { requestRender(): void },
  theme: { fg(color: string, text: string): string },
  footerData: {
    onBranchChange(callback: () => void): () => void;
    getGitBranch(): string | null;
    getExtensionStatuses(): ReadonlyMap<string, string>;
  },
) => {
  dispose?: () => void;
  invalidate(): void;
  render(width: number): string[];
};

type TestContext = {
  hasUI: boolean;
  cwd: string;
  model?: { id: string };
  ui: {
    setFooter: (factory: FooterFactory) => void;
  };
};

type EventHandlers = {
  session_start?: (event: unknown, ctx: TestContext) => Promise<void>;
  model_select?: (event: unknown, ctx: TestContext) => Promise<void>;
  turn_start?: (event: unknown, ctx: TestContext) => Promise<void>;
};

describe("minimal-footer", () => {
  test("reads the latest thinking level at render time", async () => {
    const handlers: EventHandlers = {};
    let thinkingLevel = "low";
    let footerFactory: FooterFactory | undefined;

    const pi = {
      on(event: keyof EventHandlers, handler: unknown) {
        handlers[event] = handler as EventHandlers[keyof EventHandlers];
      },
      getThinkingLevel() {
        return thinkingLevel;
      },
    };

    minimalFooter(pi as Parameters<typeof minimalFooter>[0]);

    const ctx: TestContext = {
      hasUI: true,
      cwd: "/tmp/etabli",
      model: { id: "gpt-5.4" },
      ui: {
        setFooter(factory) {
          footerFactory = factory;
        },
      },
    };

    if (!handlers.session_start) {
      throw new Error("session_start handler not registered");
    }

    await handlers.session_start(undefined, ctx);

    if (!footerFactory) {
      throw new Error("footer factory not registered");
    }

    const component = footerFactory(
      { requestRender() {} },
      {
        fg(_color: string, text: string) {
          return text;
        },
      },
      {
        onBranchChange() {
          return () => {};
        },
        getGitBranch() {
          return "main";
        },
        getExtensionStatuses() {
          return new Map<string, string>();
        },
      },
    );

    expect(component.render(80)[0]).toContain("gpt-5.4 - low");

    thinkingLevel = "high";

    expect(component.render(80)[0]).toContain("gpt-5.4 - high");
  });
});
