#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

src="$root/src"
out="$root/public"

template="$src/index.html"
style="$src/styles.css"
logo="$src/logo.svg"
target="$out/index.html"

mkdir -p "$out"

sed \
  -e "/{{STYLE}}/{
    r $style
    d
  }" \
  -e "/{{LOGO}}/{
    r $logo
    d
  }" \
  "$template" > "$target"

size=$(wc -c < "$target" | tr -d ' ')
printf '%s\n' "built $(basename "$target") ($size bytes, unminified)"
