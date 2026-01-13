#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

out="$root/public"

template="$root/index.smol"
compiler="$root/scripts/smol.awk"
target="$out/index.html"
wasm_b64_file="$root/wasm/life.wasm.b64"

mkdir -p "$out"

awk -f "$compiler" "$template" > "$target"

if [ ! -f "$wasm_b64_file" ]; then
  printf '%s\n' "missing wasm base64 $wasm_b64_file" >&2
  exit 1
fi

wasm_b64=$(tr -d '\n' < "$wasm_b64_file")
tmp_html=$(mktemp)
awk -v wasm="$wasm_b64" '{ gsub(/__WASM__/, wasm); print }' "$target" > "$tmp_html"
mv "$tmp_html" "$target"

printf '%s\n' "built $(basename "$target")"
