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

read_tsv_tmp="$(mktemp)"
trap 'rm -f "$read_tsv_tmp"' INT TERM HUP EXIT

for shelf in currently-reading read to-read; do
  if ! fetch_one_shelf "$shelf"; then
    fail=1
  fi

done

# If we have a read shelf, generate derived build-time files.
read_json="$cache_dir/${user_id}_read.json"
if [ -f "$read_json" ]; then
  # Re-fetch read shelf RSS once for reliable pages/date parsing.
  rss_tmp="$(mktemp)"
  if curl -fsSL --max-time 10 "https://www.goodreads.com/review/list_rss/${user_id}?shelf=read&per_page=100&page=1" >"$rss_tmp"; then
    awk -f "$root/scripts/goodreads_read_to_tsv.awk" <"$rss_tmp" >"$read_tsv_tmp" || true

    # books_stats.smol (build-time)
    awk -F '\t' '
      BEGIN {
        print "-# Generated file. Do not edit.";
        print "-# Source: Goodreads read shelf RSS.";
        print "";
        print "ul.chart";
      }
      {
        year = substr($1, 1, 4) + 0;
        books[year] += 1;
        pages[year] += ($2 + 0);
        if (books[year] > max) max = books[year];
      }
      END {
        if (max == 0) {
          print "  li";
          print "    | (no data)";
          exit;
        }
        # Print newest year first.
        for (y in books) years[n++] = y;
        # simple bubble sort for small N
        for (i = 0; i < n; i++) for (j = i + 1; j < n; j++) if (years[j] > years[i]) { t=years[i]; years[i]=years[j]; years[j]=t }
        for (i = 0; i < n; i++) {
          y = years[i];
          pct = int((books[y] / max) * 100 + 0.5);
          printf "  li.bar\n";
          printf "    span.year\n";
          printf "      | %d\n", y;
          printf "    span.track\n";
          printf "      span.fill(style=\"width: %d%%\")\n", pct;
          printf "    span.count\n";
          if (pages[y] > 0) {
            printf "      | %d books · %d pages\n", books[y], pages[y];
          } else {
            printf "      | %d books\n", books[y];
          }
        }
      }
    ' "$read_tsv_tmp" >"$root/src/data/books_stats.smol" || true

    # books_read_grouped.smol (year headers + items, newest first)
    sort -r "$read_tsv_tmp" | awk -F '\t' '
      function stars(n,  i, s) { s=""; for (i=0;i<n;i++) s=s"★"; return s }
      BEGIN {
        print "-# Generated file. Do not edit.";
        print "-# Source: Goodreads read shelf RSS.";
        print "";
        last_year = "";
      }
      {
        date = $1;
        pages = $2 + 0;
        rating = $3 + 0;
        title = $4;
        author = $5;
        year = substr(date, 1, 4);

        if (year != last_year) {
          if (last_year != "") printf "\n";
          printf "h3.year\n";
          printf "  | %s\n", year;
          printf "ol.book_list\n";
          last_year = year;
        }

        printf "  li\n";
        printf "    span.book\n";
        printf "      | %s\n", title;
        printf "    | \n\n";
        printf "    span.author\n";
        printf "      | — %s\n", author;
        printf "    | \n\n";
        printf "    span.meta\n";
        if (rating > 0) {
          printf "      | (%s · %s)\n", date, stars(rating);
        } else {
          printf "      | (%s)\n", date;
        }
      }
    ' >"$root/src/data/books_read_grouped.smol" || true
  fi
  rm -f "$rss_tmp"
fi

exit "$fail"
