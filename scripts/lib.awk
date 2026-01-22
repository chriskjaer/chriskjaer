# shared awk helpers

function trim(s) { sub(/^[ \t\r\n]+/, "", s); sub(/[ \t\r\n]+$/, "", s); return s }

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

function rss_date_to_ymd(raw,   s, parts, day, mon, year, month) {
  s = trim(html_unescape(raw))
  if (s == "") return ""

  if (s ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/) return substr(s, 1, 10)

  sub(/^.*,[ \t]*/, "", s)

  split(s, parts, /[ \t]+/)
  if (length(parts) < 3) return ""

  day = sprintf("%02d", parts[1] + 0)
  mon = parts[2]
  year = parts[3]

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

  return ""
}
