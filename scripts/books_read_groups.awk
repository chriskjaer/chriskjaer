#!/usr/bin/awk -f

# Input: shelf | date | rating | pages | title | author
# Output: year-group rows as 6 fields (HTML in title field)

function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

function html_escape(s) {
  gsub(/&/, "&amp;", s)
  gsub(/</, "&lt;", s)
  gsub(/>/, "&gt;", s)
  gsub(/"/, "&quot;", s)
  return s
}

function stars(n,  i, s) { s=""; for (i=0;i<n;i++) s=s"★"; return s }

BEGIN {
  FS = "|"
}

{
  shelf = trim($1)
  if (shelf != "read") next

  date = trim($2)
  rating = trim($3) + 0
  pages = trim($4) + 0
  title = trim($5)
  author = trim($6)

  if (date == "") next

  year = substr(date, 1, 4)

  key = year
  items[key] = items[key] sprintf("<li><span class=\"book\">%s</span> <span class=\"author\">— %s</span> <span class=\"meta\">(%s%s)</span></li>", html_escape(title), html_escape(author), html_escape(date), (rating > 0 ? " · " stars(rating) : ""))
  years[key] = 1
}

END {
  n = 0
  for (y in years) ys[++n] = y
  for (i=1;i<=n;i++) for (j=i+1;j<=n;j++) if (ys[j] > ys[i]) { t=ys[i]; ys[i]=ys[j]; ys[j]=t }

  for (i=1;i<=n;i++) {
    y = ys[i]
    html = sprintf("<h3 class=\"year\">%s</h3><ol class=\"book_list\">%s</ol>", y, items[y])
    printf "%s |  | 0 | 0 | %s | \n", y, html
  }
}
