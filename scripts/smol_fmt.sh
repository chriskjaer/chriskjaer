#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

if [ "$#" -eq 0 ]; then
  set -- "$root/index.smol" "$root/logo.smol" "$root/styles.smol"
fi

for file in "$@"; do
  if [ ! -f "$file" ]; then
    printf '%s\n' "missing $file" >&2
    exit 1
  fi
  tmp=$(mktemp)
  awk '
    { gsub(/\t/, "  ", $0) }
    { gsub(/[ \t]+$/, "", $0) }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
  printf '%s\n' "formatted $(basename "$file")"
 done
