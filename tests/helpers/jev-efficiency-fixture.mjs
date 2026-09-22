import { readFileSync } from "node:fs";
import { fingerprintEvaluatorBundle, fingerprintEvaluatorFile, hashManifestBytes } from "../../scripts/lib/evaluator-bundle.mjs";

// Synthetic current-evaluator fixture only; never overwrite the historical manifest.
export function currentEvaluatorFixtureBytes() {
 const fixture=JSON.parse(readFileSync("workflow/self-improvement/jev-efficiency-manifest.json","utf8"));
 fixture.manifest_id="jev-efficiency-fixture-current";
 fixture.evaluator.sha256=fingerprintEvaluatorFile(".",fixture.evaluator.path);
 fixture.evaluator.bundle.sha256=fingerprintEvaluatorBundle(".",fixture.evaluator.bundle.paths);
 return Buffer.from(JSON.stringify(fixture));
}

export function currentPopulationFixtureBytes(manifestBytes) {
 const fixture=JSON.parse(readFileSync("tests/fixtures/jev-efficiency/population.json","utf8"));
 const manifest=JSON.parse(manifestBytes);
 fixture.manifest_id=manifest.manifest_id;
 fixture.manifest_sha256=hashManifestBytes(manifestBytes);
 return Buffer.from(JSON.stringify(fixture));
}
