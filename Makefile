SHELL := /bin/sh

RAW_DIR := data/raw
BOOKS_DATA := src/data/books

RSS_READ := $(RAW_DIR)/books_read.rss
RSS_TO_READ := $(RAW_DIR)/books_to-read.rss
RSS_CURRENT := $(RAW_DIR)/books_currently-reading.rss

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

$(RAW_DIR):
	@mkdir -p "$@"

$(RSS_READ): scripts/fetch_books_rss.sh $(FORCE_DEP) | $(RAW_DIR)
	@./scripts/fetch_books_rss.sh read "$@"

$(RSS_TO_READ): scripts/fetch_books_rss.sh $(FORCE_DEP) | $(RAW_DIR)
	@./scripts/fetch_books_rss.sh to-read "$@"

$(RSS_CURRENT): scripts/fetch_books_rss.sh $(FORCE_DEP) | $(RAW_DIR)
	@./scripts/fetch_books_rss.sh currently-reading "$@"

$(BOOKS_DATA): scripts/lib.awk scripts/books_from_rss.awk $(RSS_READ) $(RSS_TO_READ) $(RSS_CURRENT)
	@mkdir -p "$(dir $@)"
	@tmp=$$(mktemp); \
	trap 'rm -f "$$tmp"' INT TERM HUP EXIT; \
	awk -v SHELF=read -v DATE_FIELD=read_at -f scripts/lib.awk -f scripts/books_from_rss.awk <"$(RSS_READ)" >>"$$tmp"; \
	awk -v SHELF=to-read -v DATE_FIELD=created -f scripts/lib.awk -f scripts/books_from_rss.awk <"$(RSS_TO_READ)" >>"$$tmp"; \
	awk -v SHELF=currently-reading -v DATE_FIELD=created -f scripts/lib.awk -f scripts/books_from_rss.awk <"$(RSS_CURRENT)" >>"$$tmp"; \
	LC_ALL=C sort "$$tmp" >"$@.tmp"; \
	mv "$@.tmp" "$@"; \
	printf '%s\n' "wrote $@" >&2

smoke: html
	@./scripts/smoke.sh

test:
	@./scripts/smol_test.sh

minify: html
	@./scripts/minify.sh

clean:
	@rm -f ./public/index.html ./public/books/index.html ./public/books.json

fmt:
	@./scripts/smol_fmt.sh

wasm:
	@./scripts/wasm_build.sh

FORCE:
