SHELL := /bin/bash
SRC := src/bibby-latex.sh install.sh $(wildcard src/lib/*.sh)

.PHONY: help lint test syntax install uninstall doctor pack clean

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[1m%-12s\033[0m %s\n", $$1, $$2}'

syntax: ## bash -n every script
	@for f in $(SRC); do bash -n $$f && echo "ok  $$f"; done
	@python3 -m py_compile cloud/bibby_cloud.py src/lib/merge_settings.py && echo "ok  python"
	@node --check bin/bibby-latex.js && echo "ok  bin/bibby-latex.js"

lint: ## shellcheck (needs shellcheck installed)
	@shellcheck -S warning $(SRC)

test: syntax ## syntax + smoke test
	@bash test/smoke.sh

install: ## run the installer from this checkout
	@bash src/bibby-latex.sh

doctor: ## diagnose this machine
	@bash src/bibby-latex.sh --doctor

uninstall: ## remove TinyTeX + PATH entry
	@bash src/bibby-latex.sh --uninstall

pack: ## build the npm tarball
	@npm pack

clean:
	@rm -f *.tgz
	@find . -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
