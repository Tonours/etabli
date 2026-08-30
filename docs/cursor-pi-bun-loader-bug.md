# Draft: pi 0.84.4 under mise-managed Bun cannot resolve `@cursor/sdk` in extensions

Status: draft, not posted. Posting needs an explicit external-write command.

## Summary

When pi is installed through mise (which shims it onto the Bun runtime), any
extension that imports `@cursor/sdk` fails to resolve the package at load
time. The same extension file loads fine when pi runs from the npx-published
package of the same version.

## Environment

- pi 0.84.4 (`@earendil-works/pi-coding-agent`)
- install path A (broken): mise shim -> Bun-managed `pi` binary
- install path B (working): `npx -y @earendil-works/pi-coding-agent@0.84.4`
- extension under test: one that does `import ... from "@cursor/sdk"`
  (Cursor-model provider bridge)

## Repro

1. Install pi 0.84.4 through mise (Bun runtime shim).
2. Run `pi -e <path-to-extension-importing-cursor-sdk> -p "ok"`.
3. Observe the module-resolution failure for `@cursor/sdk`.

Then:

1. Run `npx -y @earendil-works/pi-coding-agent@0.84.4 -e <same file> -p "ok"`.
2. The extension loads and the provider works.

## Workaround

Use the npx-published package for sessions that load Cursor-bridged
extensions (validated repeatedly on this setup), or install the sdk where
the Bun shim can see it. The failure is path/runtime dependent, not
extension dependent.

## Suspected area

Module resolution for extension imports differs between the Bun-shimmed
install and the npx package layout (`node_modules` discovery root). Worth a
minimal reproducer on the pi side before filing upstream.
