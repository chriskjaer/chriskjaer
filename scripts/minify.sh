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
{
  line = $0
  out = ""
  while (1) {
    start = index(line, "<pre><code>")
    if (start == 0) {
      out = out squeeze(line)
      break
    }
    pre = substr(line, 1, start - 1)
    out = out squeeze(pre) "<pre><code>"
    line = substr(line, start + length("<pre><code>"))

    end = index(line, "</code></pre>")
    if (end == 0) {
      # no closing marker on this line; emit the rest as-is
      out = out line
      line = ""
      break
    }

    code = substr(line, 1, end - 1)
    out = out code "</code></pre>"
    line = substr(line, end + length("</code></pre>"))
  }
  print out
}
' "$file" | sed -E 's/>[[:space:]]+([^<[:space:]])/>\1/g; s/="([^"[:space:]=<>`]+)"/=\1/g' >"$tmp"

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
