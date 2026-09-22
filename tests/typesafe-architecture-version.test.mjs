import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { composeReview } from "../scripts/lib/typesafe-architecture-review.mjs";
test("architecture accepts the pinned provider response, rejects other versions",()=>{
 const response=JSON.parse(readFileSync(new URL("./fixtures/typesafe-architecture-review/pass.json",import.meta.url)));
 response.model="jev-1.13.0";
 assert.equal(composeReview(response,"fixture",[]).verdict,"pass");
 response.model="jev-1.12.0";assert.throws(()=>composeReview(response,"fixture",[]));
});
