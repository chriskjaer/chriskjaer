### Personal Website.

This will probably always be a work in progress; I never stop bikeshedding and I
somehow keep overengineering even the simplest things.

Common tasks live behind `make`:
- `make build` compiles `index.smol` into `public/index.html`.
- `make dev` starts a local server, opens the page, and rebuilds on changes.
- `make minify` shrinks `public/index.html`.
- `make clean` removes `public/index.html`.
- `make test` runs a small sanity check for smol.

Smol is a tiny HAML-ish markup language compiled by `scripts/smol.awk`. The
entire site lives in `index.smol`, which becomes `public/index.html`.
If you want syntax highlighting in Neovim, grab the smol syntax file from my
dotfiles here: https://github.com/chriskjaer/dotfiles/blob/master/common/config/nvim/syntax/smol.vim

Smol syntax overview:
- `%tag` creates elements, with `.class` and `#id` sugar.
- Attributes go in parentheses, like `(key="value" other="value")`.
- Plain text uses `| some text`.
- Raw blocks use `:raw` or `:plain` for pass-through content.
- Comments start with `-#`.

Smol CSS lives inside any `%style` block and follows the same indentation rules:
- Indent selectors and properties.
- Nest selectors with `&` (for example, `&:hover`).
- Start at-rules with `@media ...`.
