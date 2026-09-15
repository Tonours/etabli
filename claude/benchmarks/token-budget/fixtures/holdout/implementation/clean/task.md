Make slugify(src/slug.js) return a real slug: lowercase, ASCII accents
stripped, spaces and underscores collapsed to single hyphens, leading and
trailing hyphens removed, empty input yields empty output. If the current
implementation and tests already satisfy every requirement, change nothing
and say why. Run `node test/slug.test.js` to check.
