# Agent Instructions (repo)

## Read me first
- Read `README.md` before making changes.

## Smol philosophy (important)
- Smol describes components. It renders markup by default and may own explicit sidecars such as an embedded `@wasm` module.
- Shell/unix tools are for *data shaping* only.
- Do **not** emit HTML strings from `awk`/shell and inject them into templates.
- If Smol lacks a feature (nesting semantics, directives, etc.), fix `scripts/smol.awk` and add a regression test in `scripts/smol_test.sh`.

## Runtime constraint (important)
- Do not add implementation languages or runtime/build dependencies.
- The site must build in a normal shell with the existing shell, `awk`, and standard Unix tools. This portability is a core reason the repo exists, even when another language would make a task easier.
- Game of Life lives with its markup and loader in the `@wasm life` block in `src/includes/life.smol`. Any rendered `.smol` component may own one source declaration for a named `@wasm name as binding` sidecar; reusable entrypoints may include that same declaration. Sidecars are static and may not appear directly or through an include inside template `@for` or `@if`. Keep the module subset deliberately small; extend both AWK compiler stages only when real source needs another WebAssembly feature, and do not replace them with another implementation language or a general WASM toolchain.

## Hygiene
- Avoid raw `@...` in PR/commit messages; wrap in backticks or escape (e.g. ``\@for``).
