### Personal Website.

This will forever be a work in progress as I'll never stop bikeshedding and
overengineer this stuff.

Build: `make build` (compiles `index.smol` -> `public/index.html`).
Dev: `make dev` (starts server, opens browser, watches `index.smol` + compiler).
Minify: `make minify` (shrinks `public/index.html`).
Clean: `make clean` (removes `public/index.html`).
Test: `make test` (sanity check for smol).

Smol:
- Tiny HAML-ish markup compiled by `scripts/smol.awk`.
- One file source: `index.smol` -> `public/index.html`.
- `%tag` with `.class` / `#id` sugar.
- Attributes: `(key="value" key2="value")`.
- Plain text: `| some text`.
- Raw blocks: `:raw` / `:plain` (pass-through).
- Comments: `-# ...`.

Smol CSS:
- Use `%style` with indented selectors + properties (any `%style` uses smol CSS).
- Nested selectors: prefix with `&` (example: `&:hover`).
- At-rules: start line with `@media ...`.
