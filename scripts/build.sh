#!/bin/sh
set -eu

root=$(CDPATH="" cd -- "$(dirname -- "$0")/.." && pwd)

out="$root/public"
compiler="$root/scripts/smol.awk"
mkdir -p "$out"
wasm_sources=$(mktemp -d "$out/.smol-wasm-sources.XXXXXX")
trap 'rm -rf "$wasm_sources"' INT TERM HUP EXIT

build_one() {
  template="$1"
  target="$2"

  mkdir -p "$(dirname -- "$target")"
  awk -v wasm_source_dir="$wasm_sources" -f "$compiler" "$template" >"$target"

  printf '%s\n' "built $(basename "$target")"
}

if [ ! -f "$root/src/data/books" ]; then
  echo "missing src/data/books (run: make data)" >&2
  exit 1
fi

./scripts/wasm_build.sh
./scripts/books_json.sh "$root/src/data/books" "$out/books.json"

build_one "$root/src/index.smol" "$out/index.html"
build_one "$root/src/books.smol" "$out/books/index.html"
build_one "$root/src/pax.smol" "$out/pax/index.html"
build_one "$root/src/projects/smol.smol" "$out/projects/smol/index.html"
build_one "$root/src/projects/snake.smol" "$out/projects/snake/index.html"

# Static assets (kept tiny, copied explicitly).
mkdir -p "$out/pax"
cp -f "$root/src/assets/pax-avatar.jpg" "$out/pax/avatar.jpg"

trap - INT TERM HUP EXIT
rm -rf "$wasm_sources"
