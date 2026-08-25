#!/usr/bin/env bash
# Portable SHA-256 helper: Linux ships sha256sum, macOS ships shasum.
hash256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$@"
  else
    shasum -a 256 "$@"
  fi
}
