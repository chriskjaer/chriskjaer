SHELL := /bin/sh

BOOKS_DATA := src/data/books

FORCE_DEP :=
ifeq ($(FORCE),1)
FORCE_DEP := FORCE
endif

.PHONY: build dev data html smoke test minify clean fmt lint doctor cf-tail wasm FORCE

build: html

lint:
	@./scripts/lint.sh

doctor:
	@./scripts/doctor.sh

cf-tail:
	@./scripts/cf_tail_pages.sh

html: data
	@./scripts/build.sh
	@./scripts/minify.sh

dev:
	@./scripts/dev.sh

data: $(BOOKS_DATA)

$(BOOKS_DATA): scripts/fetch_books_rows.sh scripts/goodreads_rss_to_rows.awk $(FORCE_DEP)
	@mkdir -p "$(dir $@)"
	@set -e; \
	generation=$$(mktemp -d "$(dir $@).books-generation.XXXXXX"); \
	trap 'rm -rf "$$generation"' INT TERM HUP EXIT; \
	./scripts/fetch_books_rows.sh read "$$generation/read.rows"; \
	./scripts/fetch_books_rows.sh to-read "$$generation/to-read.rows"; \
	./scripts/fetch_books_rows.sh currently-reading "$$generation/currently-reading.rows"; \
	tmp="$$generation/books"; \
	cat "$$generation/read.rows" "$$generation/to-read.rows" "$$generation/currently-reading.rows" >"$$tmp"; \
	awk -F'|' 'NF != 6 { exit 1 }' "$$tmp" || { printf '%s\n' 'invalid generated book row' >&2; exit 1; }; \
	grep -q '^read |' "$$tmp" || { printf '%s\n' 'missing required read shelf' >&2; exit 1; }; \
	grep -q '^to-read |' "$$tmp" || { printf '%s\n' 'missing required to-read shelf' >&2; exit 1; }; \
	LC_ALL=C sort -o "$$tmp" "$$tmp"; \
	mv "$$tmp" "$@"; \
	printf '%s\n' "wrote $@" >&2

smoke: html
	@./scripts/smoke.sh

test:
	@./scripts/smol_test.sh
	@./scripts/wasm_test.sh
	@./scripts/site_test.sh

minify: html
	@./scripts/minify.sh

clean:
	@rm -f ./public/index.html ./public/books/index.html ./public/pax/index.html ./public/pax/avatar.jpg ./public/projects/smol/index.html ./public/projects/snake/index.html ./public/books.json

fmt:
	@./scripts/smol_fmt.sh

wasm:
	@./scripts/wasm_build.sh

FORCE:
