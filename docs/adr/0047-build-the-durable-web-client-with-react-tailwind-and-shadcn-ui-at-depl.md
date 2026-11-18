---
status: accepted
date: 2026-11-17
tags: [durable, web, build]
affected_components: [durable/web, durable/web-src, durable/scripts/build-web.ts, deploy]
---

# Build the durable web client with React, Tailwind and shadcn/ui at deploy

The durable PWA moves from hand-written DOM code to React, Tailwind and shadcn/ui components, built by Vite from durable/web-src into the two fixed files the daemon already serves (web/app.js and web/style.css), so the daemon, its CSP and its seven served paths stay unchanged. The two outputs are not tracked: the production checkout runs a frozen install and `bun run build` after each pull, every web package stays a devDependency, and `bun run test` builds first so CI exercises the build. Rejected: shadcn tokens over plain CSS without React (no component source to share with the mockups), and a committed bundle (generated diffs in every PR and a bundle that can drift from its sources); the cost accepted is one more deploy command and a short window where a pulled checkout serves 400 until it is built.
