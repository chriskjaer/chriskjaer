#!/usr/bin/awk -f

# Wasmol: a deliberately tiny WebAssembly compiler.
# It implements only the declarations and opcodes used by src/wasm/life.wasmol.

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

function is_identifier(value) {
  return value ~ /^[A-Za-z_][A-Za-z0-9_]*$/
}

function byte_hex(value) {
  return sprintf("%02x", value)
}

function type_code(type) {
  if (type == "i32") return "7f"
  if (type == "f32") return "7d"
  fatal("unsupported type " type)
}

function uleb(value,   byte, encoded) {
  encoded = ""
  do {
    byte = value % 128
    value = int(value / 128)
    if (value > 0) byte += 128
    encoded = encoded byte_hex(byte)
  } while (value > 0)
  return encoded
}

function sleb(value,   byte, done, encoded, next_value, remainder, sign_set) {
  encoded = ""
  do {
    remainder = value % 128
    if (remainder < 0) remainder += 128
    byte = remainder
    next_value = int(value / 128)
    if (value < 0 && value % 128 != 0) next_value--
    sign_set = byte >= 64
    done = (next_value == 0 && !sign_set) || (next_value == -1 && sign_set)
    if (!done) byte += 128
    encoded = encoded byte_hex(byte)
    value = next_value
  } while (!done)
  return encoded
}

function ascii_hex(value,   encoded, i, char) {
  encoded = ""
  for (i = 1; i <= length(value); i++) {
    char = substr(value, i, 1)
    if (!(char in ascii)) fatal("non-ASCII name " value)
    encoded = encoded byte_hex(ascii[char])
  }
  return encoded
}

function wasm_string(value) {
  return uleb(length(value)) ascii_hex(value)
}

function emit_byte(value) {
  printf "%c", value
}

function emit_hex(hex,   i) {
  for (i = 1; i <= length(hex); i += 2) {
    emit_byte((hex_value(substr(hex, i, 1)) * 16) + hex_value(substr(hex, i + 1, 1)))
  }
}

function hex_value(digit) {
  digit = tolower(digit)
  if (digit >= "0" && digit <= "9") return digit + 0
  return index("abcdef", digit) + 9
}

function section(id, payload) {
  emit_hex(byte_hex(id) uleb(length(payload) / 2) payload)
}

function add_type(signature, params, result,   code, i, key) {
  key = signature
  if (key in type_index) return type_index[key]
  type_index[key] = type_count
  code = "60" uleb(params)
  for (i = 1; i <= params; i++) code = code signature_param[key, i]
  if (result == "") code = code "00"
  else code = code "01" type_code(result)
  type_body[type_count] = code
  return type_count++
}

function local_index(name,   key) {
  key = current_func SUBSEP name
  if (!(key in locals)) fatal("unknown local " name)
  return locals[key]
}

function declare_local(name, type,   key, item_index) {
  if (!is_identifier(name)) fatal("invalid inline local " name)
  key = current_func SUBSEP name
  if (key in locals) fatal("duplicate local " name)
  function_locals[current_func]++
  item_index = function_params[current_func] + function_locals[current_func] - 1
  locals[key] = item_index
  local_type[key] = type
  function_local_type[current_func, function_locals[current_func]] = type
  return item_index
}

function push_value(type) {
  value_type[++value_height] = type
}

function pop_value(expected, context,   actual) {
  if (value_height == control_height[control_depth] && control_unreachable[control_depth]) return expected == "" ? "*" : expected
  if (value_height <= control_height[control_depth]) fatal("operand stack underflow at " context)
  actual = value_type[value_height]
  delete value_type[value_height--]
  if (expected != "" && actual != expected) fatal(context " expected " expected " but found " actual)
  return actual
}

function mark_unreachable() {
  while (value_height > control_height[control_depth]) delete value_type[value_height--]
  control_unreachable[control_depth] = 1
}

function push_control(label) {
  if (!is_identifier(label)) fatal("control block needs a valid label")
  control_depth++
  control_label[control_depth] = label
  control_height[control_depth] = value_height
  control_unreachable[control_depth] = 0
}

function pop_control() {
  if (control_depth == 0) fatal("end without block or loop")
  if (!control_unreachable[control_depth] && value_height != control_height[control_depth]) fatal("control block leaves values on the stack")
  while (value_height > control_height[control_depth]) delete value_type[value_height--]
  delete control_label[control_depth]
  delete control_height[control_depth]
  delete control_unreachable[control_depth]
  control_depth--
}

function branch_depth(label,   i) {
  for (i = control_depth; i >= 1; i--) {
    if (control_label[i] == label) return control_depth - i
  }
  fatal("unknown branch label " label)
}

function append(code) {
  function_code[current_func] = function_code[current_func] code
}

function memory_instruction(op, argument,   offset) {
  offset = 0
  if (argument != "") {
    if (argument !~ /^offset=[A-Za-z_][A-Za-z0-9_]*$/ && argument !~ /^offset=[0-9]+$/) fatal("invalid memory argument " argument)
    sub(/^offset=/, "", argument)
    if (is_identifier(argument)) {
      if (!(argument in constant_value)) fatal("unknown constant " argument)
      argument = constant_value[argument]
    }
    offset = argument + 0
    if (offset < 0 || offset > 4294967295) fatal("memory offset is out of range")
  }
  if (op == "i32.load") return "28" "02" uleb(offset)
  if (op == "i32.load8_u") return "2d" "00" uleb(offset)
  if (op == "i32.store") return "36" "02" uleb(offset)
  if (op == "i32.store8") return "3a" "00" uleb(offset)
  fatal("unsupported memory instruction " op)
}

function float32(value) {
  if (value == "0" || value == "0x0p+0") return "00000000"
  if (value == "1" || value == "0x1p+0") return "0000803f"
  if (value == "4294967296" || value == "0x1p+32") return "0000804f"
  fatal("unsupported f32 constant " value)
}

function compile_instruction(line,   argument, count, fields, op, item_index, item_type, left_type, right_type, value) {
  count = split(line, fields, /[ \t]+/)
  op = fields[1]
  argument = count > 1 ? fields[2] : ""

  if (op == "block" || op == "loop") {
    if (count != 2) fatal(op " expects one label")
    push_control(argument)
    append((op == "block" ? "02" : "03") "40")
  } else if (op == "end") {
    if (count != 1) fatal("end takes no operands")
    append("0b")
    pop_control()
  } else if (op == "br" || op == "br_if") {
    if (count != 2) fatal(op " expects one label")
    if (op == "br_if") pop_value("i32", op)
    append((op == "br" ? "0c" : "0d") uleb(branch_depth(argument)))
    if (op == "br") mark_unreachable()
  } else if (op == "local.get" || op == "local.set" || op == "local.tee") {
    if (count != 2) fatal(op " expects one local")
    if (argument ~ /:/) {
      if (op == "local.get" || argument !~ /^[A-Za-z_][A-Za-z0-9_]*:(i32|f32)$/) fatal("invalid inline local " argument)
      split(argument, inline_local, ":")
      item_type = inline_local[2]
      item_index = declare_local(inline_local[1], item_type)
      pop_value(item_type, op)
      if (op == "local.tee") push_value(item_type)
    } else {
      item_index = local_index(argument)
      item_type = local_type[current_func SUBSEP argument]
      if (op == "local.get") push_value(item_type)
      else {
        pop_value(item_type, op)
        if (op == "local.tee") push_value(item_type)
      }
    }
    append((op == "local.get" ? "20" : op == "local.set" ? "21" : "22") uleb(item_index))
  } else if (op == "global.get" || op == "global.set") {
    if (count != 2) fatal(op " expects one global")
    if (!(argument in global_index)) fatal("unknown global " argument)
    if (op == "global.get") push_value(global_name_type[argument])
    else pop_value(global_name_type[argument], op)
    append((op == "global.get" ? "23" : "24") uleb(global_index[argument]))
  } else if (op == "i32.const") {
    if (count != 2) fatal("i32.const expects one value")
    value = argument
    if (is_identifier(value)) {
      if (!(value in constant_value)) fatal("unknown constant " value)
      value = constant_value[value]
    }
    if (value !~ /^-?[0-9]+$/) fatal("invalid i32 constant " argument)
    if (value + 0 < -2147483648 || value + 0 > 2147483647) fatal("i32 constant is out of range")
    push_value("i32")
    append("41" sleb(value + 0))
  } else if (op == "f32.const") {
    if (count != 2) fatal("f32.const expects one value")
    value = argument
    if (is_identifier(value)) {
      if (!(value in constant_value)) fatal("unknown constant " value)
      value = constant_value[value]
    }
    push_value("f32")
    append("43" float32(value))
  } else if (op ~ /^i32\.(load|load8_u|store|store8)$/) {
    if (count > 2) fatal(op " expects at most one offset")
    if (memory_count == 0) fatal(op " requires memory")
    if (op == "i32.load" || op == "i32.load8_u") {
      pop_value("i32", op)
      push_value("i32")
    } else {
      pop_value("i32", op)
      pop_value("i32", op)
    }
    append(memory_instruction(op, argument))
  } else if (op == "select") {
    if (count != 1) fatal("select takes no operands")
    pop_value("i32", op)
    right_type = pop_value("", op)
    left_type = pop_value("", op)
    if (left_type != "*" && right_type != "*" && left_type != right_type) fatal("select operands have different types")
    push_value(left_type != "*" ? left_type : right_type != "*" ? right_type : "i32")
    append(opcode[op])
  } else if (op == "return") {
    if (count != 1) fatal("return takes no operands")
    if (function_result[current_func] != "") pop_value(function_result[current_func], op)
    append(opcode[op])
    mark_unreachable()
  } else if (op in opcode) {
    if (count != 1) fatal(op " takes no operands")
    if (op == "i32.eqz") {
      pop_value("i32", op)
      push_value("i32")
    } else if (op ~ /^i32\.(eq|ne|lt_u|gt_u|le_u)$/) {
      pop_value("i32", op); pop_value("i32", op); push_value("i32")
    } else if (op ~ /^f32\.(lt|gt)$/) {
      pop_value("f32", op); pop_value("f32", op); push_value("i32")
    } else if (op ~ /^i32\.(add|sub|mul|rem_s|and|shr_s)$/) {
      pop_value("i32", op); pop_value("i32", op); push_value("i32")
    } else if (op == "f32.mul") {
      pop_value("f32", op); pop_value("f32", op); push_value("f32")
    } else if (op == "i32.trunc_sat_f32_u") {
      pop_value("f32", op); push_value("i32")
    }
    append(opcode[op])
  } else {
    fatal("unsupported instruction " op)
  }
}

BEGIN {
  type_count = 0
  function_count = 0
  memory_count = 0
  global_count = 0
  export_count = 0

  for (i = 0; i < 128; i++) ascii[sprintf("%c", i)] = i

  opcode["return"] = "0f"
  opcode["select"] = "1b"
  opcode["i32.eqz"] = "45"
  opcode["i32.eq"] = "46"
  opcode["i32.ne"] = "47"
  opcode["i32.lt_u"] = "49"
  opcode["i32.gt_u"] = "4b"
  opcode["i32.le_u"] = "4d"
  opcode["f32.lt"] = "5d"
  opcode["f32.gt"] = "5e"
  opcode["i32.add"] = "6a"
  opcode["i32.sub"] = "6b"
  opcode["i32.mul"] = "6c"
  opcode["i32.rem_s"] = "6f"
  opcode["i32.and"] = "71"
  opcode["i32.shr_s"] = "75"
  opcode["f32.mul"] = "94"
  opcode["i32.trunc_sat_f32_u"] = "fc01"
}

{
  line = $0
  sub(/[ \t]*#.*/, "", line)
  line = trim(line)
  if (line == "") next

  field_count = split(line, field, /[ \t]+/)

  if (field[1] == "memory") {
    if (current_func != "") fatal("memory declaration inside function")
    declaration_value = field[3]
    if (is_identifier(declaration_value)) {
      if (!(declaration_value in constant_value)) fatal("unknown constant " declaration_value)
      declaration_value = constant_value[declaration_value]
    }
    if (field_count != 3 || !is_identifier(field[2]) || declaration_value !~ /^[0-9]+$/ || declaration_value + 0 > 65536) fatal("invalid memory declaration")
    if (memory_count != 0) fatal("Wasmol supports exactly one memory")
    if (field[2] in memory_index) fatal("duplicate memory " field[2])
    memory_count++
    memory_name[memory_count] = field[2]
    memory_pages[memory_count] = declaration_value + 0
    memory_index[field[2]] = memory_count - 1
  } else if (field[1] == "global") {
    if (current_func != "") fatal("global declaration inside function")
    if (field_count != 5 || !is_identifier(field[2]) || field[3] != "mutable" || field[4] != "i32" || field[5] !~ /^-?[0-9]+$/) fatal("invalid global declaration")
    if (field[5] + 0 < -2147483648 || field[5] + 0 > 2147483647) fatal("global initializer is out of range")
    if (field[2] in global_index) fatal("duplicate global " field[2])
    global_count++
    global_name[global_count] = field[2]
    global_mutable[global_count] = field[3] == "mutable"
    global_type[global_count] = field[4]
    global_name_type[field[2]] = field[4]
    global_value[global_count] = field[5] + 0
    global_index[field[2]] = global_count - 1
  } else if (field[1] == "const") {
    if (current_func != "") fatal("constant declaration inside function")
    if (field_count != 4 || !is_identifier(field[2]) || field[3] != "=" || field[4] !~ /^-?[0-9]+$/) fatal("invalid constant declaration")
    if (field[2] in constant_value) fatal("duplicate constant " field[2])
    constant_value[field[2]] = field[4]
  } else if (field[1] == "export") {
    if (current_func != "") fatal("export declaration inside function")
    if ((field_count != 3 && !(field_count == 5 && field[4] == "as")) || !is_identifier(field[3])) fatal("invalid export declaration")
    export_count++
    export_kind[export_count] = field[2]
    export_target[export_count] = field[3]
    export_name[export_count] = field_count >= 5 && field[4] == "as" ? field[5] : field[3]
    if (!is_identifier(export_name[export_count])) fatal("invalid export name " export_name[export_count])
    if (export_name[export_count] in exported_name) fatal("duplicate export name " export_name[export_count])
    exported_name[export_name[export_count]] = 1
  } else if (field[1] == "func") {
    if (current_func != "") fatal("nested function")
    if (field_count < 2 || !is_identifier(field[2]) || (field[2] in function_index)) fatal("invalid or duplicate function")
    current_func = field[2]
    function_count++
    function_name[function_count] = current_func
    function_index[current_func] = function_count - 1
    parameter_count = 0
    result_type = ""
    signature = ""
    for (i = 3; i <= field_count; i++) {
      if (field[i] == "->") {
        if (i != field_count - 1) fatal("result type must end function declaration")
        result_type = field[++i]
      } else {
        if (field[i] !~ /^[A-Za-z_][A-Za-z0-9_]*:(i32|f32)$/) fatal("invalid parameter " field[i])
        split(field[i], part, ":")
        if (part[1] == "" || part[2] == "") fatal("invalid parameter " field[i])
        if ((current_func SUBSEP part[1]) in locals) fatal("duplicate parameter " part[1])
        parameter_count++
        locals[current_func SUBSEP part[1]] = parameter_count - 1
        local_type[current_func SUBSEP part[1]] = part[2]
        signature = signature (parameter_count == 1 ? "" : ",") part[2]
      }
    }
    signature_key = signature "->" result_type
    p = 0
    for (i = 3; i <= field_count && field[i] != "->"; i++) {
      split(field[i], part, ":")
      signature_param[signature_key, ++p] = type_code(part[2])
    }
    function_type[function_count] = add_type(signature_key, parameter_count, result_type)
    function_params[current_func] = parameter_count
    function_result[current_func] = result_type
    function_code[current_func] = ""
    function_locals[current_func] = 0
    control_depth = 0
    value_height = 0
    control_height[0] = 0
    control_unreachable[0] = 0
  } else if (field[1] == "local") {
    if (current_func == "") fatal("local outside function")
    if (field_count != 2) fatal("local expects one declaration")
    if (field[2] !~ /^[A-Za-z_][A-Za-z0-9_]*:(i32|f32)$/) fatal("invalid local " field[2])
    split(field[2], part, ":")
    if (part[1] == "" || part[2] == "") fatal("invalid local " field[2])
    if ((current_func SUBSEP part[1]) in locals) fatal("duplicate local " part[1])
    function_locals[current_func]++
    item_index = function_params[current_func] + function_locals[current_func] - 1
    locals[current_func SUBSEP part[1]] = item_index
    local_type[current_func SUBSEP part[1]] = part[2]
    function_local_type[current_func, function_locals[current_func]] = part[2]
  } else if (field[1] == "endfunc") {
    if (current_func == "") fatal("endfunc outside function")
    if (field_count != 1) fatal("endfunc takes no operands")
    if (control_depth != 0) fatal("unclosed control block")
    if (!control_unreachable[0]) {
      if (function_result[current_func] != "") pop_value(function_result[current_func], "function result")
      if (value_height != 0) fatal("function leaves values on the stack")
    }
    append("0b")
    current_func = ""
  } else {
    if (current_func == "") fatal("instruction outside function")
    compile_instruction(line)
  }
}

END {
  if (failed) exit 1
  if (current_func != "") fatal("unclosed function " current_func)

  type_payload = uleb(type_count)
  for (i = 0; i < type_count; i++) type_payload = type_payload type_body[i]

  function_payload = uleb(function_count)
  for (i = 1; i <= function_count; i++) function_payload = function_payload uleb(function_type[i])

  memory_payload = uleb(memory_count)
  for (i = 1; i <= memory_count; i++) memory_payload = memory_payload "00" uleb(memory_pages[i])

  global_payload = uleb(global_count)
  for (i = 1; i <= global_count; i++) {
    global_payload = global_payload type_code(global_type[i]) (global_mutable[i] ? "01" : "00") "41" sleb(global_value[i]) "0b"
  }

  export_payload = uleb(export_count)
  for (i = 1; i <= export_count; i++) {
    kind = export_kind[i]
    target = export_target[i]
    if (kind == "func") {
      if (!(target in function_index)) fatal("unknown function export " target)
      item_index = function_index[target]
    } else if (kind == "memory") {
      if (!(target in memory_index)) fatal("unknown memory export " target)
      item_index = memory_index[target]
    } else if (kind == "global") {
      if (!(target in global_index)) fatal("unknown global export " target)
      item_index = global_index[target]
    } else {
      fatal("unsupported export kind " kind)
    }
    export_payload = export_payload wasm_string(export_name[i]) (kind == "func" ? "00" : kind == "memory" ? "02" : "03") uleb(item_index)
  }

  code_payload = uleb(function_count)
  for (i = 1; i <= function_count; i++) {
    name = function_name[i]
    local_count = function_locals[name]
    for (j = 2; j <= local_count; j++) {
      if (function_local_type[name, j] != function_local_type[name, 1]) fatal("mixed local types are not supported")
    }
    locals_hex = local_count ? "01" uleb(local_count) type_code(function_local_type[name, 1]) : "00"
    body = locals_hex function_code[name]
    code_payload = code_payload uleb(length(body) / 2) body
  }

  emit_hex("0061736d01000000")
  section(1, type_payload)
  section(3, function_payload)
  if (memory_count) section(5, memory_payload)
  if (global_count) section(6, global_payload)
  if (export_count) section(7, export_payload)
  section(10, code_payload)
}
