#!/bin/sh
set -eu

need_cf=0
if [ "${1:-}" = "--cf" ]; then
  need_cf=1
  shift
fi

have() { command -v "$1" >/dev/null 2>&1; }

show_tool() {
  name="$1"
  version_cmd="$2"

  if ! have "$name"; then
    printf '%s\n' "missing: $name" >&2
    return 1
  fi

  path=$(command -v "$name")
  printf '%s\n' "ok: $name ($path)"

  if [ -n "$version_cmd" ]; then
    # shellcheck disable=SC2086
    sh -c "$version_cmd" 2>/dev/null | head -n 1 | sed 's/^/  /'
  fi

  return 0
}

status=0

show_tool awk 'awk -W version' || status=1
show_tool curl 'curl --version' || status=1
show_tool sort 'sort --version' || status=1
show_tool sed 'sed --version' || status=1
show_tool sh '' || status=1
show_tool make 'make --version' || status=1

if have wrangler; then
  printf '%s\n' "ok: wrangler ($(command -v wrangler))"
  wrangler --version 2>/dev/null | head -n 1 | sed 's/^/  /'

  missing_cf=0
  if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
    printf '%s\n' "warn: CLOUDFLARE_API_TOKEN not set (wrangler needs it non-interactive)" >&2
    missing_cf=1
  fi
  if [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]; then
    printf '%s\n' "warn: CLOUDFLARE_ACCOUNT_ID not set (needed for some cf ops)" >&2
  fi

  if [ "$need_cf" -eq 1 ] && [ "$missing_cf" -eq 1 ]; then
    status=1
  fi
fi

exit "$status"
