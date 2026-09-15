const assert = require("node:assert");
const { slugify } = require("../src/slug.js");

assert.strictEqual(slugify("Hello World"), "hello-world");
console.log("slug tests ok");
