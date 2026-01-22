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
- `make test` runs a small sanity check for smol.
- `make fmt` normalizes indentation and trims trailing whitespace in smol files.
- `make lint` runs `shellcheck` + `shfmt` when installed (otherwise warns).
- `make doctor` prints tool versions + sanity checks.
- `make cf-tail` tails Cloudflare Pages failing logs (requires env vars).

Books page:
- Source: Goodreads shelves `read`, `to-read`, `currently-reading`.
- Fetch: `scripts/fetch_books_rss.sh` downloads shelf RSS into `data/raw/`.
- Transform: `scripts/books_from_rss.awk` converts RSS into `src/data/books` rows.
- JSON: `scripts/books_json.sh` converts `src/data/books` into `public/books.json`.
- Wrapper: `scripts/goodreads_sync.sh` runs fetch+transform (manual use).

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

One small convenience: any `style` block found in the body is moved up into the
head, and any `script` block is moved to the end of the body.

Minify also strips a bit more: safe attribute quotes are removed and leading
indentation in text nodes is trimmed.

The favicon is a tiny SVG at `public/favicon.svg`, wired up in the head.

The background runs a tiny Game of Life in WebAssembly, compiled from
`src/wasm/life.zig`. The build drops `public/life.wasm`, so the page fetches it at
runtime and Cloudflare doesn’t need Zig.

To refresh the wasm:
`make wasm` (or run `scripts/wasm_build.sh` directly).
