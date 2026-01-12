#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

out="$root/public"

template="$root/index.smol"
compiler="$root/scripts/smol.awk"
target="$out/index.html"
zig_src="$root/wasm/life.zig"

mkdir -p "$out"

awk -f "$compiler" "$template" > "$target"

run_zig() {
  if command -v zig >/dev/null 2>&1; then
    zig "$@"
    return
  fi

  if command -v mise >/dev/null 2>&1; then
    mise exec zig@latest -- zig "$@"
    return
  fi

  return 1
}

if ! run_zig version >/dev/null 2>&1; then
  printf '%s\n' "missing zig (install with: mise install zig@latest && mise use -g zig@latest)" >&2
  exit 1
fi

if [ ! -f "$zig_src" ]; then
  printf '%s\n' "missing wasm source $zig_src" >&2
  exit 1
fi

wasm_tmp=$(mktemp)
run_zig build-exe -O ReleaseSmall -target wasm32-freestanding -fno-entry -rdynamic \
  -femit-bin="$wasm_tmp" "$zig_src"
wasm_b64=$(base64 < "$wasm_tmp" | tr -d '\n')
tmp_html=$(mktemp)
awk -v wasm="$wasm_b64" '{ gsub(/__WASM__/, wasm); print }' "$target" > "$tmp_html"
mv "$tmp_html" "$target"
rm -f "$wasm_tmp"

printf '%s\n' "built $(basename "$target")"
