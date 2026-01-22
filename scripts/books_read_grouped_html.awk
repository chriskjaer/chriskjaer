# Input rows: shelf | date | stars | pages | title | author
# Emits HTML lines (intended to be included via smol @data + @for + | ...)

function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

function html_escape(s) {
  gsub(/&/, "&amp;", s)
  gsub(/</, "&lt;", s)
  gsub(/>/, "&gt;", s)
  gsub(/"/, "&quot;", s)
  return s
}

function stars(n,    i, out) {
  out = ""
  for (i = 0; i < n; i++) out = out "★"
  return out
}

BEGIN {
  prev_year = ""
}

{
  shelf = trim($1)
  date = trim($2)
  rating = trim($3) + 0
  title = trim($5)
  author = trim($6)

  if (shelf != "read") next
  year = substr(date, 1, 4)
  if (year == "") next

  title = html_escape(title)
  author = html_escape(author)

  if (year != prev_year) {
    if (prev_year != "") print "</ol>"
    print "<h3 class=year>" year "</h3>"
    print "<ol class=book_list>"
    prev_year = year
  }

  meta = "(" date
  if (rating > 0) meta = meta " · " stars(rating)
  meta = meta ")"

  print "<li><span class=book>" title "</span><span class=author>— " author "</span><span class=meta>" meta "</span></li>"
}

END {
  if (prev_year != "") print "</ol>"
}
