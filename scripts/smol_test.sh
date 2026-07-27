#!/bin/sh
set -eu

root=$(CDPATH="" cd -- "$(dirname -- "$0")/.." && pwd)
compiler="$root/scripts/smol.awk"

tmp_in=$(mktemp)
tmp_out=$(mktemp)
tmp_expected=$(mktemp)
tmp_include=$(mktemp)
tmp_data=$(mktemp)
tmp_onefield=$(mktemp)

cat <<'HAML' >"$tmp_in"
@title Smol Test
@description Example site
@viewport width=device-width, initial-scale=1
@lang en
@charset utf-8
@meta(name="theme-color" content="#000")

@vars
  who "Chris"
  note_class=note
  note_text "Included #{who}"

:body
  h1 Hello #{who}
  @include INC note_class=note note_text="Included #{who}"
  @data DATAFILE as people
  @data ONEFIELD as tags
  ul
    @for people as person
      li #{person.index}: #{person.5}
  ol
    @for tags as tag
      li #{tag.index}: #{tag.value}
  style
    body
      margin: 0
  script
    | console.log("#{who}")
HAML

cat <<'HAML' >"$tmp_include"
p(class="#{note_class}")
  | #{note_text}
HAML

cat <<'DATA' >"$tmp_data"
read | 2024-01-01 | 0 | 0 | Ada | Lovelace
read | 2024-01-02 | 0 | 0 | Linus | Torvalds
DATA

cat <<'ONE' >"$tmp_onefield"
smol
test
ONE

tmp_in2=$(mktemp)

sed "s|@include INC|@include $tmp_include|" "$tmp_in" >"$tmp_in2"
mv "$tmp_in2" "$tmp_in"

tmp_in3=$(mktemp)

sed "s|@data DATAFILE|@data $tmp_data|" "$tmp_in" >"$tmp_in3"
mv "$tmp_in3" "$tmp_in"

tmp_in4=$(mktemp)

sed "s|@data ONEFIELD|@data $tmp_onefield|" "$tmp_in" >"$tmp_in4"
mv "$tmp_in4" "$tmp_in"

cat <<'HTML' >"$tmp_expected"
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>Smol Test</title>
    <meta name="description" content="Example site" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000" />
    <style>
    body {
      margin: 0;
    }
    </style>
  </head>
  <body>
    <h1>Hello Chris</h1>
    <p class="note">
      Included Chris
    </p>
    <ul>
      <li>1: Ada</li>
      <li>2: Linus</li>
    </ul>
    <ol>
      <li>1: smol</li>
      <li>2: test</li>
    </ol>
    <script>
    console.log("Chris")
    </script>
  </body>
</html>
HTML

awk -f "$compiler" "$tmp_in" >"$tmp_out"

diff -u "$tmp_expected" "$tmp_out"

# Test: one-line text (`tag | text`).

tmp_inline_in=$(mktemp)
tmp_inline_out=$(mktemp)

cat <<'SMOL' >"$tmp_inline_in"
@title Smol Inline Text Test

:body
  @set name "Pax"
  p | Hi, #{name}
SMOL

awk -f "$compiler" "$tmp_inline_in" >"$tmp_inline_out"
grep -q "<p>Hi, Pax</p>" "$tmp_inline_out"

rm -f "$tmp_inline_in" "$tmp_inline_out"

# Regression: @for at EOF + pipeline with quotes and pipes.

tmp_in_eof=$(mktemp)
tmp_out_eof=$(mktemp)
tmp_expected_eof=$(mktemp)
tmp_data_eof=$(mktemp)

authors_data="$tmp_data_eof"
cat <<'DATA' >"$tmp_data_eof"
read | 2024-01-01 | 0 | 0 | Ada | Lovelace
read | 2024-01-02 | 0 | 0 | Linus | Torvalds
DATA

cat <<'HAML' >"$tmp_in_eof"
@title Smol EOF For Test

:body
  @data DATAFILE | awk -F'|' '{print $5 "|" $6}' as names
  ul
    @for names as row
      li #{row.1} #{row.2}
HAML

tmp_in_eof2=$(mktemp)

sed "s|DATAFILE|$authors_data|" "$tmp_in_eof" >"$tmp_in_eof2"
mv "$tmp_in_eof2" "$tmp_in_eof"

cat <<'HTML' >"$tmp_expected_eof"
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>Smol EOF For Test</title>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
  </head>
  <body>
    <ul>
      <li>Ada Lovelace</li>
      <li>Linus Torvalds</li>
    </ul>
  </body>
</html>
HTML

awk -f "$compiler" "$tmp_in_eof" >"$tmp_out_eof"

diff -u "$tmp_expected_eof" "$tmp_out_eof"

# Test: @shell + @if.

tmp_shell_data=$(mktemp)
tmp_shell_in=$(mktemp)
tmp_shell_out=$(mktemp)
tmp_shell_expected=$(mktemp)

tmp_shell_emit_in=$(mktemp)
tmp_shell_emit_out=$(mktemp)

cat <<'DATA' >"$tmp_shell_data"
a|yes
b|no
DATA

cat <<'SMOL' >"$tmp_shell_in"
@title Smol Shell If Test

:body
  @shell CMD as rows
  ul
    @for rows as r
      @if r.2 == "yes"
        li
          | ok-#{r.1}
SMOL

# Inject cmd without risking quoting issues.
sed "s|CMD|cat $tmp_shell_data|" "$tmp_shell_in" >"$tmp_shell_in.2"
mv "$tmp_shell_in.2" "$tmp_shell_in"

cat <<'HTML' >"$tmp_shell_expected"
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>Smol Shell If Test</title>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
  </head>
  <body>
    <ul>
      <li>
        ok-a
      </li>
    </ul>
  </body>
</html>
HTML

awk -f "$compiler" "$tmp_shell_in" >"$tmp_shell_out"

diff -u "$tmp_shell_expected" "$tmp_shell_out"

# Test: @shell emit mode (no `as`).
cat <<'SMOL' >"$tmp_shell_emit_in"
@title Smol Shell Emit Test

:body
  p
    @shell "printf '%s\\n' '<span>hello</span>'"
SMOL

awk -f "$compiler" "$tmp_shell_emit_in" >"$tmp_shell_emit_out"
# Should be inserted as raw HTML (not escaped).
grep -q "<span>hello</span>" "$tmp_shell_emit_out"

# Test: @data emit mode (no `as`).
tmp_data_emit_file=$(mktemp)
tmp_data_emit_in=$(mktemp)
tmp_data_emit_out=$(mktemp)

cat <<'DATA' >"$tmp_data_emit_file"
<span>data-emit</span>
DATA

cat <<'SMOL' >"$tmp_data_emit_in"
@title Smol Data Emit Test

:body
  div
    @data DATAFILE
SMOL

sed "s|DATAFILE|$tmp_data_emit_file|" "$tmp_data_emit_in" >"$tmp_data_emit_in.2"
mv "$tmp_data_emit_in.2" "$tmp_data_emit_in"

awk -f "$compiler" "$tmp_data_emit_in" >"$tmp_data_emit_out"
grep -q "<span>data-emit</span>" "$tmp_data_emit_out"

rm -f \
  "$tmp_in" "$tmp_out" "$tmp_expected" "$tmp_include" "$tmp_data" "$tmp_onefield" \
  "$tmp_inline_in" "$tmp_inline_out" \
  "$tmp_in_eof" "$tmp_out_eof" "$tmp_expected_eof" "$tmp_data_eof" \
  "$tmp_shell_data" "$tmp_shell_in" "$tmp_shell_out" "$tmp_shell_expected" \
  "$tmp_shell_emit_in" "$tmp_shell_emit_out" \
  "$tmp_data_emit_file" "$tmp_data_emit_in" "$tmp_data_emit_out"

printf '%s\n' "smol test ok"

# regression: directives at same indent close previous tags
cat >/tmp/smol_directive_test.smol <<'SMOL'
:body
  section
    h2.section_title
      | Read
    @data /tmp/smol_directive_test.data as years
    @for years as y
      h3.year
        | #{y.value}
SMOL
cat >/tmp/smol_directive_test.data <<'DATA'
2025
DATA
awk -f "$compiler" /tmp/smol_directive_test.smol >/tmp/smol_directive_test.html
# h3 must not be inside h2
if grep -q "<h2 class=section_title>Read <h3" /tmp/smol_directive_test.html; then
  echo "directive nesting regression" >&2
  cat /tmp/smol_directive_test.html >&2
  exit 1
fi
rm -f /tmp/smol_directive_test.smol /tmp/smol_directive_test.data /tmp/smol_directive_test.html

# regression: `@for` output must stay nested under parent tags
cat >/tmp/smol_for_nesting_test.smol <<'SMOL'
:body
  ul
    @data /tmp/smol_for_nesting_test.data as rows
    @for rows as r
      li
        | #{r.value}
SMOL
cat >/tmp/smol_for_nesting_test.data <<'DATA'
a
b
DATA
awk -f "$compiler" /tmp/smol_for_nesting_test.smol >/tmp/smol_for_nesting_test.html
has_nested=$(awk '
  BEGIN{in_ul=0; ok=0}
  /<ul>/{in_ul=1; next}
  in_ul && /<li>/{ok=1; exit}
  in_ul && /<\/ul>/{exit}
  END{print ok}
' /tmp/smol_for_nesting_test.html)
if [ "$has_nested" != "1" ]; then
  echo "for nesting regression" >&2
  cat /tmp/smol_for_nesting_test.html >&2
  exit 1
fi
rm -f /tmp/smol_for_nesting_test.smol /tmp/smol_for_nesting_test.data /tmp/smol_for_nesting_test.html

# regression: nested `@for` should keep nesting correct
cat >/tmp/smol_for_nested_test.smol <<'SMOL'
:body
  @data /tmp/smol_for_nested_years.data as years
  @for years as y
    h2 #{y.value}
    ul
      @data /tmp/smol_for_nested_items.data as items
      @for items as it
        li #{y.value}-#{it.value}
SMOL
cat >/tmp/smol_for_nested_years.data <<'DATA'
2025
DATA
cat >/tmp/smol_for_nested_items.data <<'DATA'
a
DATA
awk -f "$compiler" /tmp/smol_for_nested_test.smol >/tmp/smol_for_nested_test.html
# ensure li is inside ul (not after)
if grep -q "<ul>[[:space:]]*</ul>[[:space:]]*<li" /tmp/smol_for_nested_test.html; then
  echo "nested for nesting regression" >&2
  cat /tmp/smol_for_nested_test.html >&2
  exit 1
fi
rm -f /tmp/smol_for_nested_test.smol /tmp/smol_for_nested_years.data /tmp/smol_for_nested_items.data /tmp/smol_for_nested_test.html

# regression: a nested loop at the end of an outer loop must replay before EOF
cat >/tmp/smol_nested_eof_test.smol <<'SMOL'
:body
  @data /tmp/smol_nested_eof_years.data as years
  @for years as y
    h2 #{y.value}
    @shell "echo '#{y.value}|Book'" as books
    ul
      @for books as book
        li #{book.1}: #{book.2}
SMOL
cat >/tmp/smol_nested_eof_years.data <<'DATA'
2026
DATA
awk -f "$compiler" /tmp/smol_nested_eof_test.smol >/tmp/smol_nested_eof_test.html
grep -q '<li>2026: Book</li>' /tmp/smol_nested_eof_test.html
rm -f /tmp/smol_nested_eof_test.smol /tmp/smol_nested_eof_years.data /tmp/smol_nested_eof_test.html

# `@wasm` is a sidecar block: it binds the public URL, disappears from HTML,
# and writes one dedented Smol/WASM source file for the binary backend.
tmp_wasm_dir=$(mktemp -d)
tmp_wasm_in=$(mktemp)
tmp_wasm_out=$(mktemp)
cat >"$tmp_wasm_in" <<'SMOL'
@wasm demo as demo_wasm
  @vars
    pages 1
    answer_address 0
  @memory pages
    @state answer at answer_address
  @export memory
  @func value -> i32 export
    @return 7

:body
  p | #{demo_wasm}
SMOL

if awk -f "$compiler" "$tmp_wasm_in" >"$tmp_wasm_out" 2>/dev/null; then
  printf '%s\n' 'smol test: @wasm unexpectedly compiled without a sidecar directory' >&2
  exit 1
fi

awk -v wasm_source_dir="$tmp_wasm_dir" -f "$compiler" "$tmp_wasm_in" >"$tmp_wasm_out"
grep -q '<p>/demo.wasm</p>' "$tmp_wasm_out"
if grep -q '@wasm\|@func\|@return' "$tmp_wasm_out"; then
  printf '%s\n' 'smol test: @wasm source leaked into HTML' >&2
  exit 1
fi
cat >"$tmp_wasm_dir/expected" <<'WASMOL'
@vars
  pages 1
  answer_address 0
@memory pages
  @state answer at answer_address
@export memory
@func value -> i32 export
  @return 7
WASMOL
diff -u "$tmp_wasm_dir/expected" "$tmp_wasm_dir/demo.wasmol"
rm -rf "$tmp_wasm_dir" "$tmp_wasm_in" "$tmp_wasm_out"

# Module declarations are static. An empty data loop must not hide one from the
# compiler and make source validity depend on runtime data.
tmp_wasm_loop_dir=$(mktemp -d)
tmp_wasm_loop_in=$(mktemp)
tmp_wasm_loop_out=$(mktemp)
tmp_wasm_empty=$(mktemp)
cat >"$tmp_wasm_loop_in" <<SMOL
@data "$tmp_wasm_empty" as rows
:body
  @for rows as row
    @wasm hidden as hidden_wasm
      @func value -> i32 export
        @return 1
SMOL
if awk -v wasm_source_dir="$tmp_wasm_loop_dir" -f "$compiler" "$tmp_wasm_loop_in" >"$tmp_wasm_loop_out" 2>/dev/null; then
  printf '%s\n' 'smol test: empty @for silently hid an @wasm module' >&2
  exit 1
fi
if [ -e "$tmp_wasm_loop_dir/hidden.wasmol" ]; then
  printf '%s\n' 'smol test: forbidden loop module left a sidecar source' >&2
  exit 1
fi
rm -rf "$tmp_wasm_loop_dir" "$tmp_wasm_loop_in" "$tmp_wasm_loop_out" "$tmp_wasm_empty"

for condition in yes no; do
  tmp_wasm_if_dir=$(mktemp -d)
  tmp_wasm_if_in=$(mktemp)
  tmp_wasm_if_out=$(mktemp)
  cat >"$tmp_wasm_if_in" <<SMOL
@set enabled yes
:body
  @if enabled == "$condition"
    @wasm conditional as conditional_wasm
      @func value -> i32 export
        @return 1
SMOL
  if awk -v wasm_source_dir="$tmp_wasm_if_dir" -f "$compiler" "$tmp_wasm_if_in" >"$tmp_wasm_if_out" 2>/dev/null; then
    printf 'smol test: @if %s silently accepted an @wasm module\n' "$condition" >&2
    exit 1
  fi
  rm -rf "$tmp_wasm_if_dir" "$tmp_wasm_if_in" "$tmp_wasm_if_out"
done

# A static module may follow a false conditional at the same template indent.
tmp_wasm_after_if_dir=$(mktemp -d)
tmp_wasm_after_if_in=$(mktemp)
tmp_wasm_after_if_out=$(mktemp)
cat >"$tmp_wasm_after_if_in" <<'SMOL'
@set enabled no
:body
  @if enabled == yes
    p | hidden
  @wasm sibling as sibling_wasm
    @func value -> i32 export
      @return 1
  p | #{sibling_wasm}
SMOL
awk -v wasm_source_dir="$tmp_wasm_after_if_dir" -f "$compiler" "$tmp_wasm_after_if_in" >"$tmp_wasm_after_if_out"
[ -f "$tmp_wasm_after_if_dir/sibling.wasmol" ]
grep -q '<p>/sibling.wasm</p>' "$tmp_wasm_after_if_out"
rm -rf "$tmp_wasm_after_if_dir" "$tmp_wasm_after_if_in" "$tmp_wasm_after_if_out"

# Dynamic template blocks may not hide a module indirectly through an include.
tmp_wasm_hidden_dir=$(mktemp -d)
tmp_wasm_hidden_component=$(mktemp)
tmp_wasm_hidden_rows=$(mktemp)
cat >"$tmp_wasm_hidden_component" <<'SMOL'
@wasm indirect as indirect_wasm
  @func value -> i32 export
    @return 1
SMOL
for control in for if; do
  tmp_wasm_hidden_in=$(mktemp)
  tmp_wasm_hidden_out=$(mktemp)
  if [ "$control" = for ]; then
    cat >"$tmp_wasm_hidden_in" <<SMOL
@data "$tmp_wasm_hidden_rows" as rows
:body
  @for rows as row
    @include "$tmp_wasm_hidden_component"
SMOL
  else
    cat >"$tmp_wasm_hidden_in" <<SMOL
@set enabled no
:body
  @if enabled == yes
    @include "$tmp_wasm_hidden_component"
SMOL
  fi
  if awk -v wasm_source_dir="$tmp_wasm_hidden_dir" -f "$compiler" "$tmp_wasm_hidden_in" >"$tmp_wasm_hidden_out" 2>/dev/null; then
    printf 'smol test: empty %s silently hid an included @wasm module\n' "$control" >&2
    exit 1
  fi
  rm -f "$tmp_wasm_hidden_in" "$tmp_wasm_hidden_out"
done
rm -rf "$tmp_wasm_hidden_dir" "$tmp_wasm_hidden_component" "$tmp_wasm_hidden_rows"

# Reusing one declaration compares its body, not just its source line, and
# lexical aliases such as `/./` still identify the same source declaration.
tmp_wasm_reuse_root=$(mktemp -d)
mkdir -p "$tmp_wasm_reuse_root/sources"
cat >"$tmp_wasm_reuse_root/shared.smol" <<'SMOL'
@wasm shared as shared_wasm
  @func value -> i32 export
    @return 1
SMOL
awk -v wasm_source_dir="$tmp_wasm_reuse_root/sources" -f "$compiler" "$tmp_wasm_reuse_root/shared.smol" >/dev/null
awk -v wasm_source_dir="$tmp_wasm_reuse_root/sources" -f "$compiler" "$tmp_wasm_reuse_root/./shared.smol" >/dev/null
sed 's/@return 1/@return 2/' "$tmp_wasm_reuse_root/shared.smol" >"$tmp_wasm_reuse_root/shared.changed"
mv "$tmp_wasm_reuse_root/shared.changed" "$tmp_wasm_reuse_root/shared.smol"
if awk -v wasm_source_dir="$tmp_wasm_reuse_root/sources" -f "$compiler" "$tmp_wasm_reuse_root/shared.smol" >/dev/null 2>&1; then
  printf '%s\n' 'smol test: changed reused module source was silently accepted' >&2
  exit 1
fi
grep -q '^  @return 1$' "$tmp_wasm_reuse_root/sources/shared.wasmol"
rm -rf "$tmp_wasm_reuse_root"

# Blank lines are content inside raw blocks; they must not end browser source
# and turn the following indented JavaScript into accidental HTML elements.
tmp_raw_blank_in=$(mktemp)
tmp_raw_blank_out=$(mktemp)
cat >"$tmp_raw_blank_in" <<'SMOL'
:body
  script
    :raw
      (() => {
        const first = 1;

        const second = 2;
      })();
SMOL
awk -f "$compiler" "$tmp_raw_blank_in" >"$tmp_raw_blank_out"
grep -q 'const first = 1;' "$tmp_raw_blank_out"
grep -q 'const second = 2;' "$tmp_raw_blank_out"
if grep -q '<const>' "$tmp_raw_blank_out"; then
  printf '%s\n' 'smol test: blank line ended raw block and emitted JavaScript as markup' >&2
  exit 1
fi
rm -f "$tmp_raw_blank_in" "$tmp_raw_blank_out"
