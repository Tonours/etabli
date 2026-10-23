#!/usr/bin/env bash
# Portable SHA-256 helpers: Linux ships sha256sum, macOS ships shasum.
# hash256 is a function for normal use; HASH256_BIN is a command array for
# exec boundaries (xargs and friends cannot invoke shell functions).
if command -v sha256sum >/dev/null 2>&1; then
  HASH256_BIN=(sha256sum)
else
  HASH256_BIN=(shasum -a 256)
fi

hash256() {
  "${HASH256_BIN[@]}" "$@"
}
