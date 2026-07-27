#!/usr/bin/awk -f

# Validate one Goodreads RSS page and emit normalized pipe-delimited rows.
# Exit 0: usable rows, 2: no items, 3: items but no usable rows, 1: invalid feed.

function fail(message) {
  print "invalid Goodreads RSS: " message > "/dev/stderr"
  status = 1
  exit 1
}

function trim(s) {
  sub(/^[ \t\r\n]+/, "", s)
  sub(/[ \t\r\n]+$/, "", s)
  return s
}

function squash(s) {
  gsub(/[ \t\r\n]+/, " ", s)
  return trim(s)
}

function remove_blocks(s, open_marker, close_marker,   before, after, start, finish) {
  while ((start = index(s, open_marker)) > 0) {
    before = substr(s, 1, start - 1)
    after = substr(s, start + length(open_marker))
    finish = index(after, close_marker)
    if (finish == 0) fail("unterminated " open_marker " block")
    s = before substr(after, finish + length(close_marker))
  }
  return s
}

function encode_cdata(s,   after, before, finish, inner, start) {
  while ((start = index(s, "<![CDATA[")) > 0) {
    before = substr(s, 1, start - 1)
    after = substr(s, start + length("<![CDATA["))
    finish = index(after, "]]>")
    if (finish == 0) fail("unterminated CDATA block")
    inner = substr(after, 1, finish - 1)
    gsub(/&/, "\\&amp;", inner)
    gsub(/</, "\\&lt;", inner)
    gsub(/>/, "\\&gt;", inner)
    s = before inner substr(after, finish + length("]]>") )
  }
  return s
}

function count_literal(s, needle,   count, pos) {
  count = 0
  while ((pos = index(s, needle)) > 0) {
    count++
    s = substr(s, pos + length(needle))
  }
  return count
}

function xml_text(s) {
  gsub(/&#39;/, "'", s)
  gsub(/&apos;/, "'", s)
  gsub(/&quot;/, "\"", s)
  gsub(/&lt;/, "<", s)
  gsub(/&gt;/, ">", s)
  gsub(/&amp;/, "\\&", s)
  s = squash(s)
  gsub(/\|/, "¦", s)
  return s
}

function extract(tag, item,   close_tag, finish, gt, rest, start) {
  start = index(item, "<" tag)
  if (start == 0) return ""
  rest = substr(item, start)
  gt = index(rest, ">")
  if (gt == 0) return ""
  rest = substr(rest, gt + 1)
  close_tag = "</" tag ">"
  finish = index(rest, close_tag)
  if (finish == 0) return ""
  return substr(rest, 1, finish - 1)
}

function date_ymd(raw,   day, mon, month, parts, s, year) {
  s = xml_text(raw)
  if (s ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/) return substr(s, 1, 10)
  sub(/^.*,[ \t]*/, "", s)
  split(s, parts, /[ \t]+/)
  if (parts[1] !~ /^[0-9][0-9]?$/ || parts[3] !~ /^[0-9][0-9][0-9][0-9]$/) return ""
  day = sprintf("%02d", parts[1] + 0)
  mon = parts[2]
  year = parts[3]
  month = index("JanFebMarAprMayJunJulAugSepOctNovDec", mon)
  if (month == 0 || (month - 1) % 3 != 0) return ""
  month = sprintf("%02d", int((month - 1) / 3) + 1)
  return year "-" month "-" day
}

function number(raw,   value) {
  value = xml_text(raw)
  return value ~ /^-?[0-9]+$/ ? value + 0 : 0
}

BEGIN {
  if (SHELF == "" || (DATE_FIELD != "read_at" && DATE_FIELD != "created")) {
    fail("usage: awk -v SHELF=name -v DATE_FIELD=read_at|created -f goodreads_rss_to_rows.awk file")
  }
}

{
  document = document $0 "\n"
}

END {
  if (status == 1) exit 1
  if (length(document) > 5242880) fail("response exceeds 5242880 bytes")

  upper = toupper(document)
  if (index(upper, "<!DOCTYPE") || index(upper, "<!ENTITY")) fail("DTD and entity declarations are not allowed")

  document = remove_blocks(document, "<!--", "-->")
  document = encode_cdata(document)
  document = trim(document)
  sub(/^<\?xml[^?]*\?>[ \t\r\n]*/, "", document)

  if (document !~ /^<rss([ \t\r\n>])/ || document !~ /<\/rss>[ \t\r\n]*$/) fail("root element is not unnamespaced rss")
  if (count_literal(document, "<rss") != 1 || count_literal(document, "</rss>") != 1) fail("expected exactly one rss element")

  namespaced = document
  gsub(/<\/?atom:link[^>]*>/, "", namespaced)
  gsub(/<\/?xhtml:meta[^>]*>/, "", namespaced)
  if (namespaced ~ /<\/?[[:alnum:]_-]+:/) fail("unexpected namespaced element")

  if (count_literal(document, "<channel>") != 1 || count_literal(document, "</channel>") != 1) fail("expected exactly one channel element")
  channel_start = index(document, "<channel>")
  channel_rest = substr(document, channel_start + length("<channel>"))
  channel_end = index(channel_rest, "</channel>")
  if (channel_start == 0 || channel_end == 0) fail("invalid channel element")
  channel = substr(channel_rest, 1, channel_end - 1)

  channel_metadata = remove_blocks(channel, "<item>", "</item>")
  channel_metadata = remove_blocks(channel_metadata, "<image>", "</image>")
  if (count_literal(channel_metadata, "<title>") != 1 || count_literal(channel_metadata, "</title>") != 1) fail("expected exactly one channel title")
  channel_title = xml_text(extract("title", channel_metadata))
  suffix = " bookshelf: " SHELF
  if (length(channel_title) < length(suffix) || substr(channel_title, length(channel_title) - length(suffix) + 1) != suffix) fail("channel title does not identify shelf " SHELF)

  items = 0
  usable = 0
  rest = channel
  while ((item_start = index(rest, "<item>")) > 0) {
    rest = substr(rest, item_start + length("<item>"))
    item_end = index(rest, "</item>")
    if (item_end == 0) fail("unterminated item")
    item = substr(rest, 1, item_end - 1)
    rest = substr(rest, item_end + length("</item>"))
    items++

    title = xml_text(extract("title", item))
    author = xml_text(extract("author_name", item))
    date_tag = DATE_FIELD == "read_at" ? "user_read_at" : "user_date_created"
    date = date_ymd(extract(date_tag, item))
    if (title == "" || author == "" || date == "") continue

    rating = number(extract("user_rating", item))
    pages = number(extract("num_pages", item))
    printf "%s | %s | %d | %d | %s | %s\n", SHELF, date, rating, pages, title, author
    usable++
  }

  if (items == 0) exit 2
  if (usable == 0) exit 3
  exit 0
}
