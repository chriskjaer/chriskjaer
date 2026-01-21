#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cache_dir="$root/src/data/goodreads_cache"
user_id="32620052"

mkdir -p "$cache_dir"

fetch_one_shelf() {
  shelf="$1"
  out="$cache_dir/${user_id}_${shelf}.json"

  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' INT TERM HUP EXIT

  page=1
  max_pages=10
  got_any=0

  printf '%s\n' "goodreads: shelf=$shelf" >&2

  while [ "$page" -le "$max_pages" ]; do
    url="https://www.goodreads.com/review/list_rss/${user_id}?shelf=${shelf}&per_page=100&page=${page}"

    xml="$(mktemp)"
    if ! curl -fsSL --max-time 10 "$url" >"$xml"; then
      rm -f "$xml"
      printf '%s\n' "goodreads: fetch failed shelf=$shelf page=$page (keeping cache)" >&2
      return 1
    fi

    if ! grep -q "<item>" "$xml"; then
      rm -f "$xml"
      break
    fi

    got_any=1

    # Convert this page to JSON array; then append objects to tmp as NDJSON-ish.
    # We avoid jq by stripping [ ] and splitting on object boundaries.
    awk -f "$root/scripts/goodreads_rss_to_json.awk" <"$xml" \
      | sed -e '1s/^\[//' -e '$s/\]$//' \
      | sed -e 's/^[[:space:]]*//; s/[[:space:]]*$//' \
      | sed -e 's/,$//' \
      | sed -e '/^$/d' \
      >>"$tmp"

    rm -f "$xml"
    page=$((page + 1))
  done

  if [ "$got_any" -eq 0 ]; then
    printf '%s\n' "goodreads: no items shelf=$shelf (keeping cache)" >&2
    return 1
  fi

  # tmp now has JSON objects separated by commas/newlines.
  # Normalize into a proper JSON array.
  {
    printf '['
    awk 'BEGIN{first=1}
      {gsub(/^[[:space:]]+|[[:space:]]+$/, ""); if($0=="") next;
       if(first){first=0}else{printf ","}
       printf "\n%s", $0
      }
      END{if(!first) printf "\n"}
    ' <"$tmp"
    printf ']\n'
  } >"$out.tmp"

  mv "$out.tmp" "$out"
  printf '%s\n' "goodreads: updated $(basename "$out")" >&2
}

fail=0
for shelf in currently-reading read to-read; do
  if ! fetch_one_shelf "$shelf"; then
    fail=1
  fi
done

exit "$fail"
