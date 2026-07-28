---
name: tanstack-start-file-uploads
description: Implement file uploads in TanStack Start using server functions or server routes, durable storage, and runtime-aware security patterns.
version: 0.1.0
author: Moka
license: Proprietary
---

# TanStack Start File Uploads

Use this skill when a TanStack Start app needs to accept files such as:
- images
- PDFs
- audio/video clips
- user attachments
- imports/exports

## When to use
Use this skill when:
- the app needs user-facing file upload flows
- you need to choose between server-handled uploads and direct-to-storage flows
- runtime/storage constraints matter

## When not to use
Do not use this skill as the main guide when:
- the task is only about downloading/exporting existing files
- the product does not need binary uploads at all

## Important scope note
There does **not** appear to be a dedicated official TanStack Start file-upload guide.
This skill is grounded in official framework primitives:
- server functions with `FormData`
- server routes with `request.formData()`
- execution-model rules
- environment-variable boundaries
- hosting/runtime constraints

## Goal
Build upload flows that are:
- server-safe
- durable in production
- compatible with the chosen runtime
- explicit about auth and file validation

## Canonical rule
**Route loaders are isomorphic, not server-only.**

Therefore:
- do not handle uploads in loaders
- do not put storage credentials in client-safe code
- use server functions or server routes for upload entrypoints

## Core patterns

### Pattern 1 — small/simple uploads through the app server
Good when:
- file sizes are modest
- your runtime can handle the payloads
- you want a straightforward UX

Flow:
1. browser submits `FormData`
2. server function or server route receives file
3. validate auth, size, type, filename
4. persist to durable storage
5. return normalized asset metadata

### Pattern 2 — direct-to-storage uploads
Good when:
- files are large
- you want to reduce server bandwidth/memory pressure
- host/runtime makes direct proxy uploads awkward

Flow:
1. server function creates signed upload URL/token
2. browser uploads directly to object storage
3. app records asset metadata separately

### Pattern 3 — metadata + blob split
Good default for many product apps:
- binary file goes to object storage
- metadata goes to database
- UI works from normalized asset records

## Official primitive choices

### Use a server function when
- the upload is part of normal app-internal behavior
- a typed RPC-style interface is useful
- you want to validate `FormData` inside Start's server-function model

### Use a server route when
- you want a raw HTTP upload endpoint
- you need custom request/response handling
- you want a clean `/api/uploads` shape

## Server function example
```ts
export const uploadAvatar = createServerFn({ method: 'POST' })
  .inputValidator((input: FormData) => input)
  .handler(async ({ data }) => {
    const file = data.get('file')

    if (!(file instanceof File)) {
      throw new Error('file is required')
    }

    // validate auth, mime type, size, then persist to durable storage
    return {
      url: 'https://cdn.example.com/...',
      filename: file.name,
    }
  })
```

## Server route example
```ts
export const ServerRoute = createServerFileRoute('/api/uploads').methods({
  POST: async ({ request }) => {
    const formData = await request.formData()
    const file = formData.get('file')

    // validate auth, file, storage target

    return Response.json({ ok: true })
  },
})
```

## Storage guidance
Prefer durable object/blob storage for production uploads.

Good defaults:
- S3-compatible storage
- Cloudflare R2
- host/provider blob storage

Avoid relying on local filesystem persistence unless your chosen runtime explicitly guarantees it.

## Security checklist
- authenticate the actor when uploads are private or quota-limited
- authorize org/team/workspace ownership where relevant
- validate MIME type and file size server-side
- normalize or replace filenames instead of trusting raw client names
- never trust client-sent metadata alone
- add scanning/moderation hooks where the product risk requires it

## Runtime guidance

### Node/Nitro-style runtime
Usually the easiest place for traditional upload handling.

### Edge/worker-style runtime
Often better suited to:
- direct-to-storage patterns
- signed upload URLs
- minimizing server-side buffering assumptions

## Safe defaults
- keep the upload boundary server-side
- store blobs durably, not casually on local disk
- return normalized asset metadata to the UI
- separate file storage concerns from product-domain metadata
- design the flow around the real hosting runtime, not local dev assumptions

## Anti-patterns

### Anti-pattern 1
Trying to process uploads in route loaders.

### Anti-pattern 2
Using local filesystem persistence as if it were durable on every host.

### Anti-pattern 3
Trusting client-provided MIME type, filename, or file size.

### Anti-pattern 4
Putting storage secrets in `VITE_*` env vars.

### Anti-pattern 5
Building a file flow without explicit authz for private/org-owned assets.

## Definition of done
File uploads are in good shape when:
- upload entrypoints live in server functions or server routes
- storage is durable for the chosen host/runtime
- credentials stay server-only
- size/type/auth checks happen server-side
- asset metadata returned to the UI is normalized and safe to use
