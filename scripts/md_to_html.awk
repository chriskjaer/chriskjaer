#!/usr/bin/awk -f

function html_escape(s) {
  gsub(/&/, "&amp;", s)
  gsub(/</, "&lt;", s)
  gsub(/>/, "&gt;", s)
  return s
}

function flush_paragraph(   out) {
  if (para == "") return
  out = para
  para = ""
  print "<p>" out "</p>"
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
    print "<p>" html_escape(line) "</p>"
    next
  }

  if (match(line, /^#{1,6}[ \t]+/)) {
    close_list()
    close_blockquote()
    flush_paragraph()

    level = 0
    while (substr(line, level + 1, 1) == "#") level++
    text = substr(line, level + 1)
    sub(/^[ \t]+/, "", text)

    print "<h" level ">" html_escape(text) "</h" level ">"
    next
  }

  if (match(line, /^[-*][ \t]+/)) {
    close_blockquote()
    flush_paragraph()
    if (!in_list) {
      print "<ul>"
      in_list = 1
    }
    sub(/^[-*][ \t]+/, "", line)
    print "<li>" html_escape(line) "</li>"
    next
  }

  close_list()
  close_blockquote()

  line = html_escape(line)
  if (para != "") para = para " " line
  else para = line
}

END {
  close_list()
  close_blockquote()
  flush_paragraph()
  close_code()
}
