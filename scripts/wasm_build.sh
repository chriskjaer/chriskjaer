#!/bin/sh
set -eu

root=$(CDPATH="" cd -- "$(dirname -- "$0")/.." && pwd)
smol="$root/scripts/smol.awk"
frontend="$root/scripts/wasmol_front.awk"
compiler="$root/scripts/wasmol.awk"
out_dir="$root/public"

for required in "$smol" "$frontend" "$compiler"; do
  if [ ! -f "$required" ]; then
    printf 'missing compiler %s\n' "$required" >&2
    exit 1
  fi
done

mkdir -p "$out_dir"
stage=$(mktemp -d "$out_dir/.wasm-build.XXXXXX")
trap 'rm -rf "$stage"' INT TERM HUP EXIT
sources="$stage/sources"
binaries="$stage/binaries"
mkdir -p "$sources" "$binaries"

found_entry=0
render_entry() {
  entry=$1
  [ -f "$entry" ] || return 0
  found_entry=1
  LC_ALL=C awk -v wasm_source_dir="$sources" -f "$smol" "$entry" >"$stage/rendered.html"
}

if [ "$#" -gt 0 ]; then
  for entry in "$@"; do
    render_entry "$entry"
  done
else
  for entry in \
    "$root/src/index.smol" \
    "$root/src/books.smol" \
    "$root/src/pax.smol" \
    "$root/src/projects/smol.smol"; do
    render_entry "$entry"
  done
fi

if [ "$found_entry" -ne 1 ]; then
  printf '%s\n' 'no Smol entrypoints found' >&2
  exit 1
fi

found_module=0
for source in "$sources"/*.wasmol; do
  [ -f "$source" ] || continue
  found_module=1
  module=$(basename "$source" .wasmol)
  ir="$stage/$module.ir.wasmol"
  binary="$binaries/$module.wasm"
  LC_ALL=C awk -f "$frontend" "$source" >"$ir"
  LC_ALL=C awk -f "$compiler" "$ir" >"$binary"
  chmod 755 "$binary"

  magic=$(od -An -N4 -t x1 "$binary" | tr -d ' \n')
  if [ "$magic" != "0061736d" ]; then
    printf '%s\n' "generated $module is not WebAssembly" >&2
    exit 1
  fi
done

if [ "$found_module" -ne 1 ]; then
  printf '%s\n' 'no @wasm modules found' >&2
  exit 1
fi

for binary in "$binaries"/*.wasm; do
  target="$out_dir/$(basename "$binary")"
  mv "$binary" "$target"
  printf '%s\n' "wrote $(basename "$target")"
done

# Every public WASM artifact is owned by a discovered Smol module. Remove files
# whose declarations disappeared or were renamed, but only after every current
# module compiled and published successfully.
for existing in "$out_dir"/*.wasm; do
  [ -f "$existing" ] || continue
  module=$(basename "$existing" .wasm)
  if [ ! -f "$sources/$module.wasmol" ]; then
    rm -f "$existing"
    printf '%s\n' "removed $(basename "$existing")"
  fi
done

trap - INT TERM HUP EXIT
rm -rf "$stage"
