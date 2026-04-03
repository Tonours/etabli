declare module "node:child_process" {
  export function execFileSync(
    command: string,
    args?: string[],
    options?: {
      encoding?: string;
      stdio?: [string, string, string];
    },
  ): string;
}

declare module "node:fs" {
  export function existsSync(path: string): boolean;
  export function readFileSync(path: string, encoding: string): string;
  export function realpathSync(path: string): string;
  export function statSync(path: string): { mtimeMs: number; size: number };
}

declare module "node:url" {
  export function fileURLToPath(url: string): string;
}

declare module "node:os" {
  export function homedir(): string;
}

declare module "node:path" {
  export function dirname(path: string): string;
  export function join(...parts: string[]): string;
  export function resolve(...parts: string[]): string;
}

declare const process: {
  env: Record<string, string | undefined>;
};
