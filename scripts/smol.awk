#!/usr/bin/awk -f

function ltrim(s) { sub(/^[ \t]+/, "", s); return s }
function rtrim(s) { sub(/[ \t]+$/, "", s); return s }
function trim(s) { return rtrim(ltrim(s)) }
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

function close_to_depth(target_depth) {
  while (stack_depth > target_depth) {
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

function css_close_to_depth(target_depth) {
  while (css_depth > target_depth) {
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
  while (match(s, /#\{[A-Za-z0-9_.-]+\}/)) {
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

function sh_escape(s) {
  gsub(/'/, "'\"'\"'", s)
  return "'" s "'"
}

function set_var_line(text,   key, val) {
  if (text == "") return
  key = text
  if (match(text, /^[A-Za-z0-9_-]+[ \t]*=/)) {
    key = substr(text, 1, RLENGTH)
    gsub(/[ \t=]/, "", key)
    val = substr(text, RLENGTH + 1)
  } else {
    sub(/[ \t].*$/, "", key)
    val = substr(text, length(key) + 1)
  }
  val = ltrim(val)
  if (val ~ /^=/) val = ltrim(substr(val, 2))
  val = interpolate(strip_quotes(val))
  if (key != "") vars[key] = val
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

function parse_include_parts(text,   rest, file, q, pos) {
  include_file = ""
  include_params = ""
  rest = ltrim(substr(text, length("@include") + 1))
  if (rest == "") return
  if (rest ~ /^"/ || rest ~ /^'/) {
    q = substr(rest, 1, 1)
    rest = substr(rest, 2)
    pos = index(rest, q)
    if (pos > 0) {
      file = substr(rest, 1, pos - 1)
      include_params = ltrim(substr(rest, pos + 1))
    } else {
      file = rest
      include_params = ""
    }
  } else {
    file = rest
    sub(/[ \t].*$/, "", file)
    include_params = ltrim(substr(rest, length(file) + 1))
  }
  include_file = interpolate(strip_quotes(file))
}

function parse_include(text) {
  parse_include_parts(text)
  return include_file
}

function parse_layout_parts(text,   rest, file, q, pos) {
  layout_path = ""
  rest = ltrim(substr(text, length("@layout") + 1))
  if (rest == "") return

  if (rest ~ /^"/ || rest ~ /^'/) {
    q = substr(rest, 1, 1)
    rest = substr(rest, 2)
    pos = index(rest, q)
    if (pos > 0) {
      file = substr(rest, 1, pos - 1)
    } else {
      file = rest
    }
  } else {
    file = rest
    sub(/[ \t].*$/, "", file)
  }

  layout_path = interpolate(strip_quotes(file))
}

function parse_params(params,   rest, key, val, q, pos) {
  param_count = 0
  rest = params
  while (1) {
    sub(/^[ \t]+/, "", rest)
    if (rest == "") break
    if (!match(rest, /^[A-Za-z0-9_-]+/)) break
    key = substr(rest, RSTART, RLENGTH)
    rest = substr(rest, RLENGTH + 1)
    sub(/^[ \t]*/, "", rest)
    if (substr(rest, 1, 1) == "=") {
      rest = substr(rest, 2)
      sub(/^[ \t]*/, "", rest)
    }
    if (substr(rest, 1, 1) == "\"" || substr(rest, 1, 1) == "'") {
      q = substr(rest, 1, 1)
      rest = substr(rest, 2)
      pos = index(rest, q)
      if (pos > 0) {
        val = substr(rest, 1, pos - 1)
        rest = substr(rest, pos + 1)
      } else {
        val = rest
        rest = ""
      }
    } else if (match(rest, /^[^ \t]+/)) {
      val = substr(rest, RSTART, RLENGTH)
      rest = substr(rest, RLENGTH + 1)
    } else {
      val = ""
      rest = ""
    }
    val = interpolate(strip_quotes(val))
    include_param_keys[++param_count] = key
    include_param_vals[param_count] = val
  }
  return param_count
}

function vars_push(count,   i, key) {
  if (count <= 0) return
  vars_depth++
  vars_frame_count[vars_depth] = count
  for (i = 1; i <= count; i++) {
    key = include_param_keys[i]
    vars_frame_keys[vars_depth, i] = key
    if (key in vars) {
      vars_frame_has[vars_depth, i] = 1
      vars_frame_prev[vars_depth, i] = vars[key]
    } else {
      vars_frame_has[vars_depth, i] = 0
      vars_frame_prev[vars_depth, i] = ""
    }
    vars[key] = include_param_vals[i]
  }
}

function vars_pop(   i, key) {
  if (vars_depth <= 0) return
  for (i = vars_frame_count[vars_depth]; i >= 1; i--) {
    key = vars_frame_keys[vars_depth, i]
    if (vars_frame_has[vars_depth, i]) {
      vars[key] = vars_frame_prev[vars_depth, i]
    } else {
      delete vars[key]
    }
  }
  vars_frame_count[vars_depth] = 0
  vars_depth--
}

function data_fail(msg) {
  print "smol: data: " msg > "/dev/stderr"
  exit 2
}

function data_debug(msg) {
  if (ENVIRON["SMOL_DEBUG_DATA"] != "") {
    print "smol: data: " msg > "/dev/stderr"
  }
}

function data_parse_row(line, name, idx,   parts, n, i, f) {
  n = split(line, parts, "|")
  if (n < 1) data_fail(name ": row " idx ": expected 1+ fields, got " n ": " line)

  data_cols[name, idx] = n
  for (i = 1; i <= n; i++) {
    f = trim(parts[i])
    data_field[name, idx, i] = f
  }
}

function data_clear(name,   idx, col, cols) {
  if (!(name in data_loaded)) return

  for (idx = 1; idx <= data_len[name]; idx++) {
    cols = data_cols[name, idx]
    for (col = 1; col <= cols; col++) {
      delete data_field[name, idx, col]
    }
    delete data_cols[name, idx]
  }

  data_len[name] = 0
  delete data_loaded[name]
}

function data_load(path, pipeline, name,   cmd, line, idx) {
  if (name == "") return
  data_clear(name)

  pipeline = trim(pipeline)
  pipeline = interpolate(pipeline)
  path = interpolate(strip_quotes(path))

  idx = 0
  if (pipeline == "") {
    cmd = "cat " sh_escape(path)
  } else {
    # awk executes commands via a shell already; keep it simple.
    cmd = "cat " sh_escape(path) " | " pipeline
  }

  data_debug("load name='" name "' path='" path "'")
  data_debug("pipeline: " pipeline)
  data_debug("cmd: " cmd)

  while ((cmd | getline line) > 0) {
    if (line ~ /^[ \t]*$/) continue
    idx++
    data_parse_row(line, name, idx)
  }
  close(cmd)

  data_debug("loaded name='" name "' rows=" idx)

  data_len[name] = idx
  data_loaded[name] = 1
}

function shell_load(file_dir, cmd, name,   full_cmd, line, idx) {
  if (name == "") return
  data_clear(name)

  cmd = trim(cmd)
  cmd = interpolate(strip_quotes(cmd))

  full_cmd = cmd
  if (file_dir != "" && file_dir != ".") {
    full_cmd = "cd " sh_escape(file_dir) " && " cmd
  }

  idx = 0
  data_debug("shell name='" name "' cmd='" full_cmd "'")

  while ((full_cmd | getline line) > 0) {
    if (line ~ /^[ \t]*$/) continue
    idx++
    data_parse_row(line, name, idx)
  }
  close(full_cmd)

  data_debug("shell loaded name='" name "' rows=" idx)

  data_len[name] = idx
  data_loaded[name] = 1
}

function parse_shell(text, indent, file_dir, line,   rest, name, cmd) {
  rest = ltrim(substr(text, length("@shell") + 1))
  if (rest == "") return 1

  if (!match(rest, /as[ \t]+[A-Za-z0-9_-]+[ \t]*$/)) {
    print "smol: @shell: missing 'as <name>'" > "/dev/stderr"
    exit 1
  }

  name = substr(rest, RSTART)
  sub(/^as[ \t]+/, "", name)
  name = trim(name)

  cmd = trim(substr(rest, 1, RSTART - 1))
  if (cmd == "") {
    print "smol: @shell: missing command" > "/dev/stderr"
    exit 1
  }

  shell_load(file_dir, cmd, name)
  return 1
}

function parse_data(text, indent, file_dir, line,   rest, path, q, pos, name, pipeline) {
  rest = ltrim(substr(text, length("@data") + 1))
  if (rest == "") return 1

  # path (quoted or bare)
  if (rest ~ /^"/ || rest ~ /^'/) {
    q = substr(rest, 1, 1)
    rest = substr(rest, 2)
    pos = index(rest, q)
    if (pos > 0) {
      path = substr(rest, 1, pos - 1)
      rest = ltrim(substr(rest, pos + 1))
    } else {
      path = rest
      rest = ""
    }
  } else {
    path = rest
    sub(/[ \t].*$/, "", path)
    rest = ltrim(substr(rest, length(path) + 1))
  }

  if (!match(rest, /as[ \t]+[A-Za-z0-9_-]+[ \t]*$/)) {
    print "smol: @data: missing 'as <name>'" > "/dev/stderr"
    exit 1
  }

  name = substr(rest, RSTART)
  sub(/^as[ \t]+/, "", name)
  name = trim(name)

  pipeline = trim(substr(rest, 1, RSTART - 1))

  if (pipeline ~ /^\|/) pipeline = trim(substr(pipeline, 2))
  else pipeline = ""

  data_load(join_path(file_dir, path), pipeline, name)
  return 1
}

function handle_directive(text, indent, file_dir, line,   rest, key, val, attrs, inc, path, prefix) {
  if (text ~ /^@vars([ \t]|$)/) {
    vars_mode = 1
    vars_indent = indent
    vars_base_indent = -1
    return 1
  }

  if (match(text, /^@layout[ \t]+/)) {
    if (rendering_layout) {
      print "smol: @layout: not allowed inside layout" > "/dev/stderr"
      exit 1
    }

    parse_layout_parts(text)
    if (layout_path == "") return 1

    if (layout_file != "" && layout_file != join_path(file_dir, layout_path)) {
      print "smol: @layout: multiple layouts" > "/dev/stderr"
      exit 1
    }

    layout_file = join_path(file_dir, layout_path)
    return 1
  }

  if (match(text, /^@data[ \t]+/)) {
    return parse_data(text, indent, file_dir, line)
  }

  if (match(text, /^@shell[ \t]+/)) {
    return parse_shell(text, indent, file_dir, line)
  }

  if (match(text, /^@for[ \t]+/)) {
    rest = ltrim(substr(text, RLENGTH + 1))
    loop_list = rest
    sub(/[ \t].*$/, "", loop_list)
    rest = ltrim(substr(rest, length(loop_list) + 1))

    loop_alias = loop_list
    if (match(rest, /^as[ \t]+/)) {
      rest = ltrim(substr(rest, RLENGTH + 1))
      loop_alias = rest
      sub(/[ \t].*$/, "", loop_alias)
    }

    for_depth++
    for_list_stack[for_depth] = loop_list
    for_alias_stack[for_depth] = loop_alias
    for_indent_stack[for_depth] = indent
    for_count_stack[for_depth] = 0
    for_phase[for_depth] = "capture"

    return 1
  }

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
    parse_include_parts(text)
    inc = include_file
    if (inc == "") return 1
    path = join_path(file_dir, inc)
    if (section_name != "") {
      prefix = sprintf("%*s", section_base_indent + indent, "")
    } else {
      prefix = substr(line, 1, indent)
    }
    param_count = parse_params(include_params)
    vars_push(param_count)
    process_file(path, prefix)
    vars_pop()
    return 1
  }

  if (match(text, /^@yield([ \t]|$)/)) {
    rest = ltrim(substr(text, length("@yield") + 1))
    if (rest == "") rest = "body"
    sub(/[ \t].*$/, "", rest)
    yield_lines(rest)
    return 1
  }

  if (match(text, /^@if([ \t]|$)/)) {
    rest = ltrim(substr(text, length("@if") + 1))
    if (rest == "") {
      print "smol: @if: missing condition" > "/dev/stderr"
      exit 1
    }

    # Condition syntax: <lhs> (==|!=) <rhs>
    # lhs can be a variable name (including dotted dataset fields like row.1).
    # rhs can be quoted or bare.
    if (!match(rest, /[ \t]+(==|!=)[ \t]+/)) {
      print "smol: @if: expected 'lhs == rhs' or 'lhs != rhs'" > "/dev/stderr"
      exit 1
    }

    lhs = trim(substr(rest, 1, RSTART - 1))
    op = substr(rest, RSTART + 1, RLENGTH - 2)
    rhs = trim(substr(rest, RSTART + RLENGTH))

    # Resolve lhs from vars if present, otherwise treat as literal.
    if (lhs in vars) lhs_val = vars[lhs]
    else lhs_val = strip_quotes(lhs)

    rhs_val = interpolate(strip_quotes(rhs))

    cond = (op == "==") ? (lhs_val == rhs_val) : (lhs_val != rhs_val)
    if (!cond) {
      skip_mode = 1
      skip_indent = indent
    }

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

function for_finish(file_dir, next_line,   depth, list, alias, indent, count, i, j, cols, col, param_count) {
  depth = for_depth
  if (depth <= 0) return

  list = for_list_stack[depth]
  alias = for_alias_stack[depth]
  indent = for_indent_stack[depth]
  count = for_count_stack[depth]

  for_phase[depth] = "replay"

  if (!(list in data_loaded)) {
    print "smol: @for: unknown dataset '" list "'" > "/dev/stderr"
    exit 1
  }

  for (i = 1; i <= data_len[list]; i++) {
    param_count = 0
    include_param_keys[++param_count] = alias ".index"
    include_param_vals[param_count] = i

    cols = data_cols[list, i]
    for (col = 1; col <= cols; col++) {
      include_param_keys[++param_count] = alias "." col
      include_param_vals[param_count] = data_field[list, i, col]
    }

    if (cols == 1) {
      include_param_keys[++param_count] = alias ".value"
      include_param_vals[param_count] = data_field[list, i, 1]
    }

    vars_push(param_count)
    for (j = 1; j <= count; j++) {
      process_line(for_lines[depth, j], file_dir)
    }
    vars_pop()

    close_to(indent + 1)
  }

  for (j = 1; j <= count; j++) delete for_lines[depth, j]

  delete for_phase[depth]
  delete for_list_stack[depth]
  delete for_alias_stack[depth]
  delete for_indent_stack[depth]
  delete for_count_stack[depth]
  for_depth--

  if (next_line != "") {
    process_line(next_line, file_dir)
  }
}

function process_line(line, file_dir,   indent, text, ch, pos, c, tag, id, classes, attrs, name, depth, inline, raw_text, raw_line, css_text, selector, prop, cols, col) {
  if (line ~ /^[ \t]*$/) return

  indent = indent_count(line)
  text = rtrim(ltrim(line))

  if (text ~ /^-#/) return

  if (skip_mode) {
    if (indent > skip_indent) return
    skip_mode = 0
    skip_indent = -1
  }

  # @for capture handled after section indentation normalization

  if (vars_mode) {
    if (indent <= vars_indent) {
      vars_mode = 0
      vars_base_indent = -1
    } else {
      if (vars_base_indent < 0) vars_base_indent = indent
      text = rtrim(ltrim(substr(line, vars_base_indent + 1)))
      if (text ~ /^-#/ || text == "") return
      set_var_line(text)
      return
    }
  }

  if (autowrap && section_name == "") {
    if (text ~ /^:head([ \t]|$)/) {
      start_section("head", indent)
      return
    }
    if (text ~ /^:body([ \t]|$)/) {
      start_section("body", indent)
      return
    }
    close_to(indent)
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
    if (for_depth > 0 && for_phase[for_depth] == "capture") {
      if (indent <= for_indent_stack[for_depth]) {
        for_finish(file_dir, "")
      } else {
        for_lines[for_depth, ++for_count_stack[for_depth]] = line
        return
      }
    }

    close_to(indent)
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
  if (ch != "%" && ch != "." && ch != "#" && text !~ /^[A-Za-z]/) {
    emit(indent_str(stack_depth) text)
    return
  }

  pos = 1
  tag = "div"
  if (ch == "%") {
    pos = 2
    tag = ""
  } else if (ch ~ /[A-Za-z]/) {
    tag = ""
  }
  if (tag == "") {
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
  if (inline ~ /^\|/) {
    inline = substr(inline, 2)
    if (inline ~ /^ /) inline = substr(inline, 2)
  }

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

function process_file(path, prefix,   line, full, prev_dir, dir, before_depth, before_css_depth, before_css_mode, before_css_base_indent) {
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

  before_depth = stack_depth
  before_css_depth = css_depth
  before_css_mode = css_mode
  before_css_base_indent = css_base_indent

  while ((getline line < path) > 0) {
    full = (prefix != "") ? prefix line : line
    process_line(full, current_dir)
  }

  while (for_depth > 0 && for_phase[for_depth] == "capture") {
    for_finish(current_dir, "")
  }

  # Flush any still-open tags/blocks opened inside this include.
  if (css_mode && !before_css_mode) {
    css_close_to_depth(0)
    emit("</style>")
    css_mode = 0
    css_base_indent = -1
    css_depth = 0
  } else {
    css_close_to_depth(before_css_depth)
    css_mode = before_css_mode
    css_base_indent = before_css_base_indent
  }

  close_to_depth(before_depth)

  close(path)
  current_dir = prev_dir
  include_stack[path] = 0
  include_depth--
}

function scan_file(path,   line, text, dir, inc, indent) {
  if (scan_stack[path]++) return
  css_scan = 0
  css_scan_indent = -1
  raw_scan = 0
  raw_scan_indent = -1
  dir = path_dir(path)
  while ((getline line < path) > 0) {
    indent = indent_count(line)
    text = rtrim(ltrim(line))
    if (text ~ /^-#/ || text == "") continue
    if (raw_scan) {
      if (indent <= raw_scan_indent) {
        raw_scan = 0
        raw_scan_indent = -1
      } else {
        continue
      }
    }
    if (css_scan) {
      if (indent <= css_scan_indent) {
        css_scan = 0
        css_scan_indent = -1
      } else {
        continue
      }
    }
    if (text ~ /^:raw$/ || text ~ /^:plain$/) {
      raw_scan = 1
      raw_scan_indent = indent
      continue
    }
    if (text ~ /^%style([ \t]|$)/ || text ~ /^style([ \t]|$)/) {
      css_scan = 1
      css_scan_indent = indent
      continue
    }
    if (match(text, /^@include[ \t]+/)) {
      inc = parse_include(text)
      if (inc != "") scan_file(join_path(dir, inc))
      continue
    }
    if (text ~ /^\|[ \t]*<!doctype/ || text ~ /^<!doctype/ || text ~ /^%html([ \t]|$)/ || text ~ /^%head([ \t]|$)/ || text ~ /^%body([ \t]|$)/ || text ~ /^html([ \t]|$)/ || text ~ /^head([ \t]|$)/ || text ~ /^body([ \t]|$)/) {
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

function yield_lines(kind,   i, prefix, count, line) {
  prefix = indent_str(stack_depth)

  if (kind == "meta") {
    if (meta_charset == "") meta_charset = "utf-8"
    if (meta_viewport == "") meta_viewport = "width=device-width, initial-scale=1"
    if (meta_lang == "") meta_lang = "en"

    emit(prefix "<meta charset=\"" meta_charset "\" />")
    if (meta_title != "") emit(prefix "<title>" meta_title "</title>")
    if (meta_description != "") emit(prefix "<meta name=\"description\" content=\"" meta_description "\" />")
    if (meta_viewport != "") emit(prefix "<meta name=\"viewport\" content=\"" meta_viewport "\" />")
    for (i = 1; i <= meta_count; i++) emit(prefix "<meta " meta_extra[i] " />")
    return
  }

  if (kind == "head") {
    count = head_count
    for (i = 1; i <= count; i++) {
      line = head_lines[i]
      emit(prefix line)
    }
    return
  }

  if (kind == "body") {
    count = body_count
    for (i = 1; i <= count; i++) {
      line = body_lines[i]
      emit(prefix line)
    }
    return
  }

  if (kind == "scripts") {
    count = script_count
    for (i = 1; i <= count; i++) {
      line = script_lines[i]
      emit(prefix line)
    }
    return
  }

  print "smol: @yield: unknown kind '" kind "'" > "/dev/stderr"
  exit 1
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
  vars_mode = 0
  vars_indent = -1
  vars_base_indent = -1
  vars_depth = 0

  for_depth = 0

  skip_mode = 0
  skip_indent = -1

  found_html = 0
  found_sections = 0
  scan_file(main_file)
  autowrap = (found_sections && !found_html)
  emit_target = "stdout"

  layout_file = ""
  rendering_layout = 0

  process_file(main_file, "")

  if (layout_file != "") {
    if (!autowrap) {
      print "smol: @layout: requires autowrap (use :head/:body)" > "/dev/stderr"
      exit 1
    }

    if (section_name != "") {
      end_section()
      section_name = ""
    }

    move_blocks()

    if (meta_lang == "") meta_lang = "en"
    if (meta_charset == "") meta_charset = "utf-8"
    if (meta_viewport == "") meta_viewport = "width=device-width, initial-scale=1"

    vars["smol.lang"] = meta_lang
    vars["smol.charset"] = meta_charset
    vars["smol.viewport"] = meta_viewport
    vars["smol.title"] = meta_title
    vars["smol.description"] = meta_description

    reset_state()
    vars_mode = 0
    vars_indent = -1
    vars_base_indent = -1
    vars_depth = 0

    for_mode = 0
    for_replaying = 0
    for_indent = -1
    for_count = 0

    rendering_layout = 1
    autowrap = 0
    emit_target = "stdout"

    process_file(layout_file, "")

    if (css_mode) {
      css_close_to(-1)
      emit(indent_str(stack_depth) "</style>")
    }
    close_to(-1)

    exit
  }

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
