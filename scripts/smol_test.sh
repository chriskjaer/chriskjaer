#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
compiler="$root/scripts/smol.awk"

tmp_in=$(mktemp)
tmp_out=$(mktemp)
tmp_expected=$(mktemp)

cat <<'HAML' > "$tmp_in"
%div#app.container
  %h1 Hello
  %img(src="/logo.svg" alt="logo")
  %p
    | plain text
  %p.note Secondary
%style
  body
    margin: 0
  a
    color: red
    &:hover
      color: blue
HAML

cat <<'HTML' > "$tmp_expected"
<div id="app" class="container">
  <h1>Hello</h1>
  <img src="/logo.svg" alt="logo" />
  <p>
    plain text
  </p>
  <p class="note">Secondary</p>
</div>
<style>
  body {
    margin: 0;
  }
  a {
    color: red;
  }
  a:hover {
    color: blue;
  }
</style>
HTML

awk -f "$compiler" "$tmp_in" > "$tmp_out"

diff -u "$tmp_expected" "$tmp_out"

rm -f "$tmp_in" "$tmp_out" "$tmp_expected"

printf '%s\n' "smol test ok"
