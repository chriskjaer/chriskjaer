#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
compiler="$root/scripts/smol.awk"

tmp_in=$(mktemp)
tmp_out=$(mktemp)
tmp_expected=$(mktemp)
tmp_include=$(mktemp)
tmp_data=$(mktemp)
tmp_onefield=$(mktemp)

cat <<'HAML' > "$tmp_in"
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

cat <<'HAML' > "$tmp_include"
p(class="#{note_class}")
  | #{note_text}
HAML

cat <<'DATA' > "$tmp_data"
read | 2024-01-01 | 0 | 0 | Ada | Lovelace
read | 2024-01-02 | 0 | 0 | Linus | Torvalds
DATA

cat <<'ONE' > "$tmp_onefield"
smol
test
ONE

tmp_in2=$(mktemp)

sed "s|@include INC|@include $tmp_include|" "$tmp_in" > "$tmp_in2"
mv "$tmp_in2" "$tmp_in"

tmp_in3=$(mktemp)

sed "s|@data DATAFILE|@data $tmp_data|" "$tmp_in" > "$tmp_in3"
mv "$tmp_in3" "$tmp_in"

tmp_in4=$(mktemp)

sed "s|@data ONEFIELD|@data $tmp_onefield|" "$tmp_in" > "$tmp_in4"
mv "$tmp_in4" "$tmp_in"

cat <<'HTML' > "$tmp_expected"
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

awk -f "$compiler" "$tmp_in" > "$tmp_out"

diff -u "$tmp_expected" "$tmp_out"

# Regression: @for at EOF + pipeline with quotes and pipes.

tmp_in_eof=$(mktemp)
tmp_out_eof=$(mktemp)
tmp_expected_eof=$(mktemp)
tmp_data_eof=$(mktemp)

authors_data="$tmp_data_eof"
cat <<'DATA' > "$tmp_data_eof"
read | 2024-01-01 | 0 | 0 | Ada | Lovelace
read | 2024-01-02 | 0 | 0 | Linus | Torvalds
DATA

cat <<'HAML' > "$tmp_in_eof"
@title Smol EOF For Test

:body
  @data DATAFILE | awk -F'|' '{print $5 "|" $6}' as names
  ul
    @for names as row
      li #{row.1} #{row.2}
HAML

tmp_in_eof2=$(mktemp)

sed "s|DATAFILE|$authors_data|" "$tmp_in_eof" > "$tmp_in_eof2"
mv "$tmp_in_eof2" "$tmp_in_eof"

cat <<'HTML' > "$tmp_expected_eof"
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

awk -f "$compiler" "$tmp_in_eof" > "$tmp_out_eof"

diff -u "$tmp_expected_eof" "$tmp_out_eof"

rm -f \
  "$tmp_in" "$tmp_out" "$tmp_expected" "$tmp_include" "$tmp_data" "$tmp_onefield" \
  "$tmp_in_eof" "$tmp_out_eof" "$tmp_expected_eof" "$tmp_data_eof"

printf '%s\n' "smol test ok"

# regression: directives at same indent close previous tags
cat > /tmp/smol_directive_test.smol <<'SMOL'
:body
  section
    h2.section_title
      | Read
    @data /tmp/smol_directive_test.data as years
    @for years as y
      h3.year
        | #{y.value}
SMOL
cat > /tmp/smol_directive_test.data <<'DATA'
2025
DATA
awk -f "$compiler" /tmp/smol_directive_test.smol > /tmp/smol_directive_test.html
# h3 must not be inside h2
if grep -q "<h2 class=section_title>Read <h3" /tmp/smol_directive_test.html; then
  echo "directive nesting regression" >&2
  cat /tmp/smol_directive_test.html >&2
  exit 1
fi
rm -f /tmp/smol_directive_test.smol /tmp/smol_directive_test.data /tmp/smol_directive_test.html
