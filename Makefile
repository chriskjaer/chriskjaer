SHELL := /bin/sh

.PHONY: build dev minify clean test fmt wasm

build:
	@./scripts/build.sh
	@./scripts/minify.sh

dev:
	@./scripts/dev.sh

minify: build
	@./scripts/minify.sh

clean:
	@rm -f ./public/index.html ./public/books/index.html

test:
	@./scripts/smol_test.sh

fmt:
	@./scripts/smol_fmt.sh

wasm:
	@./scripts/wasm_build.sh
