test:
	swift test --enable-code-coverage --sanitize=thread --enable-test-discovery
generate-project:
	# optionally makes an xcodeproj (instead of opening the package directly)
	swift package generate-xcodeproj --enable-code-coverage
open:
	open Package.swift

swiftlint:
	@echo LINT: SwiftLint...
	@swiftlint --config .swiftlint.yml --quiet .
swiftformat:
	@echo LINT: SwiftFormat...
	@swiftformat --config .swiftformat --quiet .
	@echo Done!
lint: swiftlint swiftformat
