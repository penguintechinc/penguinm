.PHONY: install-hooks verify-hooks setup

## Install pre-commit framework + register pre-commit and pre-push hooks
install-hooks:
	@./scripts/install-pre-commit.sh

## Report whether pre-commit/pre-push hooks are installed and non-empty
verify-hooks:
	@./scripts/install-pre-commit.sh --verify

## Full local dev environment setup
setup: install-hooks
