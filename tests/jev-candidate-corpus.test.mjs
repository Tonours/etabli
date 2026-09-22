import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { validateCandidateCorpus, diagnosisObservation } from "../scripts/lib/jev-candidate-corpus.mjs";
import { prepareSelfImprovementDiagnosisRequest } from "../pi/extensions/lib/semantic-profiles.mjs";
const load=name=>JSON.parse(readFileSync(new URL(`./fixtures/jev-candidates/${name}.json`,import.meta.url)));
test("candidate corpora are versioned, separate and not live evidence",()=>{
 const claims=load("claim-evidence-v2"),diagnosis=load("diagnosis-v1");
 assert.equal(validateCandidateCorpus(claims).cases,50);assert.equal(validateCandidateCorpus(diagnosis).cases,11);
 for(const language of ["en","fr"])for(const relation of ["supported","contradicted"])assert.ok(claims.cases.some(c=>c.language===language&&c.expected_relation===relation));
 const corrupt=structuredClone(claims);corrupt.cases.find(c=>c.split==="held_out").family=claims.cases[0].family;assert.throws(()=>validateCandidateCorpus(corrupt),/split/);
 const [left,right]=diagnosis.cases.filter(c=>c.hidden_cause);
 assert.deepEqual(prepareSelfImprovementDiagnosisRequest(diagnosisObservation(left)),prepareSelfImprovementDiagnosisRequest(diagnosisObservation(right)));
 assert.equal(left.expected_action,"investigate");assert.equal(right.expected_action,"investigate");
});
