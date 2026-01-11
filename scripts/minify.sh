#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
file="$root/public/index.html"

if [ ! -f "$file" ]; then
  printf '%s\n' "missing $file (run build first)" >&2
  exit 1
fi

tmp=$(mktemp)

tr -s ' \t\r\n' ' ' < "$file" | sed 's/> </></g; s/^ //; s/ $//' > "$tmp"

mv "$tmp" "$file"

size=$(wc -c < "$file" | tr -d ' ')
printf '%s\n' "minified $(basename "$file") ($size bytes)"
