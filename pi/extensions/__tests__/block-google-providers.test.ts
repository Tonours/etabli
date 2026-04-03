import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import blockGoogleProviders, {
  CONFIGURED_DEFAULT_MODEL,
  buildAllowedCandidates,
} from "../block-google-providers.ts";

type ProviderModel = {
  provider: string;
  id: string;
};

type Level = "warning" | "error" | "info";

type Notification = {
  message: string;
  level: Level;
};

type TestContext = {
  model?: ProviderModel;
  modelRegistry: {
    find(provider: string, id: string): ProviderModel | undefined;
  };
  ui: {
    notifications: Notification[];
    notify(message: string, level: Level): void;
  };
};

type EventHandlers = {
  model_select?: (event: { model: ProviderModel; previousModel?: ProviderModel }, ctx: TestContext) => Promise<void>;
  session_start?: (event: unknown, ctx: TestContext) => Promise<void>;
  session_switch?: (event: unknown, ctx: TestContext) => Promise<void>;
};

function createRegistry(models: ProviderModel[]) {
  return {
    find(provider: string, id: string): ProviderModel | undefined {
      return models.find((model) => model.provider === provider && model.id === id);
    },
  };
}

function createContext(models: ProviderModel[], model?: ProviderModel): TestContext {
  const notifications: Notification[] = [];

  return {
    model,
    modelRegistry: createRegistry(models),
    ui: {
      notifications,
      notify(message: string, level: Level) {
        notifications.push({ message, level });
      },
    },
  };
}

function setupExtension(setModelImpl: (model: ProviderModel) => boolean | Promise<boolean>) {
  const handlers: EventHandlers = {};
  const calls: ProviderModel[] = [];

  const pi = {
    on(event: keyof EventHandlers, handler: unknown) {
      handlers[event] = handler as never;
    },
    async setModel(model: ProviderModel): Promise<boolean> {
      calls.push(model);
      return await setModelImpl(model);
    },
  };

  blockGoogleProviders(pi as Parameters<typeof blockGoogleProviders>[0]);

  return { calls, handlers };
}

describe("buildAllowedCandidates", () => {
  test("dedupes preferred model against fallback registry matches", () => {
    const preferred = { provider: "openai-codex", id: "gpt-5.4" };
    const candidates = buildAllowedCandidates(
      createRegistry([
        { provider: "openai-codex", id: "gpt-5.4" },
        { provider: "github-copilot", id: "gpt-5.4" },
        { provider: "openai-codex", id: "gpt-5.3-codex" },
        { provider: "github-copilot", id: "gpt-5.3-codex" },
      ]),
      preferred,
    );

    expect(candidates).toEqual([
      { provider: "openai-codex", id: "gpt-5.4" },
      { provider: "github-copilot", id: "gpt-5.4" },
      { provider: "openai-codex", id: "gpt-5.3-codex" },
      { provider: "github-copilot", id: "gpt-5.3-codex" },
    ]);
  });
});

describe("model_select", () => {
  test("tries previous model once and reports fallback usage", async () => {
    const previousModel = { provider: "anthropic", id: "claude-sonnet-4" };
    const blockedModel = { provider: "google-antigravity", id: "gemini-2.5-pro" };
    const { calls, handlers } = setupExtension(async (model) => {
      return model.provider === previousModel.provider && model.id === previousModel.id;
    });
    const ctx = createContext([]);

    if (!handlers.model_select) throw new Error("model_select handler not registered");
    await handlers.model_select({ model: blockedModel, previousModel }, ctx);

    expect(calls).toEqual([previousModel]);
    expect(ctx.ui.notifications).toEqual([
      {
        message: "Blocked google-antigravity/gemini-2.5-pro. Using anthropic/claude-sonnet-4 instead.",
        level: "warning",
      },
    ]);
  });
});

describe("configured default model", () => {
  test("matches pi/agent/settings.json", () => {
    const settings = JSON.parse(
      readFileSync(new URL("../../agent/settings.json", import.meta.url), "utf-8"),
    ) as {
      defaultProvider: string;
      defaultModel: string;
    };

    expect(settings.defaultProvider).toBe(CONFIGURED_DEFAULT_MODEL.provider);
    expect(settings.defaultModel).toBe(CONFIGURED_DEFAULT_MODEL.id);
  });

  test("warns once when configured default model is missing", async () => {
    const { handlers } = setupExtension(async () => false);
    const ctx = createContext([]);

    if (!handlers.session_start || !handlers.session_switch) {
      throw new Error("session handlers not registered");
    }

    await handlers.session_start(undefined, ctx);
    await handlers.session_switch(undefined, ctx);

    expect(ctx.ui.notifications).toEqual([
      {
        message: "Configured default model zai/glm-5.1 not available.",
        level: "warning",
      },
    ]);
  });

  test("does not warn when configured default model is present", async () => {
    const { handlers } = setupExtension(async () => false);
    const ctx = createContext([{ ...CONFIGURED_DEFAULT_MODEL }]);

    if (!handlers.session_start) throw new Error("session_start handler not registered");
    await handlers.session_start(undefined, ctx);

    expect(ctx.ui.notifications).toEqual([]);
  });
});
