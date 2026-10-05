import { readFileSync, realpathSync, statSync } from "node:fs";
import { isAbsolute, join } from "node:path";
import { buildReport, renderPatterns, renderReport } from "./ship-metrics-report.mjs";
import { mergePatternRows } from "./workflow-patterns.mjs";

export function buildPortfolio({ projectsFile, since, until, herdrHistory }) {
	if (herdrHistory) throw new Error("--herdr-history is single-project only; use --dir for that report.");
	let roots;
	try { roots = JSON.parse(readFileSync(projectsFile, "utf8")); }
	catch { throw new Error("Cannot read project inventory; provide --projects with a JSON array of absolute repository roots."); }
	if (!Array.isArray(roots) || !roots.length) throw new Error("Project inventory must be a nonempty JSON array of absolute repository roots.");
	const canonical = new Set();
	for (const root of roots) {
		if (typeof root !== "string" || !isAbsolute(root)) throw new Error("Every project inventory entry must be an absolute repository-root directory.");
		let path;
		try {
			path = realpathSync(root);
			if (!statSync(path).isDirectory()) throw new Error();
		} catch { throw new Error(`Project root is not an existing directory: ${root}; correct the inventory.`); }
		if (canonical.has(path)) throw new Error(`Duplicate canonical project root: ${path}; remove its duplicate or symlink alias.`);
		canonical.add(path);
	}
	const windowEnd = until || new Date().toISOString();
	const projects = [...canonical].map((root) => buildReport({ dir: join(root, ".workflow"), since, until: windowEnd }));
	return {
		window: projects[0].window,
		projects,
		patterns: mergePatternRows(projects.flatMap((report) => report.patterns.rows)),
		note: "Coverage and missing sources are reported per project; identical slugs across projects remain distinct initiatives.",
	};
}

export function renderPortfolio(report) {
	return ["Workflow statistics across explicit projects", `Projects: ${report.projects.length}`, report.note,
		"", "Combined recurring patterns:", ...renderPatterns(report.patterns),
		...report.projects.flatMap((project) => ["", renderReport(project)]),
	].join("\n");
}
