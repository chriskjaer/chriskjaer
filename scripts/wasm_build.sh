#!/bin/sh
set -eu

root=$(CDPATH="" cd -- "$(dirname -- "$0")/.." && pwd)
source="$root/scripts/life_wasm.awk"
out="$root/public/life.wasm"
out_dir=$(dirname "$out")

if [ ! -f "$source" ]; then
  printf '%s\n' "missing WebAssembly source $source" >&2
  exit 1
fi

mkdir -p "$out_dir"
tmp=$(mktemp "$out_dir/.life.wasm.XXXXXX")
trap 'rm -f "$tmp"' INT TERM HUP EXIT

LC_ALL=C awk -f "$source" >"$tmp"
chmod 755 "$tmp"

magic=$(od -An -N4 -t x1 "$tmp" | tr -d ' \n')
if [ "$magic" != "0061736d" ]; then
  printf '%s\n' 'generated file is not WebAssembly' >&2
  exit 1
fi

mv "$tmp" "$out"
printf '%s\n' "wrote $(basename "$out")"
