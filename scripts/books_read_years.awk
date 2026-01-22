# Input rows: shelf | date | stars | pages | title | author
# Emits one-field rows: year

function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

{
  shelf = trim($1)
  date = trim($2)
  if (shelf != "read") next
  year = substr(date, 1, 4)
  if (year == "") next
  years[year] = 1
}

END {
  for (y in years) print y
}
