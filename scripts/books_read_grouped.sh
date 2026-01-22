#!/bin/sh
set -eu

in=${1:?input books file required}
out=${2:?output smol file required}

root=$(CDPATH="" cd -- "$(dirname -- "$0")/.." && pwd)

[ -s "$in" ] || { echo "missing input: $in" >&2; exit 1; }

mkdir -p "$(dirname -- "$out")"

tmp=$(mktemp)
trap 'rm -f "$tmp"' INT TERM HUP EXIT

# Ensure stable order: newest first by date.
# shellcheck disable=SC2016
cat "$in" \
  | awk -F'|' '{s=$1; gsub(/^[ \t]+|[ \t]+$/, "", s); if (s=="read") print $0}' \
  | sort -t'|' -k2,2r \
  | awk -F'|' -f "$root/scripts/books_read_grouped.awk" >"$tmp"

mv "$tmp" "$out"
printf '%s\n' "wrote $out" >&2
