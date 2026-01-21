#!/usr/bin/awk -f

function stars(n,  i, s) { s=""; for (i=0;i<n;i++) s=s"★"; return s }

BEGIN {
  FS = "\t"
  if (OUT_READ == "" || OUT_STATS == "") exit 2
}

{
  year = $1 + 0
  date = $2
  rating = $3 + 0
  pages = $4 + 0
  title = $5
  author = $6

  years[year] = 1
  books[year] += 1
  if (pages > 0) pages_sum[year] += pages
  if (books[year] > max_books) max_books = books[year]

  row_year[NR] = year
  row_date[NR] = date
  row_rating[NR] = rating
  row_title[NR] = title
  row_author[NR] = author
}

END {
  n = 0
  for (y in years) ys[++n] = y
  for (i=1;i<=n;i++) for (j=i+1;j<=n;j++) if (ys[j] > ys[i]) { t=ys[i]; ys[i]=ys[j]; ys[j]=t }

  print "-# Generated file. Do not edit." > OUT_STATS
  print "-# Source: Goodreads read shelf RSS." > OUT_STATS
  print "" > OUT_STATS
  print "ul.chart" > OUT_STATS

  for (i=1;i<=n;i++) {
    y = ys[i]
    b = books[y] + 0
    p = pages_sum[y] + 0
    pct = (max_books > 0) ? int((b / max_books) * 100 + 0.5) : 0

    print "  li.bar" > OUT_STATS
    print "    span.year" > OUT_STATS
    print "      | " y > OUT_STATS
    print "    span.track" > OUT_STATS
    print "      span.fill(style=\"width: " pct "%\")" > OUT_STATS
    print "    span.count" > OUT_STATS
    if (p > 0) print "      | " b " books · " p " pages" > OUT_STATS
    else print "      | " b " books" > OUT_STATS
  }

  print "-# Generated file. Do not edit." > OUT_READ
  print "-# Source: Goodreads read shelf RSS." > OUT_READ
  print "" > OUT_READ

  current = -1
  for (r=1;r<=NR;r++) {
    y = row_year[r]
    if (y != current) {
      if (current != -1) print "" > OUT_READ
      print "h3.year" > OUT_READ
      print "  | " y > OUT_READ
      print "ol.book_list" > OUT_READ
      current = y
    }

    print "  li" > OUT_READ
    print "    span.book" > OUT_READ
    print "      | " row_title[r] > OUT_READ
    print "    | " > OUT_READ
    print "" > OUT_READ
    print "    span.author" > OUT_READ
    print "      | — " row_author[r] > OUT_READ
    print "    | " > OUT_READ
    print "" > OUT_READ
    print "    span.meta" > OUT_READ
    if (row_rating[r] > 0) print "      | (" row_date[r] " · " stars(row_rating[r]) ")" > OUT_READ
    else print "      | (" row_date[r] ")" > OUT_READ
  }
}
