const assert = require("node:assert");
const { slugify } = require("../src/slug.js");

assert.strictEqual(slugify("Hello World"), "hello-world");
assert.strictEqual(slugify("  Ete  FRAIS "), "ete-frais");
assert.strictEqual(slugify(""), "");
console.log("slug tests ok");
