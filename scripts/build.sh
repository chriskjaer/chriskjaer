#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

out="$root/public"

template="$root/index.smol"
compiler="$root/scripts/smol.awk"
target="$out/index.html"
wasm_builder="$root/scripts/wasm.sh"

mkdir -p "$out"

awk -f "$compiler" "$template" > "$target"

if [ ! -x "$wasm_builder" ]; then
  printf '%s\n' "missing wasm builder $wasm_builder" >&2
  exit 1
fi

wasm_b64=$("$wasm_builder")
tmp_html=$(mktemp)
awk -v wasm="$wasm_b64" '{ gsub(/__WASM__/, wasm); print }' "$target" > "$tmp_html"
mv "$tmp_html" "$target"

printf '%s\n' "built $(basename "$target")"
