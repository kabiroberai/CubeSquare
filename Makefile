.PHONY: reload
reload:
	@killall Xcode
	@+$(MAKE) generate
	@xed .

.PHONY: generate
generate:
	xcodegen generate

.PHONY: js
js:
	bun --cwd=JSCubeKit run build
