#!/bin/sh
set -eu

source_root=$(CDPATH="" cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' INT TERM HUP EXIT

root="$tmp/repo"
mkdir -p "$root" "$tmp/bin"
(
  cd "$source_root"
  tar --exclude=.git -cf - .
) | (
  cd "$root"
  tar -xf -
)

cat >"$tmp/bin/curl" <<'SH'
#!/bin/sh
for arg do url=$arg; done
mode=${FAKE_MODE:-normal}
shelf=$(printf '%s\n' "$url" | sed -n 's/.*[?&]shelf=\([^&]*\).*/\1/p')
page=$(printf '%s\n' "$url" | sed -n 's/.*[?&]page=\([^&]*\).*/\1/p')

empty_feed() {
  printf '%s\n' "<?xml version=\"1.0\"?><rss version=\"2.0\" xmlns:atom=\"http://www.w3.org/2005/Atom\" xmlns:xhtml=\"http://www.w3.org/1999/xhtml\"><channel><xhtml:meta name=\"robots\" content=\"noindex\"/><title>Test bookshelf: $shelf</title><atom:link href=\"https://example.test/?shelf=$shelf\"/></channel></rss>"
}

if [ "$mode" = "undated-page2" ] && [ "$shelf" = "read" ] && [ "$page" = "2" ]; then
  printf '%s\n' '<rss><channel><title>Test bookshelf: read</title><item><title>Missing date on page two</title><author_name>Reader</author_name></item></channel></rss>'
  exit 0
fi

if [ "$mode" = "pagination-cap" ] && [ "$shelf" = "read" ]; then
  printf '%s\n' "<rss><channel><title>Test bookshelf: read</title><item><title>Page $page</title><author_name>Reader</author_name><user_read_at>Thu, 22 Jan 2026 06:57:00 +0000</user_read_at><user_rating>4</user_rating><num_pages>100</num_pages></item></channel></rss>"
  exit 0
fi

if [ "$page" != "1" ]; then
  empty_feed
  exit 0
fi

case "$mode:$shelf" in
  http-fail:read)
    exit 22
    ;;
  to-read-fail:to-read)
    exit 22
    ;;
  required-empty:read)
    empty_feed
    ;;
  parser-fail:read)
    printf '%s\n' '<rss><channel><title>Test bookshelf: read</title><item><title>Missing date</title><author_name>Reader</author_name></item></channel></rss>'
    ;;
  malformed-current:currently-reading)
    printf '%s\n' '<html><body>rate limited</body></html>'
    ;;
  truncated-current:currently-reading)
    printf '%s\n' '<rss><channel><title>Test bookshelf: currently-reading</title></channel>'
    ;;
  deceptive-html-current:currently-reading)
    printf '%s\n' '<!doctype html><html><body><!-- <rss><channel></channel></rss> --><p>bookshelf: currently-reading</p></body></html>'
    ;;
  misordered-current:currently-reading)
    printf '%s\n' '</rss><rss><channel><title>Test bookshelf: currently-reading</title></channel>'
    ;;
  comment-item-current:currently-reading)
    printf '%s\n' '<rss><channel><title>Test bookshelf: currently-reading</title><!-- <item><title>Fake</title><author_name>Fake</author_name><user_date_created>Thu, 22 Jan 2026 06:57:00 +0000</user_date_created></item> --></channel></rss>'
    ;;
  cdata-item-current:currently-reading)
    printf '%s\n' '<rss><channel><title>Test bookshelf: currently-reading</title><description><![CDATA[<item><title>Fake</title></item>]]></description></channel></rss>'
    ;;
  namespace-current:currently-reading)
    printf '%s\n' '<x:rss xmlns:x="urn:not-rss"><x:channel><x:title>Test bookshelf: currently-reading</x:title></x:channel></x:rss>'
    ;;
  mixed-namespace-current:currently-reading)
    printf '%s\n' '<rss xmlns:x="urn:not-rss"><channel><title>Test bookshelf: currently-reading</title><x:item><x:title>Fake</x:title></x:item></channel></rss>'
    ;;
  wrong-namespace-current:currently-reading)
    printf '%s\n' '<rss xmlns:atom="urn:not-atom"><channel><title>Test bookshelf: currently-reading</title><atom:link href="https://example.test/"/></channel></rss>'
    ;;
  namespaced-attribute-current:currently-reading)
    printf '%s\n' '<rss xmlns:x="urn:not-allowed"><channel x:id="fake"><title>Test bookshelf: currently-reading</title></channel></rss>'
    ;;
  processing-instruction-current:currently-reading)
    printf '%s\n' '<rss><channel><title>Test bookshelf: currently-reading</title><?fake <item><title>Fake</title><author_name>Fake</author_name><user_date_created>Thu, 22 Jan 2026 06:57:00 +0000</user_date_created></item>?></channel></rss>'
    ;;
  malformed-nesting-current:currently-reading)
    printf '%s\n' '<rss><channel><title>Test bookshelf: currently-reading</title><image><link>bad</image></link></channel></rss>'
    ;;
  invalid-date-current:currently-reading)
    printf '%s\n' '<rss><channel><title>Test bookshelf: currently-reading</title><item><title>Bad date</title><author_name>Reader</author_name><user_date_created>2026-99-99</user_date_created></item></channel></rss>'
    ;;
  numeric-reference-current:currently-reading)
    printf '%s\n' '<rss><channel><title>Test bookshelf: currently-reading</title><item><title>Rock &#38; Roll &#x26; More</title><author_name>Reader</author_name><user_date_created>2026-01-22</user_date_created></item></channel></rss>'
    ;;
  duplicate-title-current:currently-reading)
    printf '%s\n' '<rss><channel><title>Wrong bookshelf: read</title><title>Test bookshelf: currently-reading</title></channel></rss>'
    ;;
  loose-title-current:currently-reading)
    printf '%s\n' '<rss><channel><title>Test bookshelf: currently-reading-extra</title></channel></rss>'
    ;;
  dtd-current:currently-reading)
    printf '%s\n' '<!DOCTYPE rss [<!ENTITY x "currently-reading">]><rss><channel><title>Test bookshelf: &x;</title></channel></rss>'
    ;;
  oversize-current:currently-reading)
    awk 'BEGIN { printf "<rss><channel><title>Test bookshelf: currently-reading</title></channel></rss>"; for (i = 0; i < 5242880; i++) printf "x" }'
    ;;
  markup-current:currently-reading)
    printf '%s\n' '<rss><channel><title>Test bookshelf: currently-reading</title><item><title>&lt;img src=x onerror=alert(1)&gt;</title><author_name>&lt;b&gt;Bad&lt;/b&gt;</author_name><user_date_created>Thu, 22 Jan 2026 06:57:00 +0000</user_date_created><user_rating>0</user_rating><num_pages>1</num_pages></item></channel></rss>'
    ;;
  markup-read:read)
    printf '%s\n' '<rss><channel><title>Test bookshelf: read</title><item><title>&lt;svg onload=alert(2)&gt;</title><author_name>&lt;b&gt;Bad&lt;/b&gt;</author_name><user_read_at>Thu, 22 Jan 2026 06:57:00 +0000</user_read_at><user_rating>0</user_rating><num_pages>1</num_pages></item></channel></rss>'
    ;;
  markup-to-read:to-read)
    printf '%s\n' '<rss><channel><title>Test bookshelf: to-read</title><item><title>&lt;iframe src=evil&gt;</title><author_name>&lt;b&gt;Bad&lt;/b&gt;</author_name><user_date_created>Thu, 22 Jan 2026 06:57:00 +0000</user_date_created><user_rating>0</user_rating><num_pages>1</num_pages></item></channel></rss>'
    ;;
  parser-fail-current:currently-reading)
    printf '%s\n' '<rss><channel><title>Test bookshelf: currently-reading</title><item><title>Missing date</title><author_name>Reader</author_name></item></channel></rss>'
    ;;
  *:read)
    printf '%s\n' '<rss xmlns:atom="http://www.w3.org/2005/Atom" xmlns:xhtml="http://www.w3.org/1999/xhtml"><channel><xhtml:meta name="robots" content="noindex"/><title>Test bookshelf: read</title><atom:link href="https://example.test/read"/><item><title>Read book</title><author_name>Reader</author_name><user_rating>5</user_rating><num_pages>200</num_pages><user_read_at>Thu, 21 Jan 2026 06:57:00 +0000</user_read_at></item></channel></rss>'
    ;;
  *:to-read)
    printf '%s\n' '<rss xmlns:atom="http://www.w3.org/2005/Atom" xmlns:xhtml="http://www.w3.org/1999/xhtml"><channel><xhtml:meta name="robots" content="noindex"/><title>Test bookshelf: to-read</title><atom:link href="https://example.test/to-read"/><item><title>Future book</title><author_name>Writer</author_name><user_rating>0</user_rating><num_pages>300</num_pages><user_date_created>Thu, 22 Jan 2026 06:57:00 +0000</user_date_created></item></channel></rss>'
    ;;
  *:currently-reading)
    empty_feed
    ;;
  *)
    exit 22
    ;;
esac
SH
chmod +x "$tmp/bin/curl"

seed='read | 2000-01-01 | 0 | 1 | Existing book | Existing author'
assert_seed_preserved() {
  [ "$(cat "$root/src/data/books")" = "$seed" ] || {
    printf '%s\n' "site test: failed sync replaced existing data in mode $1" >&2
    exit 1
  }
}

# A genuinely empty optional shelf is valid.
PATH="$tmp/bin:$PATH" FAKE_MODE=normal "$root/scripts/goodreads_sync.sh"
grep -q '^read |' "$root/src/data/books"
grep -q '^to-read |' "$root/src/data/books"
if grep -q '^currently-reading |' "$root/src/data/books"; then
  printf '%s\n' 'site test: expected no currently-reading rows' >&2
  exit 1
fi

# Required empty shelves, HTTP failures, malformed RSS, and unusable items fail
# atomically without replacing the previous good dataset.
for mode in required-empty http-fail to-read-fail malformed-current truncated-current deceptive-html-current misordered-current namespace-current mixed-namespace-current wrong-namespace-current namespaced-attribute-current processing-instruction-current malformed-nesting-current invalid-date-current duplicate-title-current loose-title-current dtd-current oversize-current parser-fail parser-fail-current; do
  printf '%s\n' "$seed" >"$root/src/data/books"
  if PATH="$tmp/bin:$PATH" FAKE_MODE="$mode" "$root/scripts/goodreads_sync.sh"; then
    printf '%s\n' "site test: expected sync failure in mode $mode" >&2
    exit 1
  fi
  assert_seed_preserved "$mode"
done

PATH="$tmp/bin:$PATH" FAKE_MODE=numeric-reference-current "$root/scripts/goodreads_sync.sh"
grep -Fq 'Rock & Roll & More' "$root/src/data/books"

for mode in comment-item-current cdata-item-current; do
  PATH="$tmp/bin:$PATH" FAKE_MODE="$mode" "$root/scripts/goodreads_sync.sh"
  if grep -q '^currently-reading |' "$root/src/data/books"; then
    printf '%s\n' "site test: hidden item markup became a row in mode $mode" >&2
    exit 1
  fi
done

printf '%s\n' "$seed" >"$root/src/data/books"
if PATH="$tmp/bin:$PATH" MAX_PAGES=2 FAKE_MODE=pagination-cap "$root/scripts/goodreads_sync.sh"; then
  printf '%s\n' 'site test: expected pagination-cap sync failure' >&2
  exit 1
fi
assert_seed_preserved pagination-cap

# A later page containing only legitimate undated historical read items is
# skippable when the shelf produced usable rows on another page.
PATH="$tmp/bin:$PATH" FAKE_MODE=undated-page2 "$root/scripts/goodreads_sync.sh"
grep -q '^read |' "$root/src/data/books"

# The production Make target must reject bad required or optional feeds atomically.
for mode in required-empty http-fail to-read-fail malformed-current truncated-current deceptive-html-current misordered-current namespace-current mixed-namespace-current wrong-namespace-current namespaced-attribute-current processing-instruction-current malformed-nesting-current invalid-date-current duplicate-title-current loose-title-current dtd-current oversize-current parser-fail parser-fail-current; do
  printf '%s\n' "$seed" >"$root/src/data/books"
  rm -rf "$root/data/raw"
  if PATH="$tmp/bin:$PATH" FAKE_MODE="$mode" make -C "$root" data FORCE=1; then
    printf '%s\n' "site test: expected make data failure in mode $mode" >&2
    exit 1
  fi
  assert_seed_preserved "$mode-make"
done

for mode in comment-item-current cdata-item-current; do
  rm -rf "$root/data/raw"
  PATH="$tmp/bin:$PATH" FAKE_MODE="$mode" make -C "$root" data FORCE=1
  if grep -q '^currently-reading |' "$root/src/data/books"; then
    printf '%s\n' "site test: hidden item markup became a Make row in mode $mode" >&2
    exit 1
  fi
done

printf '%s\n' "$seed" >"$root/src/data/books"
if PATH="$tmp/bin:$PATH" MAX_PAGES=2 FAKE_MODE=pagination-cap make -C "$root" data FORCE=1; then
  printf '%s\n' 'site test: expected pagination-cap Make failure' >&2
  exit 1
fi
assert_seed_preserved pagination-cap-make

rm -rf "$root/data/raw"
PATH="$tmp/bin:$PATH" FAKE_MODE=undated-page2 make -C "$root" data FORCE=1
grep -q '^read |' "$root/src/data/books"

# Feed text stays plain in data/JSON but is escaped before Smol renders HTML.
rm -rf "$root/data/raw"
PATH="$tmp/bin:$PATH" FAKE_MODE=markup-current make -C "$root" html FORCE=1
grep -Fq '<img src=x onerror=alert(1)>' "$root/src/data/books"
grep -Fq '<img src=x onerror=alert(1)>' "$root/public/books.json"
grep -Fq '&lt;img src=x onerror=alert(1)&gt;' "$root/public/books/index.html"
if grep -Fq '<img src=x onerror=alert(1)>' "$root/public/books/index.html"; then
  printf '%s\n' 'site test: Goodreads markup reached generated HTML unescaped' >&2
  exit 1
fi

rm -rf "$root/data/raw"
PATH="$tmp/bin:$PATH" FAKE_MODE=markup-read make -C "$root" html FORCE=1
grep -Fq '&lt;svg onload=alert(2)&gt;' "$root/public/books/index.html"
if grep -Fq '<svg onload=alert(2)>' "$root/public/books/index.html"; then
  printf '%s\n' 'site test: read-shelf markup reached generated HTML unescaped' >&2
  exit 1
fi

rm -rf "$root/data/raw"
PATH="$tmp/bin:$PATH" FAKE_MODE=markup-to-read make -C "$root" html FORCE=1
grep -Fq '&lt;iframe src=evil&gt;' "$root/public/books/index.html"
if grep -Fq '<iframe src=evil>' "$root/public/books/index.html"; then
  printf '%s\n' 'site test: to-read markup reached generated HTML unescaped' >&2
  exit 1
fi

# Build the complete site from deterministic fixtures in the copied workspace.
PATH="$tmp/bin:$PATH" FAKE_MODE=normal make -C "$root" html FORCE=1
"$root/scripts/smoke.sh"

books="$root/public/books/index.html"
index="$root/public/index.html"
pax="$root/public/pax/index.html"
snake="$root/public/projects/snake/index.html"

current_section=$(awk '/Currently reading/{found=1} found{print} found && /<\/section>/{exit}' "$books")
if printf '%s\n' "$current_section" | grep -q '<li'; then
  printf '%s\n' 'site test: expected empty currently-reading section' >&2
  exit 1
fi

grep -q '1 books · 200 pages' "$books"

grep -q 'Co-founder &amp; CTO at' "$index"
grep -q 'exploring how AI changes what ambitious teams can build.' "$index"
grep -q '<title>Chris Kjær | Co-founder and CTO at Landfolk</title>' "$index"

grep -q 'rel=canonical href=https://chriskjaer.com/' "$index"
grep -q 'property=og:url content=https://chriskjaer.com/' "$index"
grep -q 'rel=canonical href=https://chriskjaer.com/books/' "$books"
grep -q 'property=og:url content=https://chriskjaer.com/books/' "$books"

test -s "$snake"
test -s "$root/public/snake.wasm"
if grep -q 'href=/projects/snake' "$index"; then
  printf '%s\n' 'site test: home page should not list every project' >&2
  exit 1
fi
grep -q 'href=/projects/snake/' "$pax"
grep -q '<title>Snake — projects — chriskjaer</title>' "$snake"
grep -q 'rel=canonical href=https://chriskjaer.com/projects/snake/' "$snake"
grep -q 'property=og:url content=https://chriskjaer.com/projects/snake/' "$snake"
grep -q 'id=snake-screen' "$snake"
grep -q 'aria-label="Snake controls"' "$snake"
grep -q 'class="control up"' "$snake"
grep -q '\.control\.up' "$snake"
grep -q 'event.target.closest("button")' "$snake"
grep -q 'prefers-reduced-motion: reduce' "$snake"
grep -q 'devicePixelRatio' "$snake"
grep -Eq 'const glyphs[[:space:]]*=' "$snake"
if grep -q 'fillText(' "$snake"; then
  printf '%s\n' 'site test: Snake LCD uses antialiased canvas text' >&2
  exit 1
fi
grep -q 'env(safe-area-inset-top)' "$snake"
grep -q 'viewport-fit=cover' "$snake"
grep -q 'https://chriskjaer.com/projects/snake/' "$root/public/sitemap.xml"

printf '%s\n' 'site test ok'
