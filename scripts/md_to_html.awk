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
  code_flush()
  code_buf_clear()
  in_code = 0
}

BEGIN {
  in_code = 0
  in_list = 0
  in_bq = 0
  para = ""

  code_len = 0
}

function code_buf_clear(   i) {
  for (i = 1; i <= code_len; i++) delete code_buf[i]
  code_len = 0
}

function code_buf_push(s) {
  code_len++
  code_buf[code_len] = s
}

function code_flush(   i, s, n, min, lead) {
  if (code_len == 0) {
    # Empty block
    print "<pre><code></code></pre>"
    return
  }

  # Compute minimal leading indentation among non-empty lines.
  min = -1
  for (i = 1; i <= code_len; i++) {
    s = code_buf[i]
    if (s ~ /^[ \t]*$/) continue
    lead = 0
    while (substr(s, lead + 1, 1) == " " || substr(s, lead + 1, 1) == "\t") lead++
    if (min < 0 || lead < min) min = lead
  }
  if (min < 0) min = 0

  # Emit without a leading blank line.
  printf "%s", "<pre><code>"
  for (i = 1; i <= code_len; i++) {
    s = code_buf[i]
    if (min > 0) {
      # Strip up to min leading whitespace characters.
      n = 0
      while (n < min && (substr(s, n + 1, 1) == " " || substr(s, n + 1, 1) == "\t")) n++
      s = substr(s, n + 1)
    }
    printf "%s\n", html_escape(s)
  }
  print "</code></pre>"
}

{
  sub(/\r$/, "", $0)
  line = $0

  if (line ~ /^```/) {
    close_list()
    close_blockquote()
    flush_paragraph()

    if (!in_code) {
      in_code = 1
      code_buf_clear()
    } else {
      code_flush()
      code_buf_clear()
      in_code = 0
    }
    next
  }

  if (in_code) {
    code_buf_push(line)
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
