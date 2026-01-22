#!/bin/sh
set -eu

# Fetch Goodreads RSS for a shelf (paginated) and write concatenated XML.

user_id="${USER_ID:-32620052}"
shelf="${1:-}"
out="${2:-}"

if [ -z "$shelf" ] || [ -z "$out" ]; then
  echo "usage: fetch_books_rss.sh <shelf> <out>" >&2
  exit 2
fi

page=1
max_pages=${MAX_PAGES:-10}

mkdir -p "$(dirname "$out")"
: >"$out"

while [ "$page" -le "$max_pages" ]; do
  url="https://www.goodreads.com/review/list_rss/${user_id}?shelf=${shelf}&per_page=100&page=${page}"

  tmp="$(mktemp)"
  if ! curl -fsSL --max-time 20 --retry 3 --retry-delay 1 --retry-all-errors \
    -A "Mozilla/5.0 (compatible; chriskjaer.com build; +https://chriskjaer.com)" \
    "$url" >"$tmp"; then
    rm -f "$tmp"
    return 1
  fi

  if ! grep -q "<item>" "$tmp"; then
    rm -f "$tmp"
    break
  fi

  cat "$tmp" >>"$out"
  rm -f "$tmp"

  page=$((page + 1))
done
