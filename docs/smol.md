# Smol

Smol is a tiny indentation-based markup language compiled to HTML by `scripts/smol.awk`.

It’s intentionally small.
Not “minimal for its own sake”, but small enough that you can hold it in your head.

This doc is written from the inside: how I (Pax) think about Smol, why it’s shaped the way it is, and how to use it without fighting it.

## Philosophy

Smol has one job: **render markup**.

Unix tools have a different job: **shape data**.

That split is the whole point:

- Smol templates should look like layout.
- Shell pipelines should do grouping, sorting, filtering, counting.
- If Smol is missing a layout feature, we extend Smol itself instead of injecting giant HTML strings from shell.

Why?

- **Templates stay readable.** You see structure, not string soup.
- **Data transforms stay testable.** They’re just scripts/pipelines.
- **The build stays deterministic.** Everything happens at compile-time.

## Mental Model

A `.smol` file is compiled line-by-line.

- Indentation creates nesting.
- Tags are emitted as HTML elements.
- Directives (lines starting with `\@`) do “meta things”: set variables, load data, loop, include, etc.
- Some blocks are special (like `style` and `script`).

Smol also has an “autowrap” convenience:

- `:head` and `:body` become the document wrapper.
- You can write a page as `:body ...` and Smol will generate the doctype + html/head/body.

## Quick Start

A minimal page:

```smol
@title Hello
@description A tiny page
@viewport width=device-width, initial-scale=1
@lang en
@charset utf-8

:body
  main
    h1
      | Hello
    p
      | This was written in Smol.
```

Plain text uses `|`:

```smol
p
  | This is text.
```

## Tags, Classes, IDs

Smol tags look like HTML tag names:

```smol
main
  section
    h2
      | Title
```

You can add classes and ids with sugar:

```smol
div.card
  | …

nav#top
  | …
```

Attributes go in parentheses:

```smol
a(href="/books" rel="me") Books
img(src="/pax/avatar.jpg" alt="Pax")
```

## Layouts and Includes

### Layout

Use a layout to avoid repeating the document skeleton:

```smol
@layout "includes/layout.smol"

@title My page

:body
  main
    | …
```

The layout uses `\@yield` to drop your sections into place.

### Include

Includes are like partials:

```smol
@include includes/logo.smol
```

Includes can take parameters:

```smol
@include includes/logo.smol logo_class=logo
```

Inside the include, use `#{logo_class}`.

## Variables

Set a variable:

```smol
@set name "Pax"

p
  | Hi, #{name}
```

Or set many at once:

```smol
@vars
  name "Pax"
  site_url https://chriskjaer.com
```

Variables interpolate with `#{...}`.

## Data and Loops

Smol can load datasets and iterate them.

### Loading data from a file

`\@data` loads a `|`-separated file into a dataset:

```smol
@data "src/data/books" as books
```

Each line becomes a row, fields are `row.1`, `row.2`, etc.

### Shaping data with a pipeline

You can attach a pipeline (this is the “unix shapes data” part):

```smol
@data "src/data/books" | awk -F'|' '$1=="read" {print $0}' | sort -t'|' -k2,2r as read_books
```

Smol runs `cat <file> | <pipeline>` and reads stdout as the dataset.

### Looping

```smol
ul
  @for read_books as b
    li
      | #{b.5} — #{b.6}
```

If the dataset has one field per row, Smol also exposes `row.value`.

## Conditionals

Use `\@if` to conditionally render an indented block:

```smol
@if book.2 != ""
  | (#{book.1} · #{book.2})
```

Smol supports `==` and `!=`.

## Shell

Shell can be used in two ways.

### 1) Load a dataset

When you end with `as name`, it loads a dataset you can loop:

```smol
@shell "cat src/data/books | awk -F'|' '{print $5}'" as titles

@for titles as t
  | #{t.value}
```

### 2) Emit stdout directly

When you don’t use `as`, Smol inserts the command’s stdout directly into the page:

```smol
div.markdown
  @shell "../scripts/md_to_html.awk ../docs/pax.md"
```

This is powerful.
It also means you’re responsible for what you emit (it’s inserted raw).

## Raw Blocks

Sometimes you want to pass content through exactly as written.
Use `:raw` or `:plain`:

```smol
script
  :raw
    console.log("hi")
```

## CSS and JS

A `style` block inside the body is moved into the head.
A `script` block is moved to the end of the body.

CSS is indentation-based and supports simple nesting with `&`:

```smol
style
  a
    color: #d86738
    &:hover
      opacity: .9
```

## Where Things Live

- Compiler: `scripts/smol.awk`
- Tests: `scripts/smol_test.sh`
- Templates: `src/*.smol`
- Partials: `src/includes/*.smol`
- Built output: `public/` (generated)

## Extending Smol

Smol is small enough that the “right” fix is often to improve the compiler.

Rule of thumb:

- If you need a new way to **render structure**, extend Smol.
- If you need a new way to **transform data**, add a script or pipeline.

When you change the compiler, add a regression test in `scripts/smol_test.sh`.

## Debugging Tips

- Run `make test` to validate the compiler behavior.
- Run `make smoke` to ensure generated HTML looks sane.
- If you’re debugging data pipelines, `SMOL_DEBUG_DATA=1` will print dataset load commands.

## A Note From Pax

Smol isn’t trying to be everything.
It’s trying to be a small place where structure stays honest.

When it works, the template reads like a page.
And when it breaks, it breaks in ways you can fix.
