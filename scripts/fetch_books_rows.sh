#!/bin/sh
set -eu

# Fetch and structurally parse one paginated Goodreads shelf into normalized rows.

user_id="${USER_ID:-32620052}"
shelf="${1:-}"
out="${2:-}"
root=$(CDPATH="" cd -- "$(dirname -- "$0")/.." && pwd)

if [ -z "$shelf" ] || [ -z "$out" ]; then
  echo "usage: fetch_books_rows.sh <shelf> <out>" >&2
  exit 2
fi

date_field=created
if [ "$shelf" = "read" ]; then date_field=read_at; fi

page=1
max_pages=${MAX_PAGES:-10}
saw_items=0
got_any=0
complete=0

out_dir=$(dirname "$out")
mkdir -p "$out_dir"
combined="$(mktemp "$out_dir/.books-rows.XXXXXX")"
trap 'rm -f "$combined"' INT TERM HUP EXIT

while [ "$page" -le "$max_pages" ]; do
  url="https://www.goodreads.com/review/list_rss/${user_id}?shelf=${shelf}&per_page=100&page=${page}"

  xml="$(mktemp)"
  if ! curl -fsSL --max-time 20 --max-filesize 5242880 \
    --retry 3 --retry-delay 1 --retry-all-errors \
    -A "Mozilla/5.0 (compatible; chriskjaer.com build; +https://chriskjaer.com)" \
    "$url" >"$xml"; then
    rm -f "$xml"
    exit 1
  fi

  rows="$(mktemp)"
  if awk -v SHELF="$shelf" -v DATE_FIELD="$date_field" \
    -f "$root/scripts/goodreads_rss_to_rows.awk" "$xml" >"$rows"; then
    status=0
  else
    status=$?
  fi
  rm -f "$xml"

  case "$status" in
    0)
      saw_items=1
      got_any=1
      cat "$rows" >>"$combined"
      ;;
    2)
      rm -f "$rows"
      complete=1
      break
      ;;
    3)
      saw_items=1
      ;;
    *)
      rm -f "$rows"
      printf '%s\n' "invalid Goodreads RSS/items: shelf=$shelf page=$page" >&2
      exit 1
      ;;
  esac
  rm -f "$rows"
  page=$((page + 1))
done

if [ "$complete" -ne 1 ]; then
  printf '%s\n' "Goodreads pagination limit reached: shelf=$shelf max_pages=$max_pages" >&2
  exit 1
fi

if [ "$saw_items" -eq 1 ] && [ "$got_any" -eq 0 ]; then
  printf '%s\n' "no usable Goodreads items: shelf=$shelf" >&2
  exit 1
fi

mv "$combined" "$out"
