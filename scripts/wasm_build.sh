#!/bin/sh
set -eu

root=$(CDPATH="" cd -- "$(dirname -- "$0")/.." && pwd)
frontend="$root/scripts/wasmol_front.awk"
compiler="$root/scripts/wasmol.awk"
source="$root/src/wasm/life.wasmol"
out="$root/public/life.wasm"
out_dir=$(dirname "$out")

if [ ! -f "$frontend" ]; then
  printf '%s\n' "missing Wasmol frontend $frontend" >&2
  exit 1
fi

if [ ! -f "$compiler" ]; then
  printf '%s\n' "missing Wasmol compiler $compiler" >&2
  exit 1
fi

if [ ! -f "$source" ]; then
  printf '%s\n' "missing WebAssembly source $source" >&2
  exit 1
fi

mkdir -p "$out_dir"
tmp=''
ir=''
tmp=$(mktemp "$out_dir/.life.wasm.XXXXXX")
trap '[ -z "$tmp" ] || rm -f "$tmp"; [ -z "$ir" ] || rm -f "$ir"' INT TERM HUP EXIT
ir=$(mktemp "$out_dir/.life.wasmol.XXXXXX")

LC_ALL=C awk -f "$frontend" "$source" >"$ir"
LC_ALL=C awk -f "$compiler" "$ir" >"$tmp"
chmod 755 "$tmp"

magic=$(od -An -N4 -t x1 "$tmp" | tr -d ' \n')
if [ "$magic" != "0061736d" ]; then
  printf '%s\n' 'generated file is not WebAssembly' >&2
  exit 1
fi

mv "$tmp" "$out"
rm -f "$ir"
trap - INT TERM HUP EXIT
printf '%s\n' "wrote $(basename "$out")"
