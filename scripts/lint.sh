#!/bin/sh
set -eu

root=$(CDPATH="" cd -- "$(dirname -- "$0")/.." && pwd)

sh_files=$(find "$root/scripts" -type f -name '*.sh' -print)

if [ -z "$sh_files" ]; then
  printf '%s\n' "no shell scripts found" >&2
  exit 0
fi

status=0

if command -v shellcheck >/dev/null 2>&1; then
  # shellcheck disable=SC2086
  shellcheck -x $sh_files || status=$?
else
  printf '%s\n' "lint: shellcheck not installed; skipping (brew install shellcheck | apt-get install shellcheck)" >&2
fi

if command -v shfmt >/dev/null 2>&1; then
  # shellcheck disable=SC2086
  shfmt -i 2 -bn -ci -w $sh_files || status=$?
else
  printf '%s\n' "lint: shfmt not installed; skipping (brew install shfmt | go install mvdan.cc/sh/v3/cmd/shfmt@latest)" >&2
fi

exit "$status"
