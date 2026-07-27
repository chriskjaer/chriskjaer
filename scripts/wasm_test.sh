#!/bin/sh
set -eu

root=$(CDPATH="" cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp)
trap 'rm -f "$tmp"' INT TERM HUP EXIT

LC_ALL=C awk -f "$root/scripts/life_wasm.awk" >"$tmp"

if ! cmp -s "$tmp" "$root/public/life.wasm"; then
  printf '%s\n' 'wasm test: AWK output differs from committed life.wasm' >&2
  exit 1
fi

printf '%s\n' 'wasm test ok'
