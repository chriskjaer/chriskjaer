### Personal Website.

This will probably always be a work in progress; I never stop bikeshedding and I
somehow keep overengineering even the simplest things.

Common tasks live behind `make`:
- `make data` fetches Goodreads RSS + writes `src/data/books`.
- `make html` builds + minifies HTML into `public/` (depends on `data`).
- `make build` alias for `make html`.
- `make dev` starts a local server and rebuilds on changes.
- `make smoke` runs quick checks against `public/` output.
- `make clean` removes generated HTML.
- `make test` runs Smol regressions and a fixture-backed full-site build.
- `make fmt` normalizes indentation and trims trailing whitespace in smol files.
- `make lint` runs `shellcheck` + `shfmt` when installed (otherwise warns).
- `make doctor` prints tool versions + sanity checks.
- `make cf-tail` tails Cloudflare Pages failing logs (requires env vars).

Books page:
- Requirements: POSIX shell, `awk`, and standard Unix tools. No language runtime install.
- Source: Goodreads shelves `read`, `to-read`, `currently-reading`.
- Fetch/transform: `scripts/fetch_books_rows.sh` validates and parses each RSS
  page into normalized rows. `make data` stages all three shelves in one temporary
  generation and atomically publishes only a complete combined dataset.
- Parser: `scripts/goodreads_rss_to_rows.awk` rejects malformed, oversized,
  DTD/entity-bearing, wrong-shelf, or unexpectedly namespaced XML before
  emitting rows. Only Goodreads' Atom link and XHTML meta elements are allowed.
- Goodreads text stays plain in data/JSON and is HTML-escaped at the Smol
  rendering boundary.
- JSON: `scripts/books_json.sh` converts `src/data/books` into `public/books.json`.
- Wrapper: `scripts/goodreads_sync.sh` runs fetch+transform (manual use).
- An empty `currently-reading` shelf is valid; failures for the required
  `read` and `to-read` shelves still stop the sync.

Deployment hygiene:
- `public/robots.txt`, `public/sitemap.xml`, and `public/404.html` are static.
- `public/_redirects` sends legacy `/favicon.ico` requests to the SVG favicon.
- GitHub Actions runs tests and non-mutating shell lint on pull requests.
- A weekly scheduled workflow creates an empty refresh commit so Cloudflare Pages
  rebuilds the Goodreads-backed book list even when the site code is unchanged.

Smol is a tiny HAML-ish markup language compiled by `scripts/smol.awk`. The
site templates live in `src/` (for example `src/index.smol` and `src/books.smol`)
and compile into `public/`. Shared partials live in `src/includes/`.
If you want syntax highlighting in Neovim, grab the smol syntax file from my
dotfiles here: https://github.com/chriskjaer/dotfiles/blob/master/common/config/nvim/syntax/smol.vim

Smol syntax overview:
- `tag` creates elements (preferred), with `.class` and `#id` sugar. `%tag` still works.
- Attributes go in parentheses, like `(key="value" other="value")`.
- Plain text uses `| some text` (bare words are tags now).
- Raw blocks use `:raw` or `:plain` for pass-through content.
- Comments start with `-#`.

Smol CSS lives inside any `style` block and follows the same indentation rules:
- Indent selectors and properties.
- Nest selectors with `&` (for example, `&:hover`).
- Start at-rules with `@media ...`.

Smol also has a tiny top-level DSL for wrapping the page and keeping things
compact:
- `:head` and `:body` become the document wrapper, so you can skip writing
  `<!doctype>`, `html`, `head`, and `body` by hand.
- `@title`, `@description`, `@viewport`, `@lang`, `@charset`, and `@meta(...)`
  generate the usual `<head>` tags for you.
- `@vars` lets you set multiple values at once, and `@set name value` is there
  for one-offs. Use `#{name}` to interpolate.
- `@include file.smol` drops another smol file in place (relative to the file
  doing the include). You can pass parameters inline like
  `@include includes/logo.smol logo_class=logo`.

Data + unixy pipelines:
- `@data "path" as name` loads a `|`-separated file into a dataset you can loop.
- You can also attach a pipeline: `@data "path" | awk ... | sort ... as name`.
  Smol runs `cat <path> | <pipeline>` and treats each output line as a row,
  splitting on `|` into fields.
- `@shell "cmd ..." as name` loads a dataset from a command’s stdout.
- `@for name as row` iterates the dataset; use `#{row.1}`, `#{row.2}` etc.
- `@if lhs == rhs` / `@if lhs != rhs` conditionally renders an indented block.

This is the preferred way to keep templates “unixy”: do transforms via shell
pipelines at build-time, and let Smol stay the layout engine.

Smol philosophy:
- Smol renders markup (tags, loops, includes).
- Unix tools shape data.
- If a template needs a capability Smol doesn’t have, extend/fix `scripts/smol.awk`
  and add a regression test in `scripts/smol_test.sh` rather than injecting HTML strings.

Example (from `src/books.smol`): group “Read” by year without writing
intermediate `.smol` files:

- `@shell "cat src/data/books | awk -F'|' -f scripts/books_read_years.awk | sort -r" as read_years`
- `@for read_years as y`
- `  @shell "cat src/data/books | awk -F'|' -v YEAR=#{y.value} -f scripts/books_read_for_year.awk | sort -t'|' -k1,1r" as read_books`
- `  @for read_books as book`
- `    @if book.2 != ""`
- `      | (#{book.1} · #{book.2})`

One small convenience: any `style` block found in the body is moved up into the
head, and any `script` block is moved to the end of the body.

Minify also strips a bit more: safe attribute quotes are removed and leading
indentation in text nodes is trimmed.

The favicon is a tiny SVG at `public/favicon.svg`, wired up in the head.

The background runs a tiny Game of Life in WebAssembly. The module is assembled
directly by `scripts/life_wasm.awk`, a deliberately tiny purpose-built WASM
compiler written in AWK. No Zig, `wat2wasm`, package manager, or extra runtime is
needed. The generated `public/life.wasm` is checked in so the page can fetch it
directly.

To rebuild it:
`make wasm` (or run `scripts/wasm_build.sh` directly).
