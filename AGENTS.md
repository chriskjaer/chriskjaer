# Agent Instructions (repo)

## Read me first
- Read `README.md` before making changes.

## Smol philosophy (important)
- Smol is the layout engine. Templates should render markup using Smol tags, loops, includes.
- Shell/unix tools are for *data shaping* only.
- Do **not** emit HTML strings from `awk`/shell and inject them into templates.
- If Smol lacks a feature (nesting semantics, directives, etc.), fix `scripts/smol.awk` and add a regression test in `scripts/smol_test.sh`.

## Hygiene
- Avoid raw `@...` in PR/commit messages; wrap in backticks or escape (e.g. ``\@for``).
