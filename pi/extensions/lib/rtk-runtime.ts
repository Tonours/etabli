import { delimiter } from "node:path";

export type RewriteEnv = Record<string, string | undefined> | undefined;
export type RewriteRunner = (command: string, env: RewriteEnv) => string;
export type RtkSpawnContext = {
  command: string;
  cwd: string;
  env: Record<string, string | undefined>;
};

type RewriteError = {
  code?: unknown;
  status?: unknown;
};

function isMissingBinaryError(error: unknown): boolean {
  return typeof error === "object" && error !== null && (error as RewriteError).code === "ENOENT";
}

function isExpectedNoRewriteError(error: unknown): boolean {
  return typeof error === "object" && error !== null && (error as RewriteError).status === 1;
}

export function prependPathToEnv(env: RewriteEnv, pathPrefix: string | null): RewriteEnv {
  if (!pathPrefix) return env;
  return {
    ...(env ?? {}),
    PATH: env?.PATH ? `${pathPrefix}${delimiter}${env.PATH}` : pathPrefix,
  };
}

export function createRtkCommandRewriter(runRewrite: RewriteRunner): (command: string, env?: RewriteEnv) => string {
  const cache = new Map<string, string>();
  let disabled = false;

  return (command: string, env?: RewriteEnv): string => {
    if (command.trim().length === 0) return command;

    const cached = cache.get(command);
    if (cached) return cached;
    if (disabled) return command;

    try {
      const rewritten = runRewrite(command, env).trim();
      const resolved = rewritten.length > 0 && rewritten !== command ? rewritten : command;
      cache.set(command, resolved);
      return resolved;
    } catch (error) {
      if (isMissingBinaryError(error)) {
        disabled = true;
        cache.set(command, command);
        return command;
      }

      if (isExpectedNoRewriteError(error)) {
        cache.set(command, command);
      }

      return command;
    }
  };
}

export function createRtkSpawnHook(options: {
  pathPrefix: string | null;
  rewriteCommand: (command: string, env?: RewriteEnv) => string;
}): (context: RtkSpawnContext) => RtkSpawnContext {
  return (context: RtkSpawnContext): RtkSpawnContext => {
    const env = prependPathToEnv(context.env, options.pathPrefix) ?? context.env;
    const command = options.rewriteCommand(context.command, env);
    return { command, cwd: context.cwd, env };
  };
}
