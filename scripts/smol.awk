#!/usr/bin/awk -f

function ltrim(s) { sub(/^[ \t]+/, "", s); return s }
function rtrim(s) { sub(/[ \t]+$/, "", s); return s }
function indent_count(s) { match(s, /^[ \t]*/); return RLENGTH }
function indent_str(level,   i, out) { out=""; for (i=0; i<level; i++) out = out "  "; return out }

function is_void(tag) {
  return (tag ~ /^(area|base|br|col|embed|hr|img|input|link|meta|param|source|track|wbr)$/)
}

function css_indent(level) { return indent_str(stack_depth + 1 + level) }

function close_to(indent) {
  while (stack_depth > 0 && indent <= stack_indent[stack_depth]) {
    print indent_str(stack_depth - 1) "</" stack_tag[stack_depth] ">"
    stack_depth--
  }
}

function css_close_to(indent) {
  while (css_depth > 0 && indent <= css_indent_level[css_depth]) {
    print css_indent(css_depth - 1) "}"
    css_depth--
  }
}

function css_open(selector, indent) {
  print css_indent(css_depth) selector " {"
  css_depth++
  css_indent_level[css_depth] = indent
  css_selector[css_depth] = selector
}

BEGIN {
  stack_depth = 0
  stack_indent[0] = -1
  raw_mode = 0
  raw_indent = -1
  raw_base_indent = -1
  css_mode = 0
  css_depth = 0
  css_base_indent = -1
}

{
  line = $0
  if (line ~ /^[ \t]*$/) { next }

  indent = indent_count(line)

  if (css_mode) {
    if (indent <= css_base_indent) {
      css_close_to(-1)
      print indent_str(stack_depth) "</style>"
      css_mode = 0
    } else {
      css_text = rtrim(substr(line, indent + 1))
      if (css_text ~ /^-#/) { next }
      if (css_depth == 0) {
        css_open(css_text, indent)
        next
      }
      if (css_text ~ /^@/) {
        css_close_to(indent)
        css_open(css_text, indent)
        next
      }
      if (css_text ~ /^&/) {
        selector = css_text
        sub(/^&/, css_selector[css_depth], selector)
        css_close_to(css_indent_level[css_depth])
        css_open(selector, indent)
        next
      }
      if (css_text ~ /^(\.|#|:|\[|\*)/) {
        css_close_to(indent)
        css_open(css_text, indent)
        next
      }
      if (css_text ~ /^--/) {
        prop = css_text
        if (prop !~ /;$/) prop = prop ";"
        print css_indent(css_depth) prop
        next
      }
      if (css_text ~ /^[A-Za-z]{2,}[A-Za-z0-9_-]*[ \t]*:/) {
        prop = css_text
        if (prop !~ /;$/) prop = prop ";"
        print css_indent(css_depth) prop
        next
      }
      css_close_to(indent)
      css_open(css_text, indent)
      next
    }
  }

  if (raw_mode) {
    if (indent <= raw_indent) {
      raw_mode = 0
      raw_base_indent = -1
    } else {
      if (raw_base_indent < 0) raw_base_indent = indent
      raw_line = substr(line, raw_base_indent + 1)
      print indent_str(stack_depth) raw_line
      next
    }
  }

  text = substr(line, indent + 1)
  text = rtrim(text)

  if (text ~ /^-#/) { next }

  close_to(indent)

  if (text ~ /^:raw$/ || text ~ /^:plain$/) {
    raw_mode = 1
    raw_indent = indent
    raw_base_indent = -1
    next
  }

  if (text ~ /^\|/) {
    raw_text = substr(text, 2)
    if (raw_text ~ /^ /) raw_text = substr(raw_text, 2)
    print indent_str(stack_depth) raw_text
    next
  }

  ch = substr(text, 1, 1)
  if (ch != "%" && ch != "." && ch != "#") {
    print indent_str(stack_depth) text
    next
  }

  pos = 1
  tag = "div"
  if (ch == "%") {
    pos = 2
    tag = ""
    while (pos <= length(text)) {
      c = substr(text, pos, 1)
      if (c ~ /[A-Za-z0-9_-]/) {
        tag = tag c
        pos++
      } else {
        break
      }
    }
  }

  id = ""
  classes = ""
  attrs = ""

  while (pos <= length(text)) {
    c = substr(text, pos, 1)
    if (c == ".") {
      pos++
      name = ""
      while (pos <= length(text)) {
        c = substr(text, pos, 1)
        if (c ~ /[A-Za-z0-9_-]/) {
          name = name c
          pos++
        } else {
          break
        }
      }
      if (name != "") {
        if (classes != "") classes = classes " "
        classes = classes name
      }
      continue
    }
    if (c == "#") {
      pos++
      name = ""
      while (pos <= length(text)) {
        c = substr(text, pos, 1)
        if (c ~ /[A-Za-z0-9_-]/) {
          name = name c
          pos++
        } else {
          break
        }
      }
      if (name != "") id = name
      continue
    }
    if (c == "(") {
      pos++
      depth = 1
      attr = ""
      while (pos <= length(text) && depth > 0) {
        c = substr(text, pos, 1)
        if (c == ")") {
          depth = 0
          pos++
          break
        }
        attr = attr c
        pos++
      }
      attrs = attr
      continue
    }
    if (c == " ") {
      pos++
      break
    }
    pos++
  }

  inline = rtrim(ltrim(substr(text, pos)))

  attrs = rtrim(attrs)
  if (id != "" && attrs !~ /(^|[ \t])id=/) {
    if (attrs != "") attrs = attrs " "
    attrs = attrs "id=\"" id "\""
  }
  if (classes != "" && attrs !~ /(^|[ \t])class=/) {
    if (attrs != "") attrs = attrs " "
    attrs = attrs "class=\"" classes "\""
  }
  if (attrs != "") attrs = " " attrs

  if (is_void(tag)) {
    print indent_str(stack_depth) "<" tag attrs " />"
    next
  }

  if (tag == "style" && inline == "") {
    print indent_str(stack_depth) "<style" attrs ">"
    css_mode = 1
    css_base_indent = indent
    css_depth = 0
    next
  }

  if (inline != "") {
    print indent_str(stack_depth) "<" tag attrs ">" inline "</" tag ">"
    next
  }

  print indent_str(stack_depth) "<" tag attrs ">"
  stack_depth++
  stack_tag[stack_depth] = tag
  stack_indent[stack_depth] = indent
}

END {
  if (css_mode) {
    css_close_to(-1)
    print indent_str(stack_depth) "</style>"
  }
  close_to(-1)
}
