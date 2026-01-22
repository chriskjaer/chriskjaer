#!/bin/sh
set -eu

project="${CF_PAGES_PROJECT:-chriskjaer}"

if ! command -v wrangler >/dev/null 2>&1; then
  printf '%s\n' "missing: wrangler (npm i -g wrangler)" >&2
  exit 1
fi

if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  printf '%s\n' "missing: CLOUDFLARE_API_TOKEN (wrangler needs it non-interactive)" >&2
  exit 1
fi

account_id="${CLOUDFLARE_ACCOUNT_ID:-}"

if [ -z "$account_id" ]; then
  mem_file="${CF_ACCOUNT_ID_FILE:-$HOME/clawd/memory/2026-01-22.md}"
  if [ -f "$mem_file" ]; then
    account_id=$(grep -Eo '[a-f0-9]{32}' "$mem_file" | head -n 1 || true)
  fi
fi

if [ -z "$account_id" ]; then
  printf '%s\n' "missing: CLOUDFLARE_ACCOUNT_ID (or set CF_ACCOUNT_ID_FILE)" >&2
  exit 1
fi

printf '%s\n' "listing deployments for pages project: $project" >&2

json=$(wrangler pages deployment list --project-name "$project" --json)

deployment_id=$(printf '%s' "$json" | node -e '
  const fs = require("fs");
  const input = fs.readFileSync(0, "utf8");
  const deployments = JSON.parse(input);
  const failing = deployments
    .filter(d => (d.latest_stage && d.latest_stage.status) === "failure")
    .sort((a,b) => new Date(b.created_on) - new Date(a.created_on));
  if (failing.length) {
    process.stdout.write(failing[0].id);
    process.exit(0);
  }
  const recent = deployments
    .slice()
    .sort((a,b) => new Date(b.created_on) - new Date(a.created_on));
  if (recent.length) {
    process.stdout.write(recent[0].id);
    process.exit(0);
  }
  process.exit(1);
')

if [ -z "$deployment_id" ]; then
  printf '%s\n' "no deployments found" >&2
  exit 1
fi

printf '%s\n' "tailing deployment: $deployment_id" >&2

# Tail only failing invocations (Functions logs).
wrangler pages deployment tail "$deployment_id" \
  --project-name "$project" \
  --status error \
  --format pretty
