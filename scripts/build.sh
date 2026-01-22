#!/bin/sh
set -eu

root=$(CDPATH="" cd -- "$(dirname -- "$0")/.." && pwd)

out="$root/public"
compiler="$root/scripts/smol.awk"

build_one() {
  template="$1"
  target="$2"

  mkdir -p "$(dirname -- "$target")"
  awk -f "$compiler" "$template" >"$target"

  printf '%s\n' "built $(basename "$target")"
}

./scripts/goodreads_sync.sh
if [ ! -f "$root/src/data/books" ]; then
  echo "missing src/data/books (goodreads sync failed)" >&2
  exit 1
fi

./scripts/books_json.sh "$root/src/data/books" "$out/books.json"

build_one "$root/src/index.smol" "$out/index.html"
build_one "$root/src/books.smol" "$out/books/index.html"
build_one "$root/src/pax.smol" "$out/pax/index.html"
build_one "$root/src/projects/smol.smol" "$out/projects/smol/index.html"

# Static assets (kept tiny, copied explicitly).
mkdir -p "$out/pax"
cp -f "$root/src/assets/pax-avatar.jpg" "$out/pax/avatar.jpg"
