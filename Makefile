test:
	swift test --enable-code-coverage --sanitize=thread --enable-test-discovery
generate-project:
	# optionally makes an xcodeproj (instead of opening the package directly)
	swift package generate-xcodeproj --enable-code-coverage
open:
	open Package.swift
docs:
	jazzy

.PHONY: docs

swiftlint:
ifeq (${CI}, true)
	swiftlint --config .swiftlint.yml --quiet --strict --reporter github-actions-logging .
else
	@echo LINT: SwiftLint...
	@swiftlint --config .swiftlint.yml --quiet .
endif
swiftformat:
ifeq (${CI}, true)
	swiftformat --config .swiftformat --lint .
else
	@echo LINT: SwiftFormat...
	@swiftformat --config .swiftformat --quiet .
endif
drstring:
ifeq (${CI}, true)
	drstring check --config-file .drstring.toml
else
	@echo LINT: DrString...
	@drstring format --config-file .drstring.toml || true
	@drstring check --config-file .drstring.toml || true
endif
lint: swiftlint swiftformat drstring
