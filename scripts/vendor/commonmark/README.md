# CommonMark parser bundle

- Package: `commonmark@0.31.2`
- Upstream: <https://github.com/commonmark/commonmark.js>
- Source archive: <https://registry.npmjs.org/commonmark/-/commonmark-0.31.2.tgz>
- Vendored file: upstream `dist/commonmark.min.js`, renamed to
  `commonmark.cjs` so this ES module repository loads the browser bundle as
  CommonJS.
- SHA-256: `2de0f8ecbca0a6470da57c8b2ad043777ae999c5132f9abf12e8c332d4e46164`
- License: BSD-2-Clause for the parser, with the upstream third-party notices
  retained in `LICENSE`.

The workflow guard vendors this deterministic parser because deployed project
scaffolds cannot assume an npm install. Update the pinned version, digest,
license, regression fixture, and frozen review together.
