import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";

const BLOCKED_PROVIDERS = new Set(["google-antigravity", "google-gemini-cli"]);

type ProviderModel = {
  provider: string;
  id: string;
};

type ModelRegistry = Pick<ExtensionContext["modelRegistry"], "find">;

export const CONFIGURED_DEFAULT_MODEL: ProviderModel = {
  provider: "zai",
  id: "glm-5.1",
};

const FALLBACKS: readonly ProviderModel[] = [
  CONFIGURED_DEFAULT_MODEL,
  { provider: "github-copilot", id: "gpt-5.4" },
  { provider: "openai-codex", id: "gpt-5.3-codex" },
  { provider: "github-copilot", id: "gpt-5.3-codex" },
];

function isBlocked(model: ProviderModel | undefined): boolean {
  return model !== undefined && BLOCKED_PROVIDERS.has(model.provider);
}

function formatModel(model: ProviderModel | undefined): string {
  return model ? `${model.provider}/${model.id}` : "none";
}

function modelKey(model: ProviderModel): string {
  return `${model.provider}/${model.id}`;
}

export function buildAllowedCandidates(
  registry: ModelRegistry,
  preferred?: ProviderModel,
): ProviderModel[] {
  const candidates = new Map<string, ProviderModel>();

  if (preferred && !isBlocked(preferred)) {
    candidates.set(modelKey(preferred), preferred);
  }

  for (const fallback of FALLBACKS) {
    const model = registry.find(fallback.provider, fallback.id);
    if (!model || isBlocked(model)) continue;
    candidates.set(modelKey(model), model);
  }

  return [...candidates.values()];
}

function hasConfiguredDefaultModel(registry: ModelRegistry): boolean {
  return registry.find(CONFIGURED_DEFAULT_MODEL.provider, CONFIGURED_DEFAULT_MODEL.id) !== undefined;
}

export default function (pi: ExtensionAPI) {
  let switching = false;
  let warnedMissingConfiguredDefaultModel = false;

  async function switchToAllowed(
    ctx: ExtensionContext,
    preferred?: ProviderModel,
  ): Promise<ProviderModel | undefined> {
    if (switching) return undefined;

    const candidates = buildAllowedCandidates(ctx.modelRegistry, preferred);

    switching = true;
    try {
      for (const candidate of candidates) {
        const ok = await pi.setModel(candidate);
        if (ok) return candidate;
      }
      return undefined;
    } finally {
      switching = false;
    }
  }

  async function restorePreviousModel(
    previousModel?: ProviderModel,
  ): Promise<ProviderModel | undefined> {
    if (!previousModel || isBlocked(previousModel)) return undefined;
    const ok = await pi.setModel(previousModel);
    return ok ? previousModel : undefined;
  }

  async function enforceAllowedModel(
    ctx: ExtensionContext,
    preferred?: ProviderModel,
  ): Promise<ProviderModel | undefined> {
    if (!isBlocked(ctx.model)) return ctx.model;
    return switchToAllowed(ctx, preferred);
  }

  function validateConfiguredDefaultModel(ctx: ExtensionContext): void {
    if (hasConfiguredDefaultModel(ctx.modelRegistry)) {
      warnedMissingConfiguredDefaultModel = false;
      return;
    }

    if (warnedMissingConfiguredDefaultModel) return;

    warnedMissingConfiguredDefaultModel = true;
    ctx.ui.notify(
      `Configured default model ${formatModel(CONFIGURED_DEFAULT_MODEL)} not available.`,
      "warning",
    );
  }

  async function repairCurrentModel(ctx: ExtensionContext): Promise<void> {
    if (!isBlocked(ctx.model)) return;

    const next = await enforceAllowedModel(ctx);
    if (next) {
      ctx.ui.notify(
        `Google providers disabled. Switched to ${formatModel(next)}.`,
        "warning",
      );
      return;
    }

    ctx.ui.notify(
      "Google providers disabled. No fallback model available.",
      "error",
    );
  }

  pi.on("session_start", async (_event, ctx) => {
    validateConfiguredDefaultModel(ctx);
    await repairCurrentModel(ctx);
  });

  pi.on("session_switch", async (_event, ctx) => {
    validateConfiguredDefaultModel(ctx);
    await repairCurrentModel(ctx);
  });

  pi.on("model_select", async (event, ctx) => {
    if (switching || !isBlocked(event.model)) return;

    const preferred = event.previousModel && !isBlocked(event.previousModel)
      ? event.previousModel
      : undefined;
    const triedPreviousModel = preferred !== undefined;

    const next = await switchToAllowed(ctx, preferred);
    if (next) {
      ctx.ui.notify(
        `Blocked ${formatModel(event.model)}. Using ${formatModel(next)} instead.`,
        "warning",
      );
      return;
    }

    const restored = triedPreviousModel
      ? undefined
      : await restorePreviousModel(event.previousModel);
    if (restored) {
      ctx.ui.notify(
        `Blocked ${formatModel(event.model)}. Restored ${formatModel(restored)}.`,
        "warning",
      );
      return;
    }

    ctx.ui.notify(
      `Blocked ${formatModel(event.model)}. No fallback model available.`,
      "error",
    );
  });

  pi.on("input", async (_event, ctx) => {
    if (!isBlocked(ctx.model)) return { action: "continue" };

    const next = await enforceAllowedModel(ctx);
    if (next) return { action: "continue" };

    ctx.ui.notify(
      "Google providers disabled. Request blocked until you select a non-Google model.",
      "error",
    );
    return { action: "handled" };
  });
}
