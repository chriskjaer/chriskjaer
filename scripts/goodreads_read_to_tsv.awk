#!/usr/bin/awk -f

# Extract read-shelf fields from Goodreads RSS XML into TSV.
# Output: date_read<TAB>pages<TAB>rating_int<TAB>title<TAB>author

function ltrim(s) { sub(/^[ \t]+/, "", s); return s }
function rtrim(s) { sub(/[ \t]+$/, "", s); return s }
function trim(s) { return rtrim(ltrim(s)) }

function html_unescape(s) {
  gsub(/<!\[CDATA\[/, "", s)
  gsub(/\]\]>/, "", s)
  gsub(/&amp;/, "&", s)
  gsub(/&quot;/, "\"", s)
  gsub(/&apos;/, "'", s)
  gsub(/&#39;/, "'", s)
  gsub(/&lt;/, "<", s)
  gsub(/&gt;/, ">", s)
  return s
}

function extract(tag, item,   start, gt, end, end_tag, val) {
  start = index(item, "<" tag)
  if (start <= 0) return ""
  gt = index(substr(item, start), ">")
  if (gt <= 0) return ""
  gt = start + gt - 1

  end_tag = "</" tag ">"
  end = index(substr(item, gt + 1), end_tag)
  if (end <= 0) return ""

  val = substr(item, gt + 1, end - 1)
  return val
}

function rss_date_to_ymd(raw,   s) {
  s = trim(raw)
  s = html_unescape(s)
  if (s == "") return ""

  if (match(s, /^[0-9]{4}-[0-9]{2}-[0-9]{2}/)) return substr(s, 1, 10)
  if (match(s, /, *([0-9]{1,2}) +([A-Za-z]{3}) +([0-9]{4})/, m)) {
    day = sprintf("%02d", m[1] + 0)
    mon = m[2]
    year = m[3]
    month = ""
    if (mon == "Jan") month = "01"
    else if (mon == "Feb") month = "02"
    else if (mon == "Mar") month = "03"
    else if (mon == "Apr") month = "04"
    else if (mon == "May") month = "05"
    else if (mon == "Jun") month = "06"
    else if (mon == "Jul") month = "07"
    else if (mon == "Aug") month = "08"
    else if (mon == "Sep") month = "09"
    else if (mon == "Oct") month = "10"
    else if (mon == "Nov") month = "11"
    else if (mon == "Dec") month = "12"
    if (month != "") return year "-" month "-" day
  }
  return ""
}

BEGIN {
  RS = "</item>"
  ORS = ""
}

{
  item = $0
  if (index(item, "<item") == 0) next
  sub(/.*<item[^>]*>/, "", item)

  title = trim(html_unescape(extract("title", item)))
  author = trim(html_unescape(extract("author_name", item)))
  rating = trim(html_unescape(extract("user_rating", item)))
  pages = trim(html_unescape(extract("num_pages", item)))
  date_read = rss_date_to_ymd(extract("user_read_at", item))

  if (date_read == "") next

  rating_int = rating + 0
  pages_int = pages + 0

  printf "%s\t%d\t%d\t%s\t%s\n", date_read, pages_int, rating_int, title, author
}
