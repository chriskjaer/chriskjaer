#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
zig_src="$root/src/wasm/life.zig"
out_wasm="$root/public/life.wasm"

run_zig() {
  if command -v zig >/dev/null 2>&1; then
    zig "$@"
    return
  fi

  if command -v mise >/dev/null 2>&1; then
    if mise which zig >/dev/null 2>&1; then
      mise exec zig@latest -- zig "$@"
      return
    fi
  fi

  return 1
}

if [ ! -f "$zig_src" ]; then
  printf '%s\n' "missing wasm source $zig_src" >&2
  exit 1
fi

if ! run_zig version >/dev/null 2>&1; then
  if [ -f "$out_wasm" ]; then
    printf '%s\n' "using prebuilt $(basename "$out_wasm")"
    exit 0
  fi
  printf '%s\n' "missing zig (install with: mise install zig@latest && mise use -g zig@latest)" >&2
  exit 1
fi

mkdir -p "$(dirname "$out_wasm")"
run_zig build-exe -O ReleaseSmall -target wasm32-freestanding -fno-entry -rdynamic \
  -femit-bin="$out_wasm" "$zig_src"

printf '%s\n' "wrote $(basename "$out_wasm")"
