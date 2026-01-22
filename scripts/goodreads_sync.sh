#!/bin/sh
set -eu

root=$(CDPATH="" cd -- "$(dirname -- "$0")/.." && pwd)
user_id="32620052"
out="$root/src/data/books"

mkdir -p "$(dirname -- "$out")"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' INT TERM HUP EXIT

fetch_shelf() {
  shelf="$1"
  date_field="$2"

  page=1
  max_pages=10
  got_any=0

  printf '%s\n' "goodreads: shelf=$shelf" >&2

  while [ "$page" -le "$max_pages" ]; do
    url="https://www.goodreads.com/review/list_rss/${user_id}?shelf=${shelf}&per_page=100&page=${page}"

    xml="$(mktemp)"
    if ! curl -fsSL --max-time 20 \
      --retry 3 --retry-delay 1 --retry-all-errors \
      -A "Mozilla/5.0 (compatible; chriskjaer.com build; +https://chriskjaer.com)" \
      "$url" >"$xml"; then
      rm -f "$xml"
      printf '%s\n' "goodreads: fetch failed shelf=$shelf page=$page url=$url" >&2
      return 1
    fi

    if ! grep -q "<item>" "$xml"; then
      rm -f "$xml"
      break
    fi

    got_any=1

    awk -v SHELF="$shelf" -v DATE_FIELD="$date_field" -f "$root/scripts/goodreads_rss_to_rows.awk" <"$xml" >>"$tmp"

    rm -f "$xml"
    page=$((page + 1))
  done

  if [ "$got_any" -eq 0 ]; then
    printf '%s\n' "goodreads: no items shelf=$shelf (rss empty?)" >&2
    return 1
  fi

  return 0
}

fail=0

if ! fetch_shelf "read" "read_at"; then fail=1; fi
if ! fetch_shelf "to-read" "created"; then fail=1; fi
if ! fetch_shelf "currently-reading" "created"; then fail=1; fi

if [ -s "$tmp" ]; then
  LC_ALL=C sort "$tmp" >"$out.tmp"
  mv "$out.tmp" "$out"
  printf '%s\n' "goodreads: wrote $(basename "$out")" >&2
else
  printf '%s\n' "goodreads: no output; not writing $out" >&2
  fail=1
fi

exit "$fail"
