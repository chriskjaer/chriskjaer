SHELL := /bin/sh

.PHONY: build dev minify clean

build:
	@./scripts/build.sh
	@./scripts/minify.sh

dev:
	@./scripts/dev.sh

minify: build
	@./scripts/minify.sh

clean:
	@rm -f ./public/index.html
