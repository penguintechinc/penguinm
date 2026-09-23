# penguinm — pub-workspace Flutter monorepo. See docs/superpowers/specs for
# the full design; targets below match spec §9 exactly.
.DEFAULT_GOAL := help
SHELL := /bin/bash

SCRIPTS := tooling/scripts

.PHONY: help setup install-hooks verify-hooks bootstrap lint format \
	test test-unit test-integration coverage test-security smoke-test \
	build-android docker-build new-app seed-mock-data clean pre-commit version

help: ## Show this help message
	@echo "penguinm make targets:"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' \
		| sort

setup: install-hooks ## Verify Flutter 3.44.8, dart pub get, melos bootstrap, install git hooks
	@echo "==> Checking flutter --version == 3.44.8"
	@v=$$(flutter --version --machine 2>/dev/null | grep -o '"frameworkVersion":"[^"]*"' | cut -d'"' -f4); \
	if [ "$$v" != "3.44.8" ]; then echo "ERROR: flutter --version is '$$v', expected 3.44.8" >&2; exit 1; fi; \
	echo "flutter $$v OK"
	dart pub get
	dart run melos bootstrap

install-hooks: ## Install pre-commit framework + register pre-commit and pre-push hooks
	@$(SCRIPTS)/install-pre-commit.sh

verify-hooks: ## Report whether pre-commit/pre-push hooks are installed and non-empty
	@$(SCRIPTS)/install-pre-commit.sh --verify

bootstrap: ## Resolve workspace dependencies via melos bootstrap
	dart run melos bootstrap

lint: ## dart format check + flutter analyze (zero infos/warnings) across the workspace
	dart format --set-exit-if-changed .
	dart run melos exec -- flutter analyze --fatal-infos

format: ## Apply dart format across the workspace
	dart format .

test: ## Run every package's test suite with --coverage (coverage/lcov.info per package)
	dart run melos exec -c 4 --dir-exists=test -- flutter test --coverage --timeout=60s

test-unit: ## Run unit tests only (test/, excludes integration_test/)
	dart run melos exec -c 4 --dir-exists=test -- flutter test --coverage --timeout=60s test/

test-integration: ## Run integration_test/ suites (requires a running Android emulator, API 35 x86_64)
	@echo "test-integration requires a connected Android emulator (API 35, x86_64); see docs/TESTING.md"
	dart run melos exec -c 4 --dir-exists=integration_test -- flutter test --timeout=60s integration_test/

coverage: test ## test + coverage-gate.sh (>=90% per package, fails on LF=0 or 0 packages)
	$(SCRIPTS)/coverage-gate.sh

test-security: ## gitleaks, trivy, osv-scanner, semgrep, zizmor, hadolint — every step's exit status propagates
	gitleaks detect --redact -v
	trivy fs --scanners vuln,misconfig,secret --exit-code 1 --skip-dirs .superpowers --skip-dirs "**/coverage" --skip-dirs "**/.dart_tool" --skip-dirs "**/build" .
	osv-scanner --lockfile pubspec.lock
	uvx semgrep@1.177.0 --config p/security-audit --config p/kotlin --config p/secrets --error --exclude .superpowers .
	zizmor .github/workflows
	hadolint --config .hadolint.yaml tooling/docker/Dockerfile.flutter-android

smoke-test: ## bootstrap + analyze + penguin_reference tests + telemetry-validate + check-pins + check-logging (<2 min)
	dart run melos bootstrap
	dart run melos exec -- flutter analyze --fatal-infos
	cd apps/penguin_reference && flutter test --timeout=60s
	$(SCRIPTS)/telemetry-validate.sh
	$(SCRIPTS)/check-pins.sh
	$(SCRIPTS)/check-logging.sh

build-android: ## Build an app inside the toolchain image. Vars: APP= FLAVOR=<dev|beta|prod> FORMAT=<apk|aab>
	@if [ -z "$(APP)" ] || [ -z "$(FLAVOR)" ]; then \
		echo "usage: make build-android APP=<app> FLAVOR=<dev|beta|prod> FORMAT=<apk|aab>" >&2; \
		exit 1; \
	fi
	$(SCRIPTS)/build-android.sh $(APP) $(FLAVOR) $(if $(FORMAT),$(FORMAT),apk)

docker-build: ## Build the penguinm/flutter-android:local toolchain image
	docker build -f tooling/docker/Dockerfile.flutter-android -t penguinm/flutter-android:local .

new-app: ## Scaffold a new app. Vars: NAME= PRODUCT= DISPLAY=
	@if [ -z "$(NAME)" ] || [ -z "$(PRODUCT)" ] || [ -z "$(DISPLAY)" ]; then \
		echo "usage: make new-app NAME=<snake_case_name> PRODUCT=<product_key> DISPLAY=<Display Name>" >&2; \
		exit 1; \
	fi
	$(SCRIPTS)/new-app.sh $(NAME) $(PRODUCT) "$(DISPLAY)"

seed-mock-data: ## Regenerate test/fixtures from penguin_testing generators (prints file counts)
	dart run melos exec --dir-exists=test -- dart run penguin_testing:seed_fixtures

clean: ## Remove build artifacts and coverage output across the workspace
	-dart run melos clean
	rm -rf build/artifacts
	find . -type d -name coverage -not -path '*/.dart_tool/*' -prune -exec rm -rf {} +

pre-commit: ## lint -> test-security -> smoke-test -> test -> coverage -> check-pins, stop on first failure
	@logdir=/tmp/pre-commit-penguinm-$$(date +%s); mkdir -p "$$logdir"; \
	{ \
		echo "== lint ==" && $(MAKE) lint && \
		echo "== test-security ==" && $(MAKE) test-security && \
		echo "== smoke-test ==" && $(MAKE) smoke-test && \
		echo "== test ==" && $(MAKE) test && \
		echo "== coverage ==" && $(MAKE) coverage && \
		echo "== check-pins ==" && $(SCRIPTS)/check-pins.sh ; \
	} 2>&1 | tee "$$logdir/summary.log"; \
	status=$${PIPESTATUS[0]}; \
	echo "pre-commit: log at $$logdir/summary.log (exit $$status)"; \
	exit $$status

version: ## Apply VERSION (+ epoch build) to every app pubspec
	$(SCRIPTS)/version.sh
