# Input rows: shelf | date | stars | pages | title | author
# Emits HTML for the Books Read section.

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

BEGIN { prev_year = "" }

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
    if (prev_year != "") print "</ul>"
    print "<h3 class=year>" year "</h3>"
    print "<ul class=read_list>"
    prev_year = year
  }

  meta = date
  if (rating > 0) meta = meta " · " stars(rating)

  print "<li><div class=book_item><div class=book_head><span class=\"book book_title\">" title "</span><span class=author>— " author "</span></div><span class=meta>" meta "</span></div></li>"
}

END {
  if (prev_year != "") print "</ul>"
}
