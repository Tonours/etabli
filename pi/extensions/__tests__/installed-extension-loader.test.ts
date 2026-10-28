import { describe, expect, test } from "bun:test";
import { execFileSync, spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, mkdirSync, readFileSync, realpathSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";

const root = resolve(import.meta.dir, "../../..");
const piLookup = spawnSync("which", ["pi"], { encoding: "utf8" });
const piLauncher = piLookup.status === 0 ? piLookup.stdout.trim() : "";
const pinnedPackageRoot = join(root, "pi/node_modules/@earendil-works/pi-coding-agent");
const repositoryExtensions = [
	"no-comments.ts",
	"prefer-ipv4-dns.ts",
	"rtk.ts",
	"workflow-tools.ts",
];

function resolveActiveTargets() {
	const launcherTrace = spawnSync("bash", ["-x", piLauncher, "--version"], { encoding: "utf8" });
	const activeExec = launcherTrace.stderr.match(/\+ exec (\S+) (\S+\/dist\/(?:bundle\/)?cli\.js) --version/);
	if (launcherTrace.status === 0 && activeExec) {
		return { activeNode: activeExec[1], activeCli: activeExec[2], version: launcherTrace.stdout.trim() };
	}
	if (launcherTrace.status === 0 && /^\+ exec asdf exec pi --version$/m.test(launcherTrace.stderr)) {
		const asdfPi = spawnSync("asdf", ["which", "pi"], { encoding: "utf8" });
		const asdfNode = spawnSync("asdf", ["which", "node"], { encoding: "utf8" });
		if (asdfPi.status !== 0 || asdfNode.status !== 0) throw new Error("unable to resolve active Pi runtime");
		return { activeNode: asdfNode.stdout.trim(), activeCli: realpathSync(asdfPi.stdout.trim()), version: launcherTrace.stdout.trim() };
	}
	const managedReleaseExec = launcherTrace.stderr.match(/^\+ exec (\S+) --version$/m);
	const linkedCli = realpathSync(launcherTrace.status === 0 && managedReleaseExec ? managedReleaseExec[1] : piLauncher);
	if (!/\/dist\/(?:bundle\/)?cli\.js$/.test(linkedCli)) throw new Error("unable to resolve active Pi runtime");
	const nodeLookup = spawnSync("which", ["node"], { encoding: "utf8" });
	if (nodeLookup.status !== 0) throw new Error("unable to resolve active Pi runtime");
	const versionRun = spawnSync(piLauncher, ["--version"], { encoding: "utf8" });
	if (versionRun.status !== 0) throw new Error("unable to resolve active Pi runtime");
	return { activeNode: nodeLookup.stdout.trim(), activeCli: linkedCli, version: versionRun.stdout.trim() };
}

function runtimeAt(activeNode: string, packageRoot: string) {
	return {
		activeNodePath: realpathSync(activeNode),
		loaderPath: join(packageRoot, "dist/core/extensions/loader.js"),
		packageVersion: JSON.parse(readFileSync(join(packageRoot, "package.json"), "utf8")).version as string,
	};
}

function resolveInstalledRuntime() {
	const { activeNode, activeCli, version } = resolveActiveTargets();
	let packageRoot = dirname(realpathSync(activeCli));
	while (!existsSync(join(packageRoot, "package.json")) && dirname(packageRoot) !== packageRoot) packageRoot = dirname(packageRoot);
	return { ...runtimeAt(activeNode, packageRoot), activePiVersion: version };
}

function resolvePinnedRuntime() {
	const nodeLookup = spawnSync("which", ["node"], { encoding: "utf8" });
	if (nodeLookup.status !== 0) throw new Error("unable to resolve node for the pinned Pi runtime");
	return runtimeAt(nodeLookup.stdout.trim(), pinnedPackageRoot);
}

function loadWithNode(activeNodePath: string, loaderPath: string, paths: string[]) {
	const source = `import { loadExtensions } from ${JSON.stringify(loaderPath)}; const result = await loadExtensions(${JSON.stringify(paths)}, ${JSON.stringify(root)}); console.log(JSON.stringify({ loaded: result.extensions.map((item) => item.path), errors: result.errors }));`;
	return JSON.parse(execFileSync(activeNodePath, ["--input-type=module", "-e", source], { encoding: "utf8" }));
}

describe("installed Pi extension loader", () => {
	test("reproduces the logical-path failure and loads every extension with the managed layout", () => {
		const { activeNodePath, loaderPath, packageVersion } = piLauncher ? resolveInstalledRuntime() : resolvePinnedRuntime();
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
			writeFileSync(join(baseline, "broken.ts"), 'import "../../scripts/lib/missing-module.mjs"; export default function () {}\n');
			const baselineResult = loadWithNode(activeNodePath, loaderPath, [join(baseline, "broken.ts")]);
			expect(baselineResult.loaded).toEqual([]);
			expect(baselineResult.errors).toHaveLength(1);
			expect(baselineResult.errors.map((item: { path: string }) => item.path.split("/").at(-1))).toEqual(["broken.ts"]);

			const installedPaths = repositoryExtensions.map((name) => join(extensions, name));
			const result = loadWithNode(activeNodePath, loaderPath, installedPaths);
			expect(result.errors).toEqual([]);
			expect(result.loaded.sort()).toEqual(installedPaths.sort());
			expect(installedPaths).toHaveLength(repositoryExtensions.length);
			expect(packageVersion).toMatch(/^\d+\.\d+\.\d+$/);
		} finally {
			rmSync(cwd, { recursive: true, force: true });
		}
	}, 60000);

	test.skipIf(!piLauncher)("the pi launcher runs the version of the runtime it resolves to", () => {
		const { activePiVersion, packageVersion } = resolveInstalledRuntime();
		expect(activePiVersion).toBe(packageVersion);
	}, 60000);
});
