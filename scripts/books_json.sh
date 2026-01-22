#!/bin/sh
set -eu

root=$(CDPATH="" cd -- "$(dirname -- "$0")/.." && pwd)

in="${1:-$root/src/data/books}"
out="${2:-$root/public/books.json}"

if [ ! -f "$in" ]; then
  printf '%s\n' "missing input: $in" >&2
  exit 1
fi

mkdir -p "$(dirname -- "$out")"

tmp=$(mktemp)
trap 'rm -f "$tmp"' INT TERM HUP EXIT

awk -F'[[:space:]]*[|][[:space:]]*' '
  function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
  function esc(s) {
    gsub(/\\/, "\\\\", s)
    gsub(/"/, "\\\"", s)
    gsub(/\r/, "\\r", s)
    gsub(/\n/, "\\n", s)
    gsub(/\t/, "\\t", s)
    return s
  }

  BEGIN { print "["; first=1 }

  {
    shelf=trim($1)
    date=trim($2)
    rating=trim($3)
    pages=trim($4)
    title=trim($5)
    author=trim($6)

    if (!first) print ","
    first=0

    printf "  {\"shelf\":\"%s\",\"date\":\"%s\",\"rating\":%s,\"pages\":%s,\"title\":\"%s\",\"author\":\"%s\"}", esc(shelf), esc(date), rating+0, pages+0, esc(title), esc(author)
  }

  END { print ""; print "]" }
' "$in" >"$tmp"

mv "$tmp" "$out"
printf '%s\n' "wrote $out" >&2
