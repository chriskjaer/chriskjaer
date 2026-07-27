#!/bin/sh
set -eu

root=$(CDPATH="" cd -- "$(dirname -- "$0")/.." && pwd)

index="$root/public/index.html"
books="$root/public/books/index.html"
pax="$root/public/pax/index.html"
projects_smol="$root/public/projects/smol/index.html"
projects_snake="$root/public/projects/snake/index.html"
data="$root/src/data/books"

fail() {
  printf '%s\n' "smoke: $*" >&2
  exit 1
}

[ -s "$index" ] || fail "missing $index (run: make html)"
[ -s "$books" ] || fail "missing $books (run: make html)"
[ -s "$pax" ] || fail "missing $pax (run: make html)"
[ -s "$projects_smol" ] || fail "missing $projects_smol (run: make html)"
[ -s "$projects_snake" ] || fail "missing $projects_snake (run: make html)"
[ -s "$root/public/snake.wasm" ] || fail "missing public/snake.wasm"

# Basic style marker (index should have some inlined CSS).
grep -q "<style>" "$index" || fail "missing <style> in index.html"

# Every public page should have canonical and social sharing metadata.
for page in "$index" "$books" "$pax" "$projects_smol" "$projects_snake"; do
  grep -q 'rel=canonical' "$page" || fail "missing canonical URL in $page"
  grep -q 'property=og:title' "$page" || fail "missing Open Graph title in $page"
  grep -q 'property=og:description' "$page" || fail "missing Open Graph description in $page"
  grep -q 'property=og:url' "$page" || fail "missing Open Graph URL in $page"
  grep -q 'name=twitter:card' "$page" || fail "missing Twitter card in $page"
done

# Static discovery and fallback files should exist and have the right content.
[ -s "$root/public/robots.txt" ] || fail "missing public/robots.txt"
[ -s "$root/public/sitemap.xml" ] || fail "missing public/sitemap.xml"
[ -s "$root/public/404.html" ] || fail "missing public/404.html"
[ -s "$root/public/_redirects" ] || fail "missing public/_redirects"
grep -q '^User-agent:' "$root/public/robots.txt" || fail "invalid robots.txt"
grep -q '<urlset' "$root/public/sitemap.xml" || fail "invalid sitemap.xml"
grep -q '/favicon.ico /favicon.svg 301' "$root/public/_redirects" || fail "missing favicon redirect"

# Books page should have expected headings.
grep -Eq "<h2[^>]*>To read[[:space:]]*</h2>" "$books" || fail "books page missing 'To read' heading"
grep -Eq "<h2[^>]*>Read[[:space:]]*</h2>" "$books" || fail "books page missing 'Read' heading"

# Pax page should have expected markers.
grep -Eq "<h1[^>]*>Pax[[:space:]]*</h1>" "$pax" || fail "pax page missing 'Pax' heading"
grep -Eq "<img[^>]*src=/pax/avatar\\.jpg" "$pax" || fail "pax page missing avatar img"
grep -q 'href=/projects/snake/' "$pax" || fail "pax page missing Snake link"

# Projects Smol page should have expected markers.
grep -Eq "<h1[^>]*>Smol[[:space:]]*</h1>" "$projects_smol" || fail "projects smol page missing 'Smol' heading"

# Snake is a real playable project, not an orphaned artifact.
grep -Eq "<h1[^>]*>Snake[[:space:]]*</h1>" "$projects_snake" || fail "projects snake page missing 'Snake' heading"
grep -q 'id=snake-screen' "$projects_snake" || fail "projects snake page missing game canvas"
grep -q 'devicePixelRatio' "$projects_snake" || fail "Snake canvas is not DPR-aware"
grep -Eq 'const glyphs[[:space:]]*=' "$projects_snake" || fail "Snake LCD is missing its bitmap font"
if grep -q 'fillText(' "$projects_snake"; then
  fail "Snake LCD uses antialiased canvas text"
fi
grep -q 'env(safe-area-inset-top)' "$projects_snake" || fail "Snake page is missing safe-area spacing"
grep -q 'viewport-fit=cover' "$projects_snake" || fail "Snake page does not expose the iPhone safe area"
grep -q 'drawBoundary' "$projects_snake" || fail "Snake playfield is missing a visible collision boundary"
grep -q 'context.fillRect(1, 9, 82, 1)' "$projects_snake" || fail "Snake top wall does not replace the LCD divider"
grep -q 'context.fillRect(1, 46, 82, 1)' "$projects_snake" || fail "Snake bottom wall is not adjacent to the board"
grep -q 'const y = 10 + Math.floor(index / width) \* 2' "$projects_snake" || fail "Snake cells are not aligned inside the visible wall"
grep -q 'drawRunIndicator' "$projects_snake" || fail "Snake running state is missing a play indicator"
grep -q 'clip-path: inset(50%)' "$projects_snake" || fail "Snake duplicates LCD status below the screen"
if grep -q 'href=/projects/snake' "$index"; then
  fail "home page should not list every project"
fi

# If we have to-read rows, ensure the 'To read' section contains at least one <li>.
if [ -s "$data" ] && grep -q '^to-read |' "$data"; then
  has_li=$(awk '
    BEGIN{in_section=0; li=0}
    /To read[[:space:]]*<\/h2>/{in_section=1}
    in_section && /<li[ >]/{li=1}
    in_section && /<\/section>/{in_section=0}
    END{print li}
  ' "$books")
  if [ "$has_li" != "1" ]; then
    fail "to-read rows exist but no <li> in To read section"
  fi
fi

# If we have read rows, ensure the 'Read' section contains at least one <li>.
if [ -s "$data" ] && grep -q '^read |' "$data"; then
  has_li=$(awk '
    BEGIN{in_section=0; li=0}
    /Read[[:space:]]*<\/h2>/{in_section=1}
    in_section && /<li[ >]/{li=1}
    in_section && /<\/section>/{in_section=0}
    END{print li}
  ' "$books")
  if [ "$has_li" != "1" ]; then
    fail "read rows exist but no <li> in Read section"
  fi
fi

printf '%s\n' "smoke ok"
