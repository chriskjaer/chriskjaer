#!/bin/sh
set -eu

root=$(CDPATH="" cd -- "$(dirname -- "$0")/.." && pwd)
compiler="$root/scripts/wasmol.awk"
source="$root/src/wasm/life.wasmol"
out="$root/public/life.wasm"
out_dir=$(dirname "$out")

if [ ! -f "$compiler" ]; then
  printf '%s\n' "missing Wasmol compiler $compiler" >&2
  exit 1
fi

if [ ! -f "$source" ]; then
  printf '%s\n' "missing WebAssembly source $source" >&2
  exit 1
fi

mkdir -p "$out_dir"
tmp=$(mktemp "$out_dir/.life.wasm.XXXXXX")
trap 'rm -f "$tmp"' INT TERM HUP EXIT

LC_ALL=C awk -f "$compiler" "$source" >"$tmp"
chmod 755 "$tmp"

magic=$(od -An -N4 -t x1 "$tmp" | tr -d ' \n')
if [ "$magic" != "0061736d" ]; then
  printf '%s\n' 'generated file is not WebAssembly' >&2
  exit 1
fi

mv "$tmp" "$out"
printf '%s\n' "wrote $(basename "$out")"
