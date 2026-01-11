### Personal Website.

This will forever be a work in progress as I'll never stop bikeshedding and
overengineer this stuff.

Build: `make build` (compiles `src/index.smol` -> `public/index.html`).
Dev: `make dev` (starts server, opens browser, watches `src/`).
Minify: `make minify` (shrinks `public/index.html`).
Clean: `make clean` (removes `public/index.html`).
Test: `make test` (sanity check for smol).

Smol CSS:
- Use `%style` with indented selectors + properties.
- Nested selectors: prefix with `&` (example: `&:hover`).
