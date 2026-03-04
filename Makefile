.PHONY: build run clean app

build:
	swift build

run:
	swift run PulseMon

clean:
	swift package clean

app: build
	@echo "Creating PulseMon.app bundle..."
	@mkdir -p PulseMon.app/Contents/MacOS
	@mkdir -p PulseMon.app/Contents/Resources
	@cp Info.plist PulseMon.app/Contents/
	@cp .build/debug/PulseMon PulseMon.app/Contents/MacOS/
	@echo "PulseMon.app created successfully"

release:
	swift build -c release
	@mkdir -p PulseMon.app/Contents/MacOS
	@mkdir -p PulseMon.app/Contents/Resources
	@cp Info.plist PulseMon.app/Contents/
	@cp .build/release/PulseMon PulseMon.app/Contents/MacOS/
	@echo "PulseMon.app (release) created successfully"
