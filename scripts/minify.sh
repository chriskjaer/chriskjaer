#!/bin/sh
set -eu

root=$(CDPATH="" cd -- "$(dirname -- "$0")/.." && pwd)

files="$root/public/index.html $root/public/books/index.html $root/public/pax/index.html $root/public/projects/smol/index.html"

minify_one() {
  file="$1"

  if [ ! -f "$file" ]; then
    return
  fi

  tmp=$(mktemp)
  tmp_css=$(mktemp)

  awk '
function squeeze(s) {
  gsub(/[ \t\r\n]+/, " ", s)
  gsub(/> </, "><", s)
  sub(/^ /, "", s)
  sub(/ $/, "", s)
  return s
}
BEGIN { in_code = 0 }
{
  line = $0

  # If we are inside a <pre><code>...</code></pre> block, preserve whitespace.
  if (in_code) {
    # Don’t let outer-template indentation leak into code blocks.
    if (match(line, /^[ \t]+<\/code><\/pre>[ \t]*$/)) {
      sub(/^[ \t]+/, "", line)
    }

    print line
    if (index(line, "</code></pre>") > 0) {
      in_code = 0
    }
    next
  }

  # Start of code block may appear mid-line; squeeze before it, preserve after.
  start = index(line, "<pre><code>")
  if (start > 0) {
    pre = substr(line, 1, start - 1)
    post = substr(line, start)

    print squeeze(pre) post

    if (index(post, "</code></pre>") == 0) {
      in_code = 1
    }
    next
  }

  print squeeze(line)
}
' "$file" | sed -E 's/="([^"[:space:]=<>`]+)"/=\1/g' >"$tmp"

  awk '
function mincss(css,   t) {
  gsub(/[ \t\n]+/, " ", css)
  gsub(/ *\\{ */, "{", css)
  gsub(/ *\\} */, "}", css)
  gsub(/ *: */, ":", css)
  gsub(/ *; */, ";", css)
  gsub(/ *, */, ",", css)
  gsub(/;}/, "}", css)
  return css
}
{
  line = $0
  out = ""
  while (match(line, /<style[^>]*>/)) {
    pre = substr(line, 1, RSTART - 1)
    tag = substr(line, RSTART, RLENGTH)
    line = substr(line, RSTART + RLENGTH)
    pos = index(line, "</style>")
    if (pos > 0) {
      css = substr(line, 1, pos - 1)
      out = out pre tag mincss(css) "</style>"
      line = substr(line, pos + 8)
    } else {
      out = out pre tag line
      line = ""
    }
  }
  out = out line
  print out
}
' "$tmp" >"$tmp_css"

  mv "$tmp_css" "$file"
  rm -f "$tmp"

  size=$(wc -c <"$file" | tr -d ' ')
  printf '%s\n' "minified $(basename "$file") ($size bytes)"
}

for file in $files; do
  if [ ! -f "$file" ]; then
    printf '%s\n' "missing $file (run build first)" >&2
    exit 1
  fi
  minify_one "$file"
done
