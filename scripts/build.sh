#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

out="$root/public"

template="$root/index.smol"
compiler="$root/scripts/smol.awk"
target="$out/index.html"
wat="$root/wasm/life.wat"

mkdir -p "$out"

awk -f "$compiler" "$template" > "$target"

if command -v wat2wasm >/dev/null 2>&1; then
  wasm_tmp=$(mktemp)
  wat2wasm "$wat" -o "$wasm_tmp"
  wasm_b64=$(base64 < "$wasm_tmp" | tr -d '\n')
  tmp_html=$(mktemp)
  awk -v wasm="$wasm_b64" '{ gsub(/__WASM__/, wasm); print }' "$target" > "$tmp_html"
  mv "$tmp_html" "$target"
  rm -f "$wasm_tmp"
else
  printf '%s\n' "missing wat2wasm (install wabt) for wasm build" >&2
  exit 1
fi

size=$(wc -c < "$target" | tr -d ' ')
printf '%s\n' "built $(basename "$target") ($size bytes, unminified)"
