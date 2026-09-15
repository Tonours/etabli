Make slugify(src/slug.js) return a real slug: lowercase, ASCII accents
stripped (e-acute to e), spaces and underscores collapsed to single hyphens,
leading and trailing hyphens removed. Keep test/slug.test.js passing with
`node test/slug.test.js` and extend it for the new behavior. Touch only
src/slug.js and test/slug.test.js.
