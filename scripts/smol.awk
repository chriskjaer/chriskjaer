#!/usr/bin/awk -f

function ltrim(s) { sub(/^[ \t]+/, "", s); return s }
function rtrim(s) { sub(/[ \t]+$/, "", s); return s }
function indent_count(s) { match(s, /^[ \t]*/); return RLENGTH }
function indent_str(level,   i, out) { out=""; for (i=0; i<level; i++) out = out "  "; return out }

function is_void(tag) {
  return (tag ~ /^(area|base|br|col|embed|hr|img|input|link|meta|param|source|track|wbr)$/)
}

function emit(line) {
  if (autowrap) {
    if (emit_target == "head") {
      head_lines[++head_count] = line
    } else if (emit_target == "body") {
      body_lines[++body_count] = line
    } else {
      print line
    }
  } else {
    print line
  }
}

function reset_state() {
  stack_depth = 0
  stack_indent[0] = -1
  raw_mode = 0
  raw_indent = -1
  raw_base_indent = -1
  css_mode = 0
  css_depth = 0
  css_base_indent = -1
}

function css_indent(level) { return indent_str(stack_depth + 1 + level) }

function close_to(indent) {
  while (stack_depth > 0 && indent <= stack_indent[stack_depth]) {
    emit(indent_str(stack_depth - 1) "</" stack_tag[stack_depth] ">")
    stack_depth--
  }
}

function css_close_to(indent) {
  while (css_depth > 0 && indent <= css_indent_level[css_depth]) {
    emit(css_indent(css_depth - 1) "}")
    css_depth--
  }
}

function css_open(selector, indent) {
  emit(css_indent(css_depth) selector " {")
  css_depth++
  css_indent_level[css_depth] = indent
  css_selector[css_depth] = selector
}

function interpolate(s,   key, val, start) {
  while (match(s, /#\{[A-Za-z0-9_-]+\}/)) {
    start = RSTART
    key = substr(s, RSTART + 2, RLENGTH - 3)
    val = (key in vars) ? vars[key] : ""
    s = substr(s, 1, start - 1) val substr(s, start + RLENGTH)
  }
  return s
}

function strip_quotes(s) {
  s = rtrim(ltrim(s))
  if (s ~ /^".*"$/) return substr(s, 2, length(s) - 2)
  if (s ~ /^'.*'$/) return substr(s, 2, length(s) - 2)
  return s
}

function path_dir(path,   dir) {
  dir = path
  sub(/\/[^\/]*$/, "", dir)
  sub(/\/$/, "", dir)
  if (dir == "") dir = "."
  return dir
}

function join_path(dir, file) {
  if (file ~ /^\//) return file
  if (dir == "." || dir == "") return file
  return dir "/" file
}

function parse_include(text) {
  text = ltrim(substr(text, length("@include") + 1))
  text = strip_quotes(text)
  return interpolate(text)
}

function handle_directive(text, indent, file_dir, line,   rest, key, val, attrs, inc, path, prefix) {
  if (match(text, /^@set[ \t]+/)) {
    rest = ltrim(substr(text, RLENGTH + 1))
    key = rest
    sub(/[ \t].*$/, "", key)
    val = ltrim(substr(rest, length(key) + 1))
    val = strip_quotes(val)
    vars[key] = interpolate(val)
    return 1
  }

  if (match(text, /^@title[ \t]+/)) {
    rest = ltrim(substr(text, RLENGTH + 1))
    meta_title = interpolate(strip_quotes(rest))
    return 1
  }

  if (match(text, /^@description[ \t]+/)) {
    rest = ltrim(substr(text, RLENGTH + 1))
    meta_description = interpolate(strip_quotes(rest))
    return 1
  }

  if (match(text, /^@viewport[ \t]+/)) {
    rest = ltrim(substr(text, RLENGTH + 1))
    meta_viewport = interpolate(strip_quotes(rest))
    return 1
  }

  if (match(text, /^@lang[ \t]+/)) {
    rest = ltrim(substr(text, RLENGTH + 1))
    meta_lang = interpolate(strip_quotes(rest))
    return 1
  }

  if (match(text, /^@charset[ \t]+/)) {
    rest = ltrim(substr(text, RLENGTH + 1))
    meta_charset = interpolate(strip_quotes(rest))
    return 1
  }

  if (text ~ /^@meta[ \t]*\(/) {
    attrs = text
    sub(/^@meta[ \t]*\(/, "", attrs)
    sub(/\)[ \t]*$/, "", attrs)
    attrs = interpolate(attrs)
    meta_extra[++meta_count] = attrs
    return 1
  }

  if (match(text, /^@include[ \t]+/)) {
    inc = parse_include(text)
    if (inc == "") return 1
    path = join_path(file_dir, inc)
    prefix = substr(line, 1, indent)
    process_file(path, prefix)
    return 1
  }

  return 0
}

function start_section(name, indent) {
  section_name = name
  section_indent = indent
  section_base_indent = -1
  emit_target = name
  reset_state()
}

function end_section() {
  if (css_mode) {
    css_close_to(-1)
    emit(indent_str(stack_depth) "</style>")
    css_mode = 0
  }
  close_to(-1)
  raw_mode = 0
  raw_indent = -1
  raw_base_indent = -1
}

function process_line(line, file_dir,   indent, text, ch, pos, c, tag, id, classes, attrs, name, depth, inline, raw_text, raw_line, css_text, selector, prop) {
  if (line ~ /^[ \t]*$/) return

  indent = indent_count(line)
  text = rtrim(ltrim(line))

  if (text ~ /^-#/) return

  if (autowrap && section_name == "") {
    if (text ~ /^:head([ \t]|$)/) {
      start_section("head", indent)
      return
    }
    if (text ~ /^:body([ \t]|$)/) {
      start_section("body", indent)
      return
    }
    if (handle_directive(text, indent, file_dir, line)) return
    start_section("body", indent - 1)
    section_base_indent = indent
    line = substr(line, indent + 1)
    indent = 0
    text = rtrim(ltrim(line))
  } else {
    if (autowrap && section_name != "" && indent <= section_indent) {
      end_section()
      section_name = ""
      section_base_indent = -1
      process_line(line, file_dir)
      return
    }
    if (section_name != "") {
      if (section_base_indent < 0) section_base_indent = indent
      line = substr(line, section_base_indent + 1)
      indent = indent - section_base_indent
      text = rtrim(ltrim(line))
    }
    if (handle_directive(text, indent, file_dir, line)) return
  }

  text = interpolate(text)

  if (css_mode) {
    if (indent <= css_base_indent) {
      css_close_to(-1)
      emit(indent_str(stack_depth) "</style>")
      css_mode = 0
    } else {
      css_text = rtrim(substr(line, indent + 1))
      css_text = interpolate(css_text)
      if (css_text ~ /^-#/) return
      if (css_depth == 0) {
        css_open(css_text, indent)
        return
      }
      if (css_text ~ /^@/) {
        css_close_to(indent)
        css_open(css_text, indent)
        return
      }
      if (css_text ~ /^&/) {
        selector = css_text
        sub(/^&/, css_selector[css_depth], selector)
        css_close_to(css_indent_level[css_depth])
        css_open(selector, indent)
        return
      }
      if (css_text ~ /^(\.|#|:|\[|\*)/) {
        css_close_to(indent)
        css_open(css_text, indent)
        return
      }
      if (css_text ~ /^--/) {
        prop = css_text
        if (prop !~ /;$/) prop = prop ";"
        emit(css_indent(css_depth) prop)
        return
      }
      if (css_text ~ /^-?[A-Za-z][A-Za-z0-9_-]*[ \t]*:/) {
        prop = css_text
        if (prop !~ /;$/) prop = prop ";"
        emit(css_indent(css_depth) prop)
        return
      }
      css_close_to(indent)
      css_open(css_text, indent)
      return
    }
  }

  if (raw_mode) {
    if (indent <= raw_indent) {
      raw_mode = 0
      raw_base_indent = -1
    } else {
      if (raw_base_indent < 0) raw_base_indent = indent
      raw_line = substr(line, raw_base_indent + 1)
      raw_line = interpolate(raw_line)
      emit(indent_str(stack_depth) raw_line)
      return
    }
  }

  close_to(indent)

  if (text ~ /^:raw$/ || text ~ /^:plain$/) {
    raw_mode = 1
    raw_indent = indent
    raw_base_indent = -1
    return
  }

  if (text ~ /^\|/) {
    raw_text = substr(text, 2)
    if (raw_text ~ /^ /) raw_text = substr(raw_text, 2)
    emit(indent_str(stack_depth) raw_text)
    return
  }

  ch = substr(text, 1, 1)
  if (ch != "%" && ch != "." && ch != "#") {
    emit(indent_str(stack_depth) text)
    return
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
    emit(indent_str(stack_depth) "<" tag attrs " />")
    return
  }

  if (tag == "style" && inline == "") {
    emit(indent_str(stack_depth) "<style" attrs ">")
    css_mode = 1
    css_base_indent = indent
    css_depth = 0
    return
  }

  if (inline != "") {
    emit(indent_str(stack_depth) "<" tag attrs ">" inline "</" tag ">")
    return
  }

  emit(indent_str(stack_depth) "<" tag attrs ">")
  stack_depth++
  stack_tag[stack_depth] = tag
  stack_indent[stack_depth] = indent
}

function process_file(path, prefix,   line, full, prev_dir, dir) {
  if (++include_depth > 20) {
    print "smol: include depth too deep" > "/dev/stderr"
    exit 1
  }
  if (include_stack[path]++) {
    print "smol: recursive include: " path > "/dev/stderr"
    exit 1
  }
  prev_dir = current_dir
  dir = path_dir(path)
  current_dir = dir
  while ((getline line < path) > 0) {
    full = (prefix != "") ? prefix line : line
    process_line(full, current_dir)
  }
  close(path)
  current_dir = prev_dir
  include_stack[path] = 0
  include_depth--
}

function scan_file(path,   line, text, dir, inc) {
  if (scan_stack[path]++) return
  dir = path_dir(path)
  while ((getline line < path) > 0) {
    text = rtrim(ltrim(line))
    if (text ~ /^-#/ || text == "") continue
    if (match(text, /^@include[ \t]+/)) {
      inc = parse_include(text)
      if (inc != "") scan_file(join_path(dir, inc))
      continue
    }
    if (text ~ /^\|[ \t]*<!doctype/ || text ~ /^<!doctype/ || text ~ /^%html([ \t]|$)/ || text ~ /^%head([ \t]|$)/ || text ~ /^%body([ \t]|$)/) {
      found_html = 1
    }
    if (text ~ /^:head([ \t]|$)/ || text ~ /^:body([ \t]|$)/ || text ~ /^@title([ \t]|$)/ || text ~ /^@description([ \t]|$)/ || text ~ /^@viewport([ \t]|$)/ || text ~ /^@lang([ \t]|$)/ || text ~ /^@charset([ \t]|$)/ || text ~ /^@meta([ \t]|$|\()/) {
      found_sections = 1
    }
  }
  close(path)
  scan_stack[path] = 0
}

function move_blocks(   i, line, capture, capture_type, j, out_count) {
  capture = 0
  tmp_count = 0
  out_count = 0

  for (i = 1; i <= body_count; i++) {
    line = body_lines[i]
    if (capture) {
      sub(/^  /, "", line)
      tmp_lines[++tmp_count] = line
      if ((capture_type == "style" && line ~ /<\/style>/) || (capture_type == "script" && line ~ /<\/script>/)) {
        if (capture_type == "style") {
          for (j = 1; j <= tmp_count; j++) head_lines[++head_count] = tmp_lines[j]
        } else {
          for (j = 1; j <= tmp_count; j++) script_lines[++script_count] = tmp_lines[j]
        }
        capture = 0
        tmp_count = 0
      }
      continue
    }

    if (line ~ /<style[ >]/) {
      capture = 1
      capture_type = "style"
      tmp_count = 0
      sub(/^  /, "", line)
      tmp_lines[++tmp_count] = line
      if (line ~ /<\/style>/) {
        for (j = 1; j <= tmp_count; j++) head_lines[++head_count] = tmp_lines[j]
        capture = 0
        tmp_count = 0
      }
      continue
    }

    if (line ~ /<script[ >]/) {
      capture = 1
      capture_type = "script"
      tmp_count = 0
      sub(/^  /, "", line)
      tmp_lines[++tmp_count] = line
      if (line ~ /<\/script>/) {
        for (j = 1; j <= tmp_count; j++) script_lines[++script_count] = tmp_lines[j]
        capture = 0
        tmp_count = 0
      }
      continue
    }

    body_out[++out_count] = line
  }

  body_count = out_count
  for (i = 1; i <= body_count; i++) body_lines[i] = body_out[i]
}

function flush_autowrap(   i) {
  if (section_name != "") {
    end_section()
    section_name = ""
  }

  move_blocks()

  if (meta_lang == "") meta_lang = "en"
  if (meta_charset == "") meta_charset = "utf-8"
  if (meta_viewport == "") meta_viewport = "width=device-width, initial-scale=1"

  print "<!doctype html>"
  print "<html lang=\"" meta_lang "\">"
  print indent_str(1) "<head>"
  print indent_str(2) "<meta charset=\"" meta_charset "\" />"
  if (meta_title != "") print indent_str(2) "<title>" meta_title "</title>"
  if (meta_description != "") print indent_str(2) "<meta name=\"description\" content=\"" meta_description "\" />"
  if (meta_viewport != "") print indent_str(2) "<meta name=\"viewport\" content=\"" meta_viewport "\" />"
  for (i = 1; i <= meta_count; i++) print indent_str(2) "<meta " meta_extra[i] " />"
  for (i = 1; i <= head_count; i++) print indent_str(2) head_lines[i]
  print indent_str(1) "</head>"
  print indent_str(1) "<body>"
  for (i = 1; i <= body_count; i++) print indent_str(2) body_lines[i]
  for (i = 1; i <= script_count; i++) print indent_str(2) script_lines[i]
  print indent_str(1) "</body>"
  print "</html>"
}

BEGIN {
  main_file = ARGV[1]
  if (main_file == "") exit 1
  for (i = 1; i < ARGC; i++) ARGV[i] = ""
  ARGC = 1

  reset_state()

  found_html = 0
  found_sections = 0
  scan_file(main_file)
  autowrap = (found_sections && !found_html)
  emit_target = "stdout"

  process_file(main_file, "")

  if (autowrap) {
    flush_autowrap()
  } else {
    if (css_mode) {
      css_close_to(-1)
      emit(indent_str(stack_depth) "</style>")
    }
    close_to(-1)
  }
}
