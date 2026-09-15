Make slugify(src/slug.js) return a real slug: lowercase, ASCII accents
stripped, spaces and underscores collapsed to single hyphens, leading and
trailing hyphens removed. Edge cases are the point of this task:
slugify("") === "" and slugify("  ") === "" must hold (never "-", never
"undefined"). Keep `node test/slug.test.js` green and extend the tests.
Touch only src/slug.js and test/slug.test.js.
