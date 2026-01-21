#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cache="$root/src/data/goodreads_cache/32620052_read.json"
out="$root/src/data/goodreads_cache/32620052_read_grouped.json"

if [ ! -f "$cache" ]; then
  exit 0
fi

CACHE_PATH="$cache" OUT_PATH="$out" node - <<'NODE'
const fs = require('fs');
const cachePath = process.env.CACHE_PATH;
const outPath = process.env.OUT_PATH;

let books = [];
try {
  books = JSON.parse(fs.readFileSync(cachePath, 'utf8'));
} catch {
  process.exit(0);
}

function safeYear(date) {
  const d = String(date || '').trim();
  if (/^\d{4}-\d{2}-\d{2}$/.test(d)) return Number(d.slice(0, 4));
  if (/^\d{4}/.test(d)) return Number(d.slice(0, 4));
  return 0;
}

books = books
  .slice()
  .sort((a, b) => String(b?.date_read || '').localeCompare(String(a?.date_read || '')));

const groups = new Map();
for (const book of books) {
  const year = safeYear(book?.date_read);
  if (!groups.has(year)) groups.set(year, []);
  groups.get(year).push(book);
}

const years = [...groups.keys()].sort((a, b) => b - a);
const out = years.map((year) => ({
  year: year === 0 ? 'Unknown year' : String(year),
  books: groups.get(year) || [],
}));

fs.writeFileSync(outPath, JSON.stringify(out, null, 2) + '\n');
NODE
