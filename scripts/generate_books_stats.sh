#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cache="$root/src/data/goodreads_cache/32620052_read.json"
out="$root/src/data/books_stats.smol"

if [ ! -f "$cache" ]; then
  exit 0
fi

node - <<'NODE' "$cache" "$out"
const fs = require('fs');
const [cachePath, outPath] = process.argv.slice(2);

let books = [];
try {
  books = JSON.parse(fs.readFileSync(cachePath, 'utf8'));
} catch {
  process.exit(0);
}

const perYear = new Map();
for (const book of books) {
  const date = String(book?.date_read || '').trim();
  if (date.length < 4 || !/^\d{4}/.test(date)) continue;

  const year = Number(date.slice(0, 4));
  const pages = Number(book?.pages);

  const prev = perYear.get(year) || { books: 0, pages: 0 };
  perYear.set(year, {
    books: prev.books + 1,
    pages:
      prev.pages + (Number.isInteger(pages) && pages > 0 ? pages : 0),
  });
}

const years = [...perYear.keys()].sort((a, b) => b - a);
const maxBooks = years.reduce((m, y) => Math.max(m, perYear.get(y)?.books || 0), 0);

const fmt = new Intl.NumberFormat('en-US');

const lines = [
  '-# Generated file. Do not edit.',
  '-# Source: Goodreads read shelf cache.',
  '',
  'ul.chart',
];

if (years.length === 0) {
  lines.push('  li', '    | (no data)');
} else {
  for (const year of years) {
    const { books: bookCount, pages: pageCount } = perYear.get(year) || {
      books: 0,
      pages: 0,
    };

    const pct = maxBooks ? Math.round((bookCount / maxBooks) * 100) : 0;

    const parts = [`${bookCount} books`];
    if (pageCount > 0) parts.push(`${fmt.format(pageCount)} pages`);

    lines.push(
      '  li.bar',
      '    span.year',
      `      | ${year}`,
      '    span.track',
      `      span.fill(style="width: ${pct}%")`,
      '    span.count',
      `      | ${parts.join(' · ')}`,
    );
  }
}

fs.writeFileSync(outPath, lines.join('\n') + '\n');
NODE
