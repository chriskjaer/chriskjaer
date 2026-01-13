#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

out="$root/public"

template="$root/src/index.smol"
compiler="$root/scripts/smol.awk"
target="$out/index.html"

mkdir -p "$out"

awk -f "$compiler" "$template" > "$target"

printf '%s\n' "built $(basename "$target")"
