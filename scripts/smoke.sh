#!/bin/sh
set -eu

root=$(CDPATH="" cd -- "$(dirname -- "$0")/.." && pwd)

index="$root/public/index.html"
books="$root/public/books/index.html"
pax="$root/public/pax/index.html"
data="$root/src/data/books"

fail() {
  printf '%s\n' "smoke: $*" >&2
  exit 1
}

[ -s "$index" ] || fail "missing $index (run: make html)"
[ -s "$books" ] || fail "missing $books (run: make html)"
[ -s "$pax" ] || fail "missing $pax (run: make html)"

# Basic style marker (index should have some inlined CSS).
grep -q "<style>" "$index" || fail "missing <style> in index.html"

# Books page should have expected headings.
grep -Eq "<h2[^>]*>To read[[:space:]]*</h2>" "$books" || fail "books page missing 'To read' heading"
grep -Eq "<h2[^>]*>Read[[:space:]]*</h2>" "$books" || fail "books page missing 'Read' heading"

# Pax page should have expected markers.
grep -Eq "<h1[^>]*>Pax[[:space:]]*</h1>" "$pax" || fail "pax page missing 'Pax' heading"
grep -Eq "<img[^>]*src=/pax/avatar\\.jpg" "$pax" || fail "pax page missing avatar img"

# If we have to-read rows, ensure the 'To read' section contains at least one <li>.
if [ -s "$data" ] && grep -q '^to-read |' "$data"; then
  has_li=$(awk '
    BEGIN{in_section=0; li=0}
    /To read[[:space:]]*<\/h2>/{in_section=1}
    in_section && /<li[ >]/{li=1}
    in_section && /<\/section>/{in_section=0}
    END{print li}
  ' "$books")
  if [ "$has_li" != "1" ]; then
    fail "to-read rows exist but no <li> in To read section"
  fi
fi

# If we have read rows, ensure the 'Read' section contains at least one <li>.
if [ -s "$data" ] && grep -q '^read |' "$data"; then
  has_li=$(awk '
    BEGIN{in_section=0; li=0}
    /Read[[:space:]]*<\/h2>/{in_section=1}
    in_section && /<li[ >]/{li=1}
    in_section && /<\/section>/{in_section=0}
    END{print li}
  ' "$books")
  if [ "$has_li" != "1" ]; then
    fail "read rows exist but no <li> in Read section"
  fi
fi

printf '%s\n' "smoke ok"
