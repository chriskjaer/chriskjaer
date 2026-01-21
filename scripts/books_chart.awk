#!/usr/bin/awk -f

# Input: shelf | date | rating | pages | title | author
# Output: year | books | pages | pct |  |  (6 fields)

function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

BEGIN {
  FS = "|"
}

{
  shelf = trim($1)
  if (shelf != "read") next

  date = trim($2)
  pages = trim($4) + 0
  if (date == "") next

  year = substr(date, 1, 4)
  years[year] = 1
  books[year] += 1
  if (pages > 0) pages_sum[year] += pages
  if (books[year] > max_books) max_books = books[year]
}

END {
  n = 0
  for (y in years) ys[++n] = y
  for (i=1;i<=n;i++) for (j=i+1;j<=n;j++) if (ys[j] > ys[i]) { t=ys[i]; ys[i]=ys[j]; ys[j]=t }

  for (i=1;i<=n;i++) {
    y = ys[i]
    b = books[y] + 0
    p = pages_sum[y] + 0
    pct = (max_books > 0) ? int((b / max_books) * 100 + 0.5) : 0
    printf "%s | %d | %d | %d |  | \n", y, b, p, pct
  }
}
