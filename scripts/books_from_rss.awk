#!/usr/bin/awk -f

# Requires: awk -f scripts/lib.awk -f scripts/books_from_rss.awk
# Output: shelf | date | rating | pages | title | author

BEGIN {
  RS = "</item>"
  ORS = ""

  if (SHELF == "") {
    print "books_from_rss.awk: missing -v SHELF" > "/dev/stderr"
    exit 2
  }
  if (DATE_FIELD == "") {
    print "books_from_rss.awk: missing -v DATE_FIELD" > "/dev/stderr"
    exit 2
  }
}

{
  item = $0
  if (index(item, "<item") == 0) next
  sub(/.*<item[^>]*>/, "", item)

  title = trim(html_unescape(extract("title", item)))
  author = trim(html_unescape(extract("author_name", item)))
  rating = trim(html_unescape(extract("user_rating", item))) + 0
  pages = trim(html_unescape(extract("num_pages", item))) + 0

  if (DATE_FIELD == "read_at") {
    date = rss_date_to_ymd(extract("user_read_at", item))
  } else if (DATE_FIELD == "created") {
    date = rss_date_to_ymd(extract("user_date_created", item))
  } else {
    date = ""
  }

  if (date == "") next

  printf "%s | %s | %d | %d | %s | %s\n", SHELF, date, rating, pages, title, author
}
