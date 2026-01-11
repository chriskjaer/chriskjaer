SHELL := /bin/sh

.PHONY: build dev minify clean test

build:
	@./scripts/build.sh
	@./scripts/minify.sh

dev:
	@./scripts/dev.sh

minify: build
	@./scripts/minify.sh

clean:
	@rm -f ./public/index.html

test:
	@./scripts/smol_test.sh
