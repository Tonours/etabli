import { readFileSync, realpathSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { basename, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const number = (value) =>
  typeof value === "number" && Number.isFinite(value) && value >= 0
    ? value
    : null;
const text = (value) =>
  typeof value === "string" && value
    ? value.replace(/[\x00-\x1f\x7f]/g, "")
    : "inconnu";
const show = (value) =>
  value === null ? "inconnu" : String(Number(value.toFixed(1)));
const percent = (value) => (value === null ? "inconnu" : show(value) + "%");

export function normalizeUsage(data) {
  const context = data?.context_window,
    current = context?.current_usage;
  const counters = Object.fromEntries(
    [
      "input_tokens",
      "output_tokens",
      "cache_creation_input_tokens",
      "cache_read_input_tokens",
    ].map((key) => [key, number(current?.[key])]),
  );
  const inputs = [
    counters.input_tokens,
    counters.cache_creation_input_tokens,
    counters.cache_read_input_tokens,
  ];
  const tokens = inputs.every((n) => n !== null)
    ? inputs.reduce((a, b) => a + b, 0)
    : number(context?.total_input_tokens);
  const ratio = number(data?.prompt_cache?.hit_ratio);
  return {
    model: text(data?.model?.display_name),
    effort: text(data?.effort?.level),
    tokens,
    counters,
    used: number(context?.used_percentage),
    remaining: number(context?.remaining_percentage),
    fiveHour: number(data?.rate_limits?.five_hour?.used_percentage),
    sevenDay: number(data?.rate_limits?.seven_day?.used_percentage),
    hitPercent: ratio !== null && ratio <= 1 ? ratio * 100 : null,
    misses: number(data?.prompt_cache?.misses),
    warm:
      typeof data?.prompt_cache?.warm === "boolean"
        ? data.prompt_cache.warm
        : null,
  };
}

export function renderStatusline(data) {
  const usage = normalizeUsage(data),
    cwd =
      typeof (data?.workspace?.current_dir ?? data?.cwd) === "string"
        ? (data.workspace?.current_dir ?? data.cwd)
        : null;
  const gitEnv = Object.fromEntries(
    Object.entries(process.env).filter(([key]) => !key.startsWith("GIT_")),
  );
  const branch = cwd
    ? spawnSync(
        "git",
        ["-C", cwd, "--no-optional-locks", "branch", "--show-current"],
        { encoding: "utf8", timeout: 1000, env: gitEnv },
      ).stdout?.trim()
    : "";
  const dirty =
    branch &&
    spawnSync(
      "git",
      ["-C", cwd, "--no-optional-locks", "status", "--porcelain"],
      { encoding: "utf8", timeout: 1000, env: gitEnv },
    ).stdout?.trim();
  const ctx =
    usage.tokens !== null
      ? `${show(usage.tokens)}t`
      : usage.used !== null
        ? percent(usage.used)
        : "inconnu";
  const remaining =
    usage.remaining === null ? "" : ` (${percent(usage.remaining)} left)`;
  const warmth = usage.warm === null ? "inconnu" : usage.warm ? "warm" : "cold";
  const color = (code, value) => `\x1b[${code}m${value}\x1b[0m`;
  const dir = color("36", cwd ? text(basename(cwd)) : "inconnu");
  const git = branch
    ? ` ${color("34", "git:(")}${color("31", text(branch))}${color("34", ")")}${dirty ? ` ${color("33", "x")}` : ""}`
    : "";
  const ctxColor =
    usage.tokens !== null
      ? usage.tokens < 150000
        ? "32"
        : usage.tokens < 300000
          ? "33"
          : "31"
      : usage.used < 50
        ? "32"
        : usage.used < 80
          ? "33"
          : "31";
  return `${dir}${git} ${color("1", usage.model)} effort:${usage.effort} ${color(ctxColor, `ctx:${ctx}${remaining}`)}\nparent(last) in:${show(usage.counters.input_tokens)} out:${show(usage.counters.output_tokens)} write:${show(usage.counters.cache_creation_input_tokens)} read:${show(usage.counters.cache_read_input_tokens)} cache:${percent(usage.hitPercent)} ${warmth} miss:${show(usage.misses)} | compte 5h:${percent(usage.fiveHour)} 7j:${percent(usage.sevenDay)} | subagents:inconnu\n`;
}
let isMain = false;
try {
  isMain = Boolean(
    process.argv[1] &&
      realpathSync(process.argv[1]) === fileURLToPath(import.meta.url),
  );
} catch {}
if (isMain) {
  try {
    process.stdout.write(renderStatusline(JSON.parse(readFileSync(0, "utf8"))));
  } catch (error) {
    process.stderr.write(`invalid statusline JSON: ${error.message}\n`);
    process.exitCode = 2;
  }
}
