#!/bin/sh
set -eu

root=$(CDPATH="" cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' INT TERM HUP EXIT

candidate="$tmp/life.wasm"
ir="$tmp/life.ir.wasmol"
sources="$tmp/sources"
mkdir -p "$sources"
LC_ALL=C awk -v wasm_source_dir="$sources" -f "$root/scripts/smol.awk" "$root/src/index.smol" >"$tmp/index.html"
LC_ALL=C awk -f "$root/scripts/wasmol_front.awk" "$sources/life.wasmol" >"$ir"
LC_ALL=C awk -f "$root/scripts/wasmol.awk" "$ir" >"$candidate"

if ! cmp -s "$candidate" "$root/public/life.wasm"; then
  printf '%s\n' 'wasm test: embedded module differs from committed life.wasm' >&2
  exit 1
fi

# Snake's embedded sidecar is the deterministic source of gameplay truth. Test
# the compiled module itself rather than reimplementing movement rules in JS.
snake_sources="$tmp/snake-sources"
mkdir -p "$snake_sources"
LC_ALL=C awk -v wasm_source_dir="$snake_sources" -f "$root/scripts/smol.awk" "$root/src/projects/snake.smol" >"$tmp/snake.html"
LC_ALL=C awk -f "$root/scripts/wasmol_front.awk" "$snake_sources/snake.wasmol" >"$tmp/snake.ir"
LC_ALL=C awk -f "$root/scripts/wasmol.awk" "$tmp/snake.ir" >"$tmp/snake.wasm"
if ! cmp -s "$tmp/snake.wasm" "$root/public/snake.wasm"; then
  printf '%s\n' 'wasm test: embedded module differs from committed snake.wasm' >&2
  exit 1
fi
if command -v node >/dev/null 2>&1; then
  node - "$tmp/snake.wasm" <<'JS'
const fs = require("fs");

(async () => {
  const bytes = fs.readFileSync(process.argv[2]);
  const { instance } = await WebAssembly.instantiate(bytes, {});
  const { memory, ptr, reset, turn, step, score } = instance.exports;
  const cells = () => new Uint8Array(memory.buffer, ptr(), 40 * 18);
  const indexes = (value) => Array.from(cells(), (cell, index) => cell === value ? index : -1).filter((index) => index >= 0);

  reset(12345);
  const first = Array.from(cells());
  if (indexes(1).join(",") !== "378,379,380") throw new Error("unexpected initial snake");
  if (indexes(2).length !== 1) throw new Error("reset must place exactly one food cell");
  if (score() !== 0) throw new Error("reset must clear score");

  reset(12345);
  if (Array.from(cells()).join(",") !== first.join(",")) throw new Error("same seed must produce same board");

  reset(2147483647);
  if (indexes(1).length !== 3 || indexes(2).length !== 1) throw new Error("signed RNG output must still place food safely");

  reset(12345);
  turn(2); // direct reverse from right to left must be ignored
  if (step() !== 1 || indexes(1).join(",") !== "379,380,381") throw new Error("reverse direction was not ignored");

  turn(3); // queue up
  turn(2); // a second turn in the same tick must not replace the first
  if (step() !== 1 || !indexes(1).includes(341)) throw new Error("turn queue accepted more than one turn per tick");

  reset(7);
  let status = 1;
  for (let tick = 0; tick < 30 && status === 1; tick += 1) status = step();
  if (status !== 0) throw new Error("wall collision must end the game");
  if (step() !== 0) throw new Error("game over must remain stable until reset");
})().catch((error) => {
  console.error(`snake runtime test: ${error.message}`);
  process.exit(1);
});
JS
fi

# Exercise the real embedded-module build wrapper from a clean tree.
mkdir -p "$tmp/repo/scripts" "$tmp/repo/public"
cp "$root/scripts/smol.awk" "$root/scripts/wasmol_front.awk" "$root/scripts/wasmol.awk" "$root/scripts/wasm_build.sh" "$tmp/repo/scripts/"
cp -R "$root/src" "$tmp/repo/src"
"$tmp/repo/scripts/wasm_build.sh" "$tmp/repo/src/index.smol" >/dev/null
cmp -s "$tmp/repo/public/life.wasm" "$root/public/life.wasm" || {
  printf '%s\n' 'wasm test: clean wrapper build differs from committed life.wasm' >&2
  exit 1
}

# A component may own one module and be rendered by multiple entrypoints. The
# same source declaration is reused, while distinct modules still build once.
cat >"$tmp/repo/src/shared.smol" <<'SMOL'
@wasm shared as shared_wasm
  @func value -> i32 export
    @return 1
p | #{shared_wasm}
SMOL
cat >"$tmp/repo/src/entry-one.smol" <<'SMOL'
:body
  @include shared.smol
SMOL
cat >"$tmp/repo/src/entry-two.smol" <<'SMOL'
@wasm second as second_wasm
  @func value -> i32 export
    @return 2
:body
  @include shared.smol
  p | #{second_wasm}
SMOL
printf '%s\n' 'stale' >"$tmp/repo/public/obsolete.wasm"
"$tmp/repo/scripts/wasm_build.sh" "$tmp/repo/src/entry-one.smol" "$tmp/repo/src/entry-two.smol" >/dev/null
for module in shared second; do
  [ -f "$tmp/repo/public/$module.wasm" ] || {
    printf 'wasm test: missing module from multiple entrypoints: %s\n' "$module" >&2
    exit 1
  }
done
if [ -e "$tmp/repo/public/obsolete.wasm" ]; then
  printf '%s\n' 'wasm test: stale embedded module survived rebuild' >&2
  exit 1
fi

# Publishing several modules is one transaction: a failure during publication
# must roll every artifact back to the previous complete generation.
mkdir -p "$tmp/bin"
cat >"$tmp/bin/mv" <<'SH'
#!/bin/sh
case "$1:$2" in
  */binaries/snake.wasm:*/public/snake.wasm) exit 73 ;;
esac
exec /bin/mv "$@"
SH
chmod +x "$tmp/bin/mv"
printf '%s\n' 'old-life-generation' >"$tmp/repo/public/life.wasm"
printf '%s\n' 'old-snake-generation' >"$tmp/repo/public/snake.wasm"
if PATH="$tmp/bin:$PATH" "$tmp/repo/scripts/wasm_build.sh" >/dev/null 2>&1; then
  printf '%s\n' 'wasm test: interrupted multi-module publication unexpectedly succeeded' >&2
  exit 1
fi
grep -q '^old-life-generation$' "$tmp/repo/public/life.wasm" || {
  printf '%s\n' 'wasm test: publication failure left a mixed module generation' >&2
  exit 1
}
grep -q '^old-snake-generation$' "$tmp/repo/public/snake.wasm" || {
  printf '%s\n' 'wasm test: publication failure replaced the failing module' >&2
  exit 1
}

# Failure while removing a stale artifact must also restore every replaced
# module and clean the transaction stage.
cat >"$tmp/bin/rm" <<'SH'
#!/bin/sh
for arg do
  case "$arg" in
    */public/obsolete.wasm) exit 74 ;;
  esac
done
exec /bin/rm "$@"
SH
chmod +x "$tmp/bin/rm"
printf '%s\n' 'old-life-generation' >"$tmp/repo/public/life.wasm"
printf '%s\n' 'old-snake-generation' >"$tmp/repo/public/snake.wasm"
printf '%s\n' 'old-obsolete-generation' >"$tmp/repo/public/obsolete.wasm"
if PATH="$tmp/bin:$PATH" "$tmp/repo/scripts/wasm_build.sh" >/dev/null 2>&1; then
  printf '%s\n' 'wasm test: stale-removal failure unexpectedly succeeded' >&2
  exit 1
fi
for module in life snake obsolete; do
  grep -q "^old-$module-generation$" "$tmp/repo/public/$module.wasm" || {
    printf 'wasm test: stale-removal failure did not restore %s.wasm\n' "$module" >&2
    exit 1
  }
done
for leaked in "$tmp/repo/public"/.wasm-build.*; do
  if [ -e "$leaked" ]; then
    printf '%s\n' 'wasm test: stale-removal rollback leaked its staging directory' >&2
    exit 1
  fi
done
rm -f "$tmp/bin/rm"

# A compiler failure must preserve the previous artifact and clean its stage.
printf '%s\n' 'known-good' >"$tmp/repo/public/life.wasm"
sed 's/@return cells_address/@return missing_value/' "$tmp/repo/src/includes/life.smol" >"$tmp/repo/src/includes/life.smol.bad"
mv "$tmp/repo/src/includes/life.smol.bad" "$tmp/repo/src/includes/life.smol"
if "$tmp/repo/scripts/wasm_build.sh" "$tmp/repo/src/index.smol" >/dev/null 2>&1; then
  printf '%s\n' 'wasm test: invalid embedded module unexpectedly built' >&2
  exit 1
fi
grep -q '^known-good$' "$tmp/repo/public/life.wasm" || {
  printf '%s\n' 'wasm test: failed build replaced the previous artifact' >&2
  exit 1
}
for leaked in "$tmp/repo/public"/.wasm-build.*; do
  if [ -e "$leaked" ]; then
    printf '%s\n' 'wasm test: failed build leaked its staging directory' >&2
    exit 1
  fi
done

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

# The Smol-like frontend must reject malformed source before it reaches the
# validated stack IR backend.
expect_front_fail() {
  name=$1
  shift
  printf '%s\n' "$@" >"$tmp/front-$name.wasmol"
  if LC_ALL=C awk -f "$root/scripts/wasmol_front.awk" "$tmp/front-$name.wasmol" >"$tmp/front-$name.ir" 2>/dev/null; then
    printf 'wasm test: invalid high-level Wasmol unexpectedly lowered: %s\n' "$name" >&2
    exit 1
  fi
  if [ -s "$tmp/front-$name.ir" ]; then
    printf 'wasm test: failed frontend leaked partial IR: %s\n' "$name" >&2
    exit 1
  fi
}

expect_front_fail unknown-directive '@unicorn nope'
expect_front_fail odd-indent '@func nope' '   @return'
expect_front_fail over-indent '@func nope' '    @return'
expect_front_fail nested-declaration '@func nope' '  @const bad 1'
tab=$(printf '	')
expect_front_fail tab-indent '@func nope' "${tab}@return"
expect_front_fail malformed-constant '@const nope'
expect_front_fail malformed-for '@func nope' '  @for item 0 .. 2'
expect_front_fail malformed-expression '@func nope' '  @let value:i32 = (1 + 2'
expect_front_fail unknown-array '@func nope' '  @set nowhere[0] = 1'
expect_front_fail unknown-state-address '@state value at nowhere'
expect_front_fail duplicate-state '@const address 0' '@state value at address' '@array value at address'
expect_front_fail shadow-state '@const address 0' '@state value at address' '@func nope' '  @let value:i32 = 0'
expect_front_fail duplicate-loop-local '@func nope item:i32' '  @for item in 0 .. 2' '    @return'
expect_front_fail partial-output '@func valid' '  @return' '@unicorn nope'
expect_front_fail parameter-shadow '@const value 7' '@func nope value:i32 -> i32' '  @return value'
expect_front_fail cross-kind-duplicate '@const address 0' '@state value at address' '@const value 7'
expect_front_fail late-parameter-shadow '@func nope value:i32' '  @return' '@const value 7'
expect_front_fail late-local-shadow '@func nope' '  @let value:i32 = 0' '@const value 7'
expect_front_fail late-loop-shadow '@func nope' '  @for value in 0 .. 1' '    @return' '@const value 7'

# Smol-shaped module declarations group constants, nest memory layout, and keep
# exports next to function definitions.
printf '%s\n' \
  '@vars' \
  '  pages 1' \
  '  answer_address 0' \
  '@memory pages' \
  '  @state answer at answer_address' \
  '@export memory' \
  '@func value -> i32 export' \
  '  @return 7' >"$tmp/smol-shaped.wasmol"
LC_ALL=C awk -f "$root/scripts/wasmol_front.awk" "$tmp/smol-shaped.wasmol" >"$tmp/smol-shaped.ir"
LC_ALL=C awk -f "$root/scripts/wasmol.awk" "$tmp/smol-shaped.ir" >"$tmp/smol-shaped.wasm"
grep -q '^export func value$' "$tmp/smol-shaped.ir"

# Value returns must stop execution, and ascending half-open ranges must safely
# reject descending bounds instead of wrapping around the whole i32 space.
printf '%s\n' '@func answer -> i32' '  @return 7' '  @let after:i32 = 9' >"$tmp/return-lowering.wasmol"
LC_ALL=C awk -f "$root/scripts/wasmol_front.awk" "$tmp/return-lowering.wasmol" >"$tmp/return-lowering.ir"
grep -q '^return$' "$tmp/return-lowering.ir" || {
  printf '%s\n' 'wasm test: value return did not lower to return opcode' >&2
  exit 1
}
LC_ALL=C awk -f "$root/scripts/wasmol.awk" "$tmp/return-lowering.ir" >"$tmp/return-lowering.wasm"

printf '%s\n' '@func descending' '  @for item in 2 .. 0' '    @return' >"$tmp/range-lowering.wasmol"
LC_ALL=C awk -f "$root/scripts/wasmol_front.awk" "$tmp/range-lowering.wasmol" >"$tmp/range-lowering.ir"
grep -q '^i32.lt_s$' "$tmp/range-lowering.ir" || {
  printf '%s\n' 'wasm test: for range is missing signed bound check' >&2
  exit 1
}
LC_ALL=C awk -f "$root/scripts/wasmol.awk" "$tmp/range-lowering.ir" >"$tmp/range-lowering.wasm"

# Frontend source that lowers cleanly must still pass the backend's declaration,
# stack, and type checks.
expect_pipeline_fail() {
  name=$1
  shift
  printf '%s\n' "$@" >"$tmp/pipeline-$name.wasmol"
  if LC_ALL=C awk -f "$root/scripts/wasmol_front.awk" "$tmp/pipeline-$name.wasmol" >"$tmp/pipeline-$name.ir" 2>/dev/null \
    && LC_ALL=C awk -f "$root/scripts/wasmol.awk" "$tmp/pipeline-$name.ir" >"$tmp/pipeline-$name.wasm" 2>/dev/null; then
    printf 'wasm test: invalid high-level Wasmol unexpectedly compiled: %s\n' "$name" >&2
    exit 1
  fi
}

expect_pipeline_fail wrong-let-type '@func nope' '  @let value:i32 = 0.0'
expect_pipeline_fail duplicate-let '@func nope' '  @let value:i32 = 0' '  @let value:i32 = 1'
expect_pipeline_fail missing-result '@func nope -> i32'

printf '%s\n' 'wasm test ok'
