#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
compiler="$root/scripts/smol.awk"

tmp_in=$(mktemp)
tmp_out=$(mktemp)
tmp_expected=$(mktemp)
tmp_include=$(mktemp)
tmp_data=$(mktemp)

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
  ul
    @for people as person
      li #{person.index}: #{person.title}
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

tmp_in2=$(mktemp)

sed "s|@include INC|@include $tmp_include|" "$tmp_in" > "$tmp_in2"
mv "$tmp_in2" "$tmp_in"

tmp_in3=$(mktemp)

sed "s|@data DATAFILE|@data $tmp_data|" "$tmp_in" > "$tmp_in3"
mv "$tmp_in3" "$tmp_in"

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
    <script>
    console.log("Chris")
    </script>
  </body>
</html>
HTML

awk -f "$compiler" "$tmp_in" > "$tmp_out"

diff -u "$tmp_expected" "$tmp_out"

rm -f "$tmp_in" "$tmp_out" "$tmp_expected" "$tmp_include" "$tmp_data"

printf '%s\n' "smol test ok"
