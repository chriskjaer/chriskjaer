#!/bin/sh
set -eu

root=$(CDPATH="" cd -- "$(dirname -- "$0")/.." && pwd)
out="$root/public"
build="make -s -C $root html"
port="${PORT:-3333}"

watch_dirs=". $root/src $root/scripts $root/public"

hash_files() {
  # shellcheck disable=SC2086
  find . -type f -print | sort | while IFS= read -r file; do
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

sh -c "$build"
printf '%s\n' "serving $out at http://localhost:$port"
start_server >/dev/null 2>&1 &
server_pid=$!
open_browser

trap 'kill "$server_pid" 2>/dev/null' INT TERM EXIT

printf '%s\n' "watching $watch_dirs (ctrl-c to stop)"

while :; do
  current=$(hash_files)
  if [ "$current" != "$last" ]; then
    last="$current"
    sh -c "$build"
    printf '%s\n' "built $(date '+%H:%M:%S')"
  fi
  sleep 0.5
done
