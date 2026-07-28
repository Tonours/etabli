---
name: tanstack-start-seo
description: Implement technical SEO in TanStack Start with route head metadata, SSR discipline, social cards, structured data, and sitemap/robots support.
version: 0.1.0
author: Moka
license: Proprietary
---

# TanStack Start SEO

Use this skill when making TanStack Start pages indexable, shareable, and technically legible to search engines and LLM-facing crawlers.

## When to use
Use this skill when:
- public routes need search/social metadata
- sitemap, robots, or structured data need to be deliberate
- rendering mode choices affect discoverability

## When not to use
Do not use this skill as the main guide when:
- the page is private, internal, or purely app-shell UI
- the task is only about route wiring with no SEO surface

## Canonical rule
TanStack Start gives you the primitives for technical SEO, not automatic good SEO.

Use structured data only when the schema is valid and materially useful for the page type; do not add JSON-LD just for decoration.

The main primitives are:
- SSR
- static prerendering
- route `head()`
- server routes for `robots.txt` / `sitemap.xml`
- good performance characteristics

## Safe defaults
For pages that should rank or be shared, keep SSR enabled unless you have a very strong reason not to.

Private/authenticated/internal pages should usually be treated as non-indexable and should not receive the same SEO treatment as public content pages.

## Primary SEO surface: `head()`
Use route `head()` for:
- title
- meta description
- Open Graph tags
- Twitter card tags
- canonical links
- JSON-LD / structured data via `scripts`
- other route-level link/script metadata

### Basic pattern

```tsx
head: () => ({
  meta: [
    { title: 'Page title' },
    { name: 'description', content: 'Page description' },
  ],
})
```

Build canonical URLs from a trusted site-origin configuration rather than ad hoc request-derived strings.

### Dynamic pattern
Use loader data to generate page-specific metadata for detail pages.

## Canonical implementation checklist

### For important content pages
- unique title
- unique description
- canonical URL
- OG title/description/image
- Twitter card metadata
- descriptive URL

### For structured content pages
Add JSON-LD where it materially helps:
- article
- product
- organization
- person
- FAQ
- breadcrumb

## Sitemap strategy
Choose one:
1. built-in TanStack Start sitemap generation for static/mostly-static sites
2. static file in `public/`
3. dynamic sitemap via server route

Official Start docs support built-in sitemap generation through config such as:
- `prerender.crawlLinks: true`
- `sitemap.enabled: true`
- `sitemap.host: 'https://example.com'`

Use dynamic sitemap when:
- content changes often
- pages are not all known at build time

## robots.txt strategy
Choose one:
1. static `public/robots.txt`
2. dynamic server route such as `robots[.]txt.ts`

## Rendering strategy guidance

### Keep SSR on when
- the page matters for indexing
- the page is shared publicly
- metadata needs to be available at first response

### Consider disabling SSR when
- page is purely app-internal
- page is dashboard-only
- SEO does not matter

## Anti-patterns

### Anti-pattern 1
Disabling SSR on public content pages by default.

### Anti-pattern 2
Using the same metadata on every route.

### Anti-pattern 3
Relying only on framework SSR and ignoring titles/descriptions/canonicals.

### Anti-pattern 4
Forgetting social cards for content intended to be shared.

### Anti-pattern 5
Building dynamic content pages without a sitemap strategy.

## Definition of done
SEO work is in good shape when:
- important routes have route-level head metadata
- public pages SSR correctly
- metadata is dynamic where it should be
- sitemap/robots are handled intentionally
- canonical URLs are explicit on pages with duplication risk
