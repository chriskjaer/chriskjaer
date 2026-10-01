# Input rows: shelf | date | stars | pages | title | author
# Expects: YEAR (e.g. -v YEAR=2025)
# Emits: date | stars | title | author | pages

function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

function stars(n,    i, out) {
  out = ""
  for (i = 0; i < n; i++) out = out "★"
  return out
}

{
  shelf = trim($1)
  date = trim($2)
  rating = trim($3) + 0
  pages = trim($4) + 0
  title = trim($5)
  author = trim($6)

  if (shelf != "read") next
  if (substr(date, 1, 4) != YEAR) next

  if (pages <= 0) pages = ""
  print date " | " stars(rating) " | " title " | " author " | " pages
}
