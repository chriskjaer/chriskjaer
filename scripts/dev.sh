#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
out="$root/public"
build="$root/scripts/build.sh"
port="${PORT:-3333}"

watch_files="$root/index.smol $root/scripts/smol.awk"

hash_files() {
  for file in $watch_files; do
    if [ ! -f "$file" ]; then
      printf '%s\n' "missing $file" >&2
      exit 1
    fi
    cksum "$file"
  done | cksum | awk '{print $1}'
}

last=""

start_server() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -m http.server "$port" --directory "$out"
    return
  fi

  if command -v ruby >/dev/null 2>&1; then
    ruby -run -e httpd "$out" -p "$port"
    return
  fi

  if command -v python >/dev/null 2>&1; then
    (cd "$out" && python -m SimpleHTTPServer "$port")
    return
  fi

  printf '%s\n' "no server tool found (python3/ruby/python)" >&2
  exit 1
}

open_browser() {
  if command -v open >/dev/null 2>&1; then
    open "http://localhost:$port/"
  fi
}

"$build"
printf '%s\n' "serving $out at http://localhost:$port"
start_server >/dev/null 2>&1 &
server_pid=$!
open_browser

trap 'kill "$server_pid" 2>/dev/null' INT TERM EXIT

printf '%s\n' "watching $watch_files (ctrl-c to stop)"

while :; do
  current=$(hash_files)
  if [ "$current" != "$last" ]; then
    last="$current"
    "$build"
    printf '%s\n' "built $(date '+%H:%M:%S')"
  fi
  sleep 0.5
done
