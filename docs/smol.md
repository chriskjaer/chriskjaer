# Smol

Smol is a tiny indentation-based markup language compiled to HTML by `scripts/smol.awk`.

It’s intentionally small.
Not “minimal for its own sake”, but small enough that you can hold it in your head.

This doc is written from the inside: how I (Pax) think about Smol, why it’s shaped the way it is, and how to use it without fighting it.

## Philosophy

Smol has one job: **describe a small component clearly**.

Most blocks render markup. An explicit output block such as `@wasm` may also
compile a sidecar artifact owned by that component.

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
- Directives (lines starting with `@`) do “meta things”: set variables, load data, loop, include, etc.
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
    h1 | Hello
    p | This was written in Smol.
```

Plain text uses `|`:

```smol
p | This is text.
```

(And if you want multiple lines, just indent them.)

## Tags, Classes, IDs

Smol tags look like HTML tag names:

```smol
main
  section
    h2 | Title
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

The layout uses `@yield` to drop your sections into place.

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

`@data` loads a `|`-separated file into a dataset:

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

### Emitting file contents

If you omit `as name`, `@data` behaves more like shell: it **emits** the file contents (or the piped result) directly into the template.

```smol
div.markdown
  @data "../docs/pax.md" | ../../scripts/md_to_html.awk
```

This is the pattern used on `/pax`: keep the content in a file, pipe it through a tiny build-time transformer, and insert the result.

### Looping

```smol
ul
  @for read_books as b
    li
      | #{b.5} — #{b.6}
```

If the dataset has one field per row, Smol also exposes `row.value`.

## Conditionals

Use `@if` to conditionally render an indented block:

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

## WebAssembly Sidecars

A component can own a small WebAssembly module alongside its markup and
browser code:

```smol
@wasm counter as counter_wasm
  @vars
    memory_pages 1
    value_address 0

  @memory memory_pages
    @state value at value_address

  @export memory

  @func increment amount:i32 export
    @set value = value + amount

  @func current -> i32 export
    @return value

script
  :raw
    const response = await fetch("#{counter_wasm}");
    const { instance } = await WebAssembly.instantiate(
      await response.arrayBuffer(),
      {}
    );
```

The header is always:

```smol
@wasm module_name as binding_name
```

It means:

- The indented body is module source, not HTML.
- `binding_name` becomes `/<module_name>.wasm` for later interpolation.
- The build writes `public/<module_name>.wasm`.
- The module may live in any rendered `.smol` page or include.
- Module names and bindings must be identifiers: letters, numbers, and
  underscores, not paths.
- Every module name must have one source declaration. The component containing
  it may be included by several entrypoints; that reuses the same module.
- A module cannot be declared or included inside template `@for` or `@if`
  blocks. Module discovery never depends on data or conditional rendering.

Blank lines are optional. Two spaces own each scope, just like ordinary Smol.
Do not interpolate template variables inside the module body; use module
`@vars` instead.

### Module declarations

Declarations come before the first function:

```smol
@wasm example as example_wasm
  @vars
    memory_pages 1
    count_address 0
    values_address 4
    scale:f32 1

  @memory memory_pages
    @state count at count_address
    @array values at values_address

  @export memory
```

- `@vars` contains integer constants by default. Add `:f32` for a float
  constant.
- `@memory pages` declares one linear memory.
- `@state name at address_constant` declares a named 32-bit state value.
- `@array name at address_constant` declares a named byte array.
- `@export memory` exports the module memory.

The memory block may only contain `@state` and `@array`. Constants, memory,
state, arrays, exports, and functions share one module namespace. Parameters
and locals may not shadow module names.

### Functions and exports

```smol
@func helper value:i32 -> i32
  @return value + 1

@func public_value value:i32 -> i32 export
  @return value + 1
```

Parameters are written as `name:i32` or `name:f32`. Add `-> i32` or `-> f32`
for a result. Add `export` at the end to make the function public. Functions
without `export` stay private.

Supported statements:

```smol
@let total:i32 = 0
@set total = total + 1
@set state_name = total
@set bytes[index] = 1
@return total
@return if total == 0
@for index in 0 .. count
  @set total = total + bytes[index]
@while total <u limit
  @set total = total + 1
```

`@for` is an ascending, signed, half-open range. `-2 .. 3` visits five values;
`2 .. 0` visits none. `@return` is a real early return.

Expressions support parentheses and these operators:

- Boolean: `or`, `and`
- Equality: `==`, `!=`
- Unsigned integers: `<u`, `>u`, `<=u`
- Floats: `<f`, `>f`, `*f`
- Integers: `+`, `-`, `*`, `%s`, `>>s`

Available helpers are deliberately few:

- `u32(float)` converts a float with saturating unsigned semantics.
- `max_u(a, b)` chooses the unsigned maximum.
- `choose(condition, yes, no)` selects without branching.
- `wrap(value, size)` wraps a signed coordinate into a positive range.

This is intentionally not general WAT. Extend the subset only when a real
module needs a feature, and add frontend, backend, and runtime regression tests
with it.

### Compilation and failure behavior

The pipeline remains split internally:

```text
.smol component
  -> scripts/smol.awk extracts @wasm
  -> scripts/wasmol_front.awk lowers expressions and scopes
  -> scripts/wasmol.awk validates stack/types and emits bytes
  -> public/<name>.wasm
```

Run `make wasm` to rebuild embedded modules, or `make test` for all compiler
regressions. The build stages every module before publishing any of them. A bad
module returns non-zero and preserves the previous checked-in artifact. After a
successful build, public `.wasm` files without a current Smol declaration are
removed, so renaming or deleting a module cannot leave a deployable ghost.

## Where Things Live

- Markup/sidecar dispatcher: `scripts/smol.awk`
- WASM lowering: `scripts/wasmol_front.awk`
- Validated WASM byte emitter: `scripts/wasmol.awk`
- Tests: `scripts/smol_test.sh` and `scripts/wasm_test.sh`
- Templates and embedded modules: `src/**/*.smol`
- Partials/components: `src/includes/*.smol`
- Built HTML and WASM: `public/` (generated)

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
