#!/usr/bin/awk -f

function html_escape(s) {
  gsub(/&/, "&amp;", s)
  gsub(/</, "&lt;", s)
  gsub(/>/, "&gt;", s)
  return s
}

function html_attr_escape(s) {
  s = html_escape(s)
  gsub(/"/, "&quot;", s)
  return s
}

function md_inline(s,   out, pre, mid, post, text, url) {
  # Order matters: handle links first, then inline code/bold/italic.
  out = ""

  # Links: [text](url)
  while (match(s, /\[[^\]]+\]\([^\)]+\)/)) {
    pre = substr(s, 1, RSTART - 1)
    mid = substr(s, RSTART, RLENGTH)
    post = substr(s, RSTART + RLENGTH)

    text = mid
    sub(/^\[/, "", text)
    sub(/\]\([^\)]+\)$/, "", text)

    url = mid
    sub(/^\[[^\]]+\]\(/, "", url)
    sub(/\)$/, "", url)

    out = out html_escape(pre) "<a href=\"" html_attr_escape(url) "\">" html_escape(text) "</a>"
    s = post
  }

  out = out html_escape(s)

  # Inline code: `code` (avoid backrefs; keep it portable).
  while (match(out, /`[^`]+`/)) {
    pre = substr(out, 1, RSTART - 1)
    mid = substr(out, RSTART + 1, RLENGTH - 2)
    post = substr(out, RSTART + RLENGTH)
    out = pre "<code>" mid "</code>" post
  }

  # Bold: **x** (simple)
  while (match(out, /\*\*[^*]+\*\*/)) {
    pre = substr(out, 1, RSTART - 1)
    mid = substr(out, RSTART + 2, RLENGTH - 4)
    post = substr(out, RSTART + RLENGTH)
    out = pre "<strong>" mid "</strong>" post
  }

  return out
}

function flush_paragraph(   out) {
  if (para == "") return
  out = para
  para = ""
  print "<p>" md_inline(out) "</p>"
}

function close_list() {
  if (!in_list) return
  flush_paragraph()
  print "</ul>"
  in_list = 0
}

function close_blockquote() {
  if (!in_bq) return
  flush_paragraph()
  print "</blockquote>"
  in_bq = 0
}

function close_code() {
  if (!in_code) return
  print "</code></pre>"
  in_code = 0
}

BEGIN {
  in_code = 0
  in_list = 0
  in_bq = 0
  para = ""
}

{
  sub(/\r$/, "", $0)
  line = $0

  if (line ~ /^```/) {
    close_list()
    close_blockquote()
    flush_paragraph()
    if (!in_code) {
      print "<pre><code>"
      in_code = 1
    } else {
      close_code()
    }
    next
  }

  if (in_code) {
    # In code blocks, preserve quotes as-is (no need to escape them).
    print html_escape(line)
    next
  }

  if (line ~ /^[ \t]*$/) {
    close_list()
    close_blockquote()
    flush_paragraph()
    next
  }

  if (in_bq && line !~ /^>/) {
    close_blockquote()
  }

  if (line ~ /^>[ \t]+/) {
    close_list()
    flush_paragraph()
    if (!in_bq) {
      print "<blockquote>"
      in_bq = 1
    }
    sub(/^>[ \t]+/, "", line)
    print "<p>" md_inline(line) "</p>"
    next
  }

  # Headings: one to six leading # followed by whitespace.
  if (substr(line, 1, 1) == "#") {
    level = 0
    while (level < 6 && substr(line, level + 1, 1) == "#") level++

    # Must have at least one space/tab after the # run.
    if (substr(line, level + 1, 1) == " " || substr(line, level + 1, 1) == "\t") {
      close_list()
      close_blockquote()
      flush_paragraph()

      text = substr(line, level + 1)
      sub(/^[ \t]+/, "", text)

      print "<h" level ">" md_inline(text) "</h" level ">"
      next
    }
  }

  if (match(line, /^[-*][ \t]+/)) {
    close_blockquote()
    flush_paragraph()
    if (!in_list) {
      print "<ul>"
      in_list = 1
    }
    sub(/^[-*][ \t]+/, "", line)
    print "<li>" md_inline(line) "</li>"
    next
  }

  close_list()
  close_blockquote()

  if (para != "") para = para " " line
  else para = line
}

END {
  close_list()
  close_blockquote()
  flush_paragraph()
  close_code()
}
