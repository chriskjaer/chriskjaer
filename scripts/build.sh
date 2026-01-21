#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

out="$root/public"
compiler="$root/scripts/smol.awk"

build_one() {
  template="$1"
  target="$2"

  mkdir -p "$(dirname -- "$target")"
  awk -f "$compiler" "$template" > "$target"

  printf '%s\n' "built $(basename "$target")"
}

build_one "$root/src/index.smol" "$out/index.html"
build_one "$root/src/books.smol" "$out/books/index.html"
