#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
file="$root/public/index.html"

if [ ! -f "$file" ]; then
  printf '%s\n' "missing $file (run build first)" >&2
  exit 1
fi

tmp=$(mktemp)
tmp_css=$(mktemp)

tr -s ' \t\r\n' ' ' < "$file" | sed -E 's/> </></g; s/^ //; s/ $//; s/>[[:space:]]+([^<[:space:]])/>\1/g; s/="([^"[:space:]=<>`]+)"/=\1/g' > "$tmp"

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
' "$tmp" > "$tmp_css"

mv "$tmp_css" "$file"
rm -f "$tmp"

size=$(wc -c < "$file" | tr -d ' ')
printf '%s\n' "minified $(basename "$file") ($size bytes)"
