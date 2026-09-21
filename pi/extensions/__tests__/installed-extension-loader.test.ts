import { describe, expect, test } from "bun:test";
import { execFileSync, spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, mkdirSync, readFileSync, realpathSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";

const root = resolve(import.meta.dir, "../../..");
const piLookup = spawnSync("which", ["pi"], { encoding: "utf8" });
const piLauncher = piLookup.status === 0 ? piLookup.stdout.trim() : "";
const repositoryExtensions = [
	"filter-output.ts",
	"jev-route-capsule-runtime.ts",
	"no-comments.ts",
	"prefer-ipv4-dns.ts",
	"rtk.ts",
	"token-rate.ts",
	"workflow-router.ts",
	"workflow-run-binding.ts",
	"workflow-tools.ts",
];

function resolveInstalledRuntime() {
	const launcherTrace = spawnSync("bash", ["-x", piLauncher, "--version"], { encoding: "utf8" });
	const activeExec = launcherTrace.stderr.match(/\+ exec (\S+) (\S+\/dist\/(?:bundle\/)?cli\.js) --version/);
	const activeNode = activeExec?.[1];
	const activeCli = activeExec?.[2];
	if (launcherTrace.status !== 0 || !activeNode || !activeCli) throw new Error("unable to resolve active Pi runtime");
	const activeNodePath = realpathSync(activeNode);
	let packageRoot = dirname(realpathSync(activeCli));
	while (!existsSync(join(packageRoot, "package.json")) && dirname(packageRoot) !== packageRoot) packageRoot = dirname(packageRoot);
	return {
		activeNodePath,
		activePiVersion: launcherTrace.stdout.trim(),
		loaderPath: join(packageRoot, "dist/core/extensions/loader.js"),
		packageVersion: JSON.parse(readFileSync(join(packageRoot, "package.json"), "utf8")).version as string,
	};
}

function loadWithNode(activeNodePath: string, loaderPath: string, paths: string[]) {
	const source = `import { loadExtensions } from ${JSON.stringify(loaderPath)}; const result = await loadExtensions(${JSON.stringify(paths)}, ${JSON.stringify(root)}); console.log(JSON.stringify({ loaded: result.extensions.map((item) => item.path), errors: result.errors }));`;
	return JSON.parse(execFileSync(activeNodePath, ["--input-type=module", "-e", source], { encoding: "utf8" }));
}

describe("installed Pi extension loader", () => {
	test("reproduces the logical-path failure and loads every extension with the managed layout", () => {
		if (!piLauncher) return;
		const { activeNodePath, activePiVersion, loaderPath, packageVersion } = resolveInstalledRuntime();
		const cwd = mkdtempSync(join(tmpdir(), "etabli-pi-loader-"));
		try {
			const agent = join(cwd, ".pi/agent");
			const extensions = join(agent, "extensions");
			mkdirSync(agent, { recursive: true });
			symlinkSync(join(root, "scripts"), join(cwd, ".pi/scripts"));
			symlinkSync(join(root, "workflow"), join(cwd, ".pi/workflow"));
			symlinkSync(join(root, "pi/extensions"), extensions);

			const baseline = join(cwd, "baseline/.pi/agent/extensions");
			mkdirSync(baseline, { recursive: true });
			writeFileSync(join(baseline, "workflow-router.ts"), 'import "../../scripts/lib/usage-accounting.mjs"; export default function () {}\n');
			writeFileSync(join(baseline, "workflow-run-binding.ts"), 'import "../../scripts/lib/ledger-auto-emit.mjs"; export default function () {}\n');
			const baselineResult = loadWithNode(activeNodePath, loaderPath, [join(baseline, "workflow-router.ts"), join(baseline, "workflow-run-binding.ts")]);
			expect(baselineResult.loaded).toEqual([]);
			expect(baselineResult.errors).toHaveLength(2);
			expect(baselineResult.errors.map((item: { path: string }) => item.path.split("/").at(-1)).sort()).toEqual(["workflow-router.ts", "workflow-run-binding.ts"]);

			const installedPaths = repositoryExtensions.map((name) => join(extensions, name));
			const result = loadWithNode(activeNodePath, loaderPath, installedPaths);
			expect(result.errors).toEqual([]);
			expect(result.loaded.sort()).toEqual(installedPaths.sort());
			expect(installedPaths).toHaveLength(9);
			expect(packageVersion).toMatch(/^\d+\.\d+\.\d+$/);
			expect(activePiVersion).toBe(packageVersion);
		} finally {
			rmSync(cwd, { recursive: true, force: true });
		}
	});
});
