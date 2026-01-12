#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
zig_src="$root/wasm/life.zig"
prebuilt="$root/wasm/life.wasm"

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

if run_zig version >/dev/null 2>&1; then
  wasm_tmp=$(mktemp)
  run_zig build-exe -O ReleaseSmall -target wasm32-freestanding -fno-entry -rdynamic \
    -femit-bin="$wasm_tmp" "$zig_src"
  base64 < "$wasm_tmp" | tr -d '\n'
  rm -f "$wasm_tmp"
  exit 0
fi

if [ -f "$prebuilt" ]; then
  base64 < "$prebuilt" | tr -d '\n'
  exit 0
fi

printf '%s\n' "missing zig (install with: mise install zig@latest && mise use -g zig@latest) and no prebuilt wasm at $prebuilt" >&2
exit 1
