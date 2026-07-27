#!/bin/sh
set -eu

root=$(CDPATH="" cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' INT TERM HUP EXIT

candidate="$tmp/life.wasm"
LC_ALL=C awk -f "$root/scripts/wasmol.awk" "$root/src/wasm/life.wasmol" >"$candidate"

if ! cmp -s "$candidate" "$root/public/life.wasm"; then
  printf '%s\n' 'wasm test: Wasmol output differs from committed life.wasm' >&2
  exit 1
fi

# Exercise the real build wrapper from a clean minimal tree.
mkdir -p "$tmp/repo/scripts" "$tmp/repo/src/wasm" "$tmp/repo/public"
cp "$root/scripts/wasmol.awk" "$root/scripts/wasm_build.sh" "$tmp/repo/scripts/"
cp "$root/src/wasm/life.wasmol" "$tmp/repo/src/wasm/"
"$tmp/repo/scripts/wasm_build.sh" >/dev/null
cmp -s "$tmp/repo/public/life.wasm" "$root/public/life.wasm" || {
  printf '%s\n' 'wasm test: clean wrapper build differs from committed life.wasm' >&2
  exit 1
}

# Unsupported or malformed language features must fail closed.
expect_fail() {
  name=$1
  shift
  printf '%s\n' "$@" >"$tmp/$name.wasmol"
  if LC_ALL=C awk -f "$root/scripts/wasmol.awk" "$tmp/$name.wasmol" >"$tmp/$name.wasm" 2>/dev/null; then
    printf 'wasm test: invalid Wasmol unexpectedly compiled: %s\n' "$name" >&2
    exit 1
  fi
}

expect_fail unknown-opcode 'func nope' '  magic.unicorn' 'endfunc'
expect_fail missing-constant 'func nope' '  i32.const' 'endfunc'
expect_fail invalid-constant 'func nope' '  i32.const nope' 'endfunc'
expect_fail extra-operand 'func nope' '  return garbage' 'endfunc'
expect_fail integer-overflow 'func nope' '  i32.const 4294967295' 'endfunc'
expect_fail bare-memory 'memory'
expect_fail multiple-memory 'memory first 1' 'memory second 1'
expect_fail invalid-global 'global nope mutable f32 0'
expect_fail duplicate-function 'func nope' 'endfunc' 'func nope' 'endfunc'
expect_fail malformed-parameter 'func nope value:i32:garbage' 'endfunc'
expect_fail malformed-local 'func nope' '  local value:i32:garbage' 'endfunc'
expect_fail duplicate-export 'memory heap 1' 'export memory heap as same' 'export memory heap as same'
expect_fail trailing-endfunc 'func nope' 'endfunc garbage'
expect_fail missing-result 'func nope -> i32' 'endfunc'
expect_fail stack-underflow 'func nope' '  i32.add' 'endfunc'
expect_fail wrong-operand-type 'func nope' '  f32.const 0' '  i32.eqz' 'endfunc'
expect_fail load-without-memory 'func nope' '  i32.const 0' '  i32.load' 'endfunc'
expect_fail extra-result 'func nope' '  i32.const 0' 'endfunc'
expect_fail branch-condition 'func nope' '  block done' '  br_if done' '  end' 'endfunc'
expect_fail global-type 'global value mutable i32 0' 'func nope' '  f32.const 0' '  global.set value' 'endfunc'
expect_fail malformed-constant 'const nope 1'
expect_fail duplicate-constant 'const nope = 1' 'const nope = 2'
expect_fail unknown-constant 'func nope' '  i32.const missing' 'endfunc'
expect_fail negative-symbolic-offset 'const bad = -1' 'memory heap 1' 'func nope -> i32' '  i32.const 0' '  i32.load offset=bad' 'endfunc'
expect_fail local-before-assignment 'func nope' '  local.get missing' 'endfunc'
expect_fail malformed-inline-local 'func nope' '  i32.const 0' '  local.set value:i32:junk' 'endfunc'
expect_fail duplicate-inline-local 'func nope' '  i32.const 0' '  local.set value:i32' '  i32.const 0' '  local.set value:i32' 'endfunc'
expect_fail wrong-inline-type 'func nope' '  i32.const 0' '  local.set value:f32' 'endfunc'
expect_fail undeclared-unreachable-local 'func nope' '  block done' '    br done' '    local.set missing' '  end' 'endfunc'

printf '%s\n' 'wasm test ok'
