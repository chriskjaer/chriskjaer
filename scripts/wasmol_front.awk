#!/usr/bin/awk -f

# High-level frontend for indentation-based Smol `@wasm` blocks.
# Lowers @ directives and expressions into the validated stack IR consumed by
# scripts/wasmol.awk.

function fatal(message) {
  print FILENAME ":" FNR ": " message | "cat 1>&2"
  close("cat 1>&2")
  failed = 1
  exit 1
}

function trim(value) {
  sub(/^[ \t\r\n]+/, "", value)
  sub(/[ \t\r\n]+$/, "", value)
  return value
}

function identifier(value) {
  return value ~ /^[A-Za-z_][A-Za-z0-9_]*$/
}

function emit(line) {
  output_lines[++output_count] = line
}

function emit_code(code,   count, lines, i) {
  if (code == "") return
  count = split(code, lines, /\n/)
  for (i = 1; i <= count; i++) if (lines[i] != "") emit(lines[i])
}

function register_module_name(name, kind) {
  if (!identifier(name)) fatal("invalid " kind " name " name)
  if (name in module_name) fatal("duplicate module name " name)
  module_name[name] = kind
}

function code_line(line) {
  return line "\n"
}

function tokenize(expression,   rest, token, i, candidate) {
  for (i = 1; i <= token_count; i++) delete tokens[i]
  token_count = 0
  token_pos = 1
  rest = expression

  while (rest != "") {
    sub(/^[ \t]+/, "", rest)
    if (rest == "") break

    token = ""
    for (i = 1; i <= operator_count; i++) {
      candidate = operators[i]
      if (substr(rest, 1, length(candidate)) == candidate) {
        token = candidate
        break
      }
    }
    if (token != "") {
      tokens[++token_count] = token
      rest = substr(rest, length(token) + 1)
      continue
    }

    if (match(rest, /^[0-9]+\.[0-9]+/)) {
      token = substr(rest, 1, RLENGTH)
    } else if (match(rest, /^[0-9]+/)) {
      token = substr(rest, 1, RLENGTH)
    } else if (match(rest, /^[A-Za-z_][A-Za-z0-9_]*/)) {
      token = substr(rest, 1, RLENGTH)
    } else if (match(rest, /^[(),+\-*\[\]]/)) {
      token = substr(rest, 1, 1)
    } else {
      fatal("cannot tokenize expression near " rest)
    }
    tokens[++token_count] = token
    rest = substr(rest, length(token) + 1)
  }
}

function peek() {
  return token_pos <= token_count ? tokens[token_pos] : ""
}

function take(   token) {
  token = peek()
  if (token == "") fatal("unexpected end of expression")
  token_pos++
  return token
}

function expect(expected,   actual) {
  actual = take()
  if (actual != expected) fatal("expected " expected " but found " actual)
}

function precedence(op) {
  if (op == "or") return 1
  if (op == "and") return 2
  if (op ~ /^(==|!=|<u|>u|<=u|<f|>f)$/) return 3
  if (op ~ /^(\+|-|>>s)$/) return 4
  if (op ~ /^(\*|\*f|%s)$/) return 5
  return 0
}

function binary_opcode(op) {
  if (op == "or") return "i32.or"
  if (op == "and") return "i32.and"
  if (op == "==") return "i32.eq"
  if (op == "!=") return "i32.ne"
  if (op == "<u") return "i32.lt_u"
  if (op == ">u") return "i32.gt_u"
  if (op == "<=u") return "i32.le_u"
  if (op == "<f") return "f32.lt"
  if (op == ">f") return "f32.gt"
  if (op == "+") return "i32.add"
  if (op == "-") return "i32.sub"
  if (op == "*") return "i32.mul"
  if (op == "*f") return "f32.mul"
  if (op == "%s") return "i32.rem_s"
  if (op == ">>s") return "i32.shr_s"
  fatal("unsupported expression operator " op)
}

function parse_expression(minimum,   left, op, level, right) {
  left = parse_primary()
  while ((op = peek()) != "" && (level = precedence(op)) >= minimum) {
    take()
    right = parse_expression(level + 1)
    left = left right code_line(binary_opcode(op))
  }
  return left
}

function parse_call(name,   first, second, third, temp) {
  expect("(")

  first = parse_expression(1)
  if (name == "u32") {
    expect(")")
    return first code_line("i32.trunc_sat_f32_u")
  }

  expect(",")
  second = parse_expression(1)
  if (name == "max_u") {
    expect(")")
    return first second first second code_line("i32.gt_u") code_line("select")
  }
  if (name == "wrap") {
    expect(")")
    temp = "__wrap" ++hidden_count
    return second code_line("i32.const 0") first second code_line("i32.rem_s") \
      code_line("local.tee " temp ":i32") code_line("i32.const i32_min") \
      code_line("i32.gt_u") code_line("select") code_line("local.get " temp) \
      code_line("i32.add") code_line("local.tee " temp) code_line("i32.const 31") \
      code_line("i32.shr_s") second code_line("i32.and") code_line("local.get " temp) \
      code_line("i32.add")
  }

  expect(",")
  third = parse_expression(1)
  expect(")")
  if (name == "choose") return second third first code_line("select")
  fatal("unknown expression function " name)
}

function parse_primary(   token, inner, name, index_code) {
  token = take()

  if (token == "-") {
    inner = parse_primary()
    return code_line("i32.const 0") inner code_line("i32.sub")
  }
  if (token == "(") {
    inner = parse_expression(1)
    expect(")")
    return inner
  }
  if (token ~ /^[0-9]+\.[0-9]+$/) {
    if (token != "0.0" && token != "1.0") fatal("only 0.0 and 1.0 float literals are supported")
    sub(/\.0$/, "", token)
    return code_line("f32.const " token)
  }
  if (token ~ /^[0-9]+$/) return code_line("i32.const " token)
  if (!identifier(token)) fatal("invalid expression token " token)

  name = token
  if (peek() == "(") return parse_call(name)
  if (peek() == "[") {
    if (!(name in array_address)) fatal("unknown array " name)
    take()
    index_code = parse_expression(1)
    expect("]")
    return index_code code_line("i32.const " array_address[name]) code_line("i32.add") code_line("i32.load8_u")
  }
  if (name in state_address) return code_line("i32.const 0") code_line("i32.load offset=" state_address[name])
  if (name in constant_known) return code_line(constant_type[name] ".const " name)
  return code_line("local.get " name)
}

function expression_code(expression,   code) {
  tokenize(trim(expression))
  if (token_count == 0) fatal("empty expression")
  code = parse_expression(1)
  if (peek() != "") fatal("unexpected expression token " peek())
  return code
}

function split_assignment(text,   position) {
  position = index(text, "=")
  if (position == 0) fatal("assignment needs =")
  assignment_left = trim(substr(text, 1, position - 1))
  assignment_right = trim(substr(text, position + 1))
  if (assignment_left == "" || assignment_right == "") fatal("incomplete assignment")
}

function emit_assignment(target, expression, declare,   name, inside, open, close_at, address, local_name) {
  if (match(target, /^[A-Za-z_][A-Za-z0-9_]*\[/)) {
    name = substr(target, 1, index(target, "[") - 1)
    if (!(name in array_address)) fatal("unknown assignment array " name)
    open = index(target, "[")
    close_at = length(target)
    if (substr(target, close_at, 1) != "]") fatal("malformed array assignment")
    inside = substr(target, open + 1, close_at - open - 1)
    emit_code(expression_code(inside))
    emit("i32.const " array_address[name])
    emit("i32.add")
    emit_code(expression_code(expression))
    emit("i32.store8")
  } else if (target in state_address) {
    emit("i32.const 0")
    emit_code(expression_code(expression))
    emit("i32.store offset=" state_address[target])
  } else {
    if (declare && target !~ /^[A-Za-z_][A-Za-z0-9_]*:(i32|f32)$/) fatal("@let needs name:type")
    if (!declare && !identifier(target)) fatal("invalid assignment target " target)
    if (declare) {
      local_name = target
      sub(/:.*/, "", local_name)
      if (local_name in module_name) fatal("local shadows module name " local_name)
      if (local_name in frontend_local) fatal("duplicate local " local_name)
      frontend_local[local_name] = 1
    }
    emit_code(expression_code(expression))
    emit("local.set " target)
  }
}

function push_scope(kind, indent, label, variable) {
  scope_depth++
  scope_kind[scope_depth] = kind
  scope_indent[scope_depth] = indent
  scope_label[scope_depth] = label
  scope_variable[scope_depth] = variable

}

function close_one_scope(   kind, label, variable) {
  kind = scope_kind[scope_depth]
  label = scope_label[scope_depth]
  variable = scope_variable[scope_depth]

  if (kind == "for") {
    emit("local.get " variable)
    emit("i32.const 1")
    emit("i32.add")
    emit("local.set " variable)
    emit("br " label "_loop")
    emit("end")
    emit("end")
  } else if (kind == "while") {
    emit("br " label "_loop")
    emit("end")
    emit("end")
  } else if (kind == "func") {
    if (scope_label[scope_depth] != "") emit("end")
    emit("endfunc")
    current_function = ""
    current_return_label = ""
    current_result = ""
  } else {
    fatal("unknown frontend scope " kind)
  }

  delete scope_kind[scope_depth]
  delete scope_indent[scope_depth]
  delete scope_label[scope_depth]
  delete scope_variable[scope_depth]

  scope_depth--
}

function close_scopes(indent) {
  while (scope_depth > 0 && indent <= scope_indent[scope_depth]) close_one_scope()
}

function start_function(text, indent,   name, result, pieces, count, i, parameter, exported) {
  if (indent != 0) fatal("functions must be top-level")
  current_function = text
  sub(/^@func[ \t]+/, "", current_function)
  if (current_function == "") fatal("missing function declaration")
  exported = 0
  if (current_function ~ /[ \t]+export$/) {
    sub(/[ \t]+export$/, "", current_function)
    exported = 1
  }

  current_result = ""
  for (parameter in frontend_local) delete frontend_local[parameter]
  count = split(current_function, pieces, /[ \t]+/)
  register_module_name(pieces[1], "function")
  for (i = 2; i <= count; i++) {
    if (pieces[i] == "->") {
      current_result = pieces[i + 1]
      break
    }
    if (pieces[i] !~ /^[A-Za-z_][A-Za-z0-9_]*:(i32|f32)$/) fatal("invalid function parameter " pieces[i])
    parameter = pieces[i]
    sub(/:.*/, "", parameter)
    if (parameter in module_name) fatal("parameter shadows module name " parameter)
    if (parameter in frontend_local) fatal("duplicate parameter " parameter)
    frontend_local[parameter] = 1
  }
  if (exported) emit("export func " pieces[1])
  emit("func " current_function)

  current_return_label = ""
  if (current_result == "") {
    current_return_label = "__return" ++label_count
    emit("block " current_return_label)
  }
  push_scope("func", indent, current_return_label, "")
}

function start_for(text, indent,   rest, variable, in_at, range_at, start_expression, end_expression, label) {
  rest = text
  sub(/^@for[ \t]+/, "", rest)
  in_at = index(rest, " in ")
  if (in_at == 0) fatal("@for needs 'in'")
  variable = trim(substr(rest, 1, in_at - 1))
  rest = substr(rest, in_at + 4)
  range_at = index(rest, " .. ")
  if (!identifier(variable) || range_at == 0) fatal("@for needs name in start .. end")
  if (variable in frontend_local || variable in module_name) fatal("duplicate loop local " variable)
  frontend_local[variable] = 1
  start_expression = trim(substr(rest, 1, range_at - 1))
  end_expression = trim(substr(rest, range_at + 4))

  emit_code(expression_code(start_expression))
  emit("local.set " variable ":i32")
  label = "__for" ++label_count
  emit("block " label "_done")
  emit("loop " label "_loop")
  emit("local.get " variable)
  emit_code(expression_code(end_expression))
  emit("i32.lt_s")
  emit("i32.eqz")
  emit("br_if " label "_done")
  push_scope("for", indent, label, variable)
}

function start_while(text, indent,   expression, label) {
  expression = text
  sub(/^@while[ \t]+/, "", expression)
  if (expression == "") fatal("@while needs a condition")
  label = "__while" ++label_count
  emit("block " label "_done")
  emit("loop " label "_loop")
  emit_code(expression_code(expression))
  emit("i32.eqz")
  emit("br_if " label "_done")
  push_scope("while", indent, label, "")
}

function handle_directive(text, indent,   rest, name, value, count, fields, expression, i, constant_name, type) {
  if (text ~ /^@const[ \t]+/) {
    rest = text
    sub(/^@const[ \t]+/, "", rest)
    count = split(rest, fields, /[ \t]+/)
    constant_name = fields[1]
    type = "i32"
    if (constant_name ~ /:/) {
      type = constant_name
      sub(/^.*:/, "", type)
      sub(/:.*/, "", constant_name)
    }
    if (count != 2 || !identifier(constant_name) || type !~ /^(i32|f32)$/ || fields[2] !~ /^-?[0-9]+$/) fatal("invalid @const")
    register_module_name(constant_name, "constant")
    constant_known[constant_name] = 1
    constant_type[constant_name] = type
    emit("const " constant_name " = " fields[2])
  } else if (text ~ /^@memory[ \t]+/) {
    rest = text
    sub(/^@memory[ \t]+/, "", rest)
    if (rest == "") fatal("invalid @memory")
    register_module_name("memory", "memory")
    emit("memory memory " rest)
    memory_block = 1
    memory_block_indent = indent
  } else if (text ~ /^@state[ \t]+/) {
    rest = text
    sub(/^@state[ \t]+/, "", rest)
    count = split(rest, fields, /[ \t]+/)
    if (count != 3 || fields[2] != "at" || !identifier(fields[1]) || !identifier(fields[3])) fatal("invalid @state")
    register_module_name(fields[1], "state")
    if (!(fields[3] in constant_known) || constant_type[fields[3]] != "i32") fatal("unknown or non-i32 state address " fields[3])
    state_address[fields[1]] = fields[3]
  } else if (text ~ /^@array[ \t]+/) {
    rest = text
    sub(/^@array[ \t]+/, "", rest)
    count = split(rest, fields, /[ \t]+/)
    if (count != 3 || fields[2] != "at" || !identifier(fields[1]) || !identifier(fields[3])) fatal("invalid @array")
    register_module_name(fields[1], "array")
    if (!(fields[3] in constant_known) || constant_type[fields[3]] != "i32") fatal("unknown or non-i32 array address " fields[3])
    array_address[fields[1]] = fields[3]
  } else if (text ~ /^@export[ \t]+/) {
    rest = text
    sub(/^@export[ \t]+/, "", rest)
    count = split(rest, fields, /[ \t]+/)
    for (i = 1; i <= count; i++) emit("export " (fields[i] == "memory" ? "memory" : "func") " " fields[i])
  } else if (text ~ /^@func[ \t]+/) {
    start_function(text, indent)
  } else if (text ~ /^@let[ \t]+/) {
    rest = text
    sub(/^@let[ \t]+/, "", rest)
    split_assignment(rest)
    emit_assignment(assignment_left, assignment_right, 1)
  } else if (text ~ /^@set[ \t]+/) {
    rest = text
    sub(/^@set[ \t]+/, "", rest)
    split_assignment(rest)
    emit_assignment(assignment_left, assignment_right, 0)
  } else if (text ~ /^@return[ \t]+if[ \t]+/) {
    if (current_return_label == "") fatal("conditional return is only supported in void functions")
    expression = text
    sub(/^@return[ \t]+if[ \t]+/, "", expression)
    emit_code(expression_code(expression))
    emit("br_if " current_return_label)
  } else if (text == "@return") {
    if (current_return_label == "") fatal("value-returning function needs @return expression")
    emit("br " current_return_label)
  } else if (text ~ /^@return[ \t]+/) {
    if (current_result == "") fatal("void return cannot have a value")
    expression = text
    sub(/^@return[ \t]+/, "", expression)
    emit_code(expression_code(expression))
    emit("return")
  } else if (text ~ /^@for[ \t]+/) {
    start_for(text, indent)
  } else if (text ~ /^@while[ \t]+/) {
    start_while(text, indent)
  } else {
    fatal("unknown Wasmol directive " text)
  }
}

BEGIN {
  operator_count = 0
  operators[++operator_count] = "<=u"
  operators[++operator_count] = ">>s"
  operators[++operator_count] = "=="
  operators[++operator_count] = "!="
  operators[++operator_count] = "<u"
  operators[++operator_count] = ">u"
  operators[++operator_count] = "<f"
  operators[++operator_count] = ">f"
  operators[++operator_count] = "*f"
  operators[++operator_count] = "%s"
}

{
  raw = $0
  if (raw ~ /\t/) fatal("tabs are not allowed")
  if (raw ~ /^[ ]*$/) next
  match(raw, /^ */)
  indent = RLENGTH
  if (indent % 2 != 0) fatal("indentation must use two-space steps")
  text = trim(raw)
  if (text ~ /^#/) next

  if (constant_block) {
    if (indent <= constant_block_indent) {
      constant_block = 0
    } else {
      if (indent != constant_block_indent + 2) fatal("@vars entries use one indentation step")
      text = "@const " text
      indent = 0
    }
  }
  if (!constant_block && text == "@vars") {
    if (indent != 0 || functions_started) fatal("@vars must precede functions at top level")
    constant_block = 1
    constant_block_indent = indent
    next
  }

  if (memory_block) {
    if (indent <= memory_block_indent) {
      memory_block = 0
    } else {
      if (indent != memory_block_indent + 2 || text !~ /^@(state|array)[ \t]+/) fatal("@memory may only contain @state and @array")
      indent = 0
    }
  }

  close_scopes(indent)
  top_level = (text ~ /^@(const|memory|state|array|export|func)([ \t]|$)/)
  if (top_level) {
    if (indent != 0) fatal("module declarations must be top-level")
    if (text ~ /^@func([ \t]|$)/) {
      functions_started = 1
    } else if (functions_started) {
      fatal("module declarations must precede functions")
    }
  } else {
    if (current_function == "") fatal("statement outside function")
    if (indent != scope_indent[scope_depth] + 2) fatal("unexpected indentation")
  }
  handle_directive(text, indent)
}

END {
  if (failed) exit 1
  close_scopes(-1)
  if (failed) exit 1
  for (output_index = 1; output_index <= output_count; output_index++) print output_lines[output_index]
}
