# ==============================================================================
# MacDownloader - Native macOS Download Manager Makefile
# ==============================================================================

APP_NAME = MacDownloader
BUNDLE_ID = com.macdownloader.app
VERSION = 1.2.1
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
MACOS_DIR = $(APP_BUNDLE)/Contents/MacOS
RESOURCES_DIR = $(APP_BUNDLE)/Contents/Resources

SWIFT_FLAGS = --disable-sandbox

export TMPDIR = $(CURDIR)/.tmp
export CLANG_MODULE_CACHE_PATH = $(CURDIR)/.cache/clang
export SWIFTPM_MODULECACHE_OVERRIDE = $(CURDIR)/.cache/swiftpm

.PHONY: all build test run app zip dmg clean release help

all: build

## help: Print available targets
help:
	@echo "========================================================================"
	@echo "MacDownloader - Build & Automation System"
	@echo "========================================================================"
	@echo "  make build      - Build release binary"
	@echo "  make test       - Run all unit and integration tests"
	@echo "  make run        - Build and run the macOS SwiftUI application"
	@echo "  make app        - Package and sign release binary into MacDownloader.app bundle"
	@echo "  make zip        - Create clean zip archive of MacDownloader.app"
	@echo "  make dmg        - Create drag-and-drop DMG installer for macOS"
	@echo "  make clean      - Remove build artifacts and caches"
	@echo "  make release    - Run test suite and assemble release .app, .zip, and .dmg"
	@echo "  make help       - Display this help message"
	@echo "========================================================================"

## build: Compile release binary using SwiftPM
build:
	@echo "==> Building $(APP_NAME) (release)..."
	swift build -c release $(SWIFT_FLAGS)

## test: Run all tests
test:
	@echo "==> Running MacDownloader test suite..."
	swift test $(SWIFT_FLAGS)

## run: Run the application
run:
	@echo "==> Launching $(APP_NAME)..."
	swift run $(SWIFT_FLAGS) $(APP_NAME)

## app: Package into standalone macOS Application (.app) and code-sign
app: build
	@echo "==> Creating macOS Application Bundle at $(APP_BUNDLE)..."
	@mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)"
	@cp -f ".build/release/$(APP_NAME)" "$(MACOS_DIR)/$(APP_NAME)"
	@chmod +x "$(MACOS_DIR)/$(APP_NAME)"
	@cp -f Resources/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	@if [ -f Resources/AppIcon.icns ]; then cp -f Resources/AppIcon.icns "$(RESOURCES_DIR)/AppIcon.icns"; fi
	@echo "==> Signing application bundle (ad-hoc)..."
	@codesign --force --deep --sign - "$(APP_BUNDLE)"
	@echo "==> Application bundle successfully created and signed at $(APP_BUNDLE)"

## zip: Package the .app into a clean zip file for distribution
zip: app
	@echo "==> Creating zip archive for release..."
	@cd $(BUILD_DIR) && rm -f "$(APP_NAME)-v$(VERSION)-macOS.zip" && zip -r -y -X "$(APP_NAME)-v$(VERSION)-macOS.zip" "$(APP_NAME).app"
	@echo "==> Zip archive created at $(BUILD_DIR)/$(APP_NAME)-v$(VERSION)-macOS.zip"

## dmg: Package the .app into a DMG installer
dmg: app
	@echo "==> Creating DMG installer..."
	@rm -rf "$(BUILD_DIR)/dmg_temp"
	@mkdir -p "$(BUILD_DIR)/dmg_temp"
	@cp -R "$(APP_BUNDLE)" "$(BUILD_DIR)/dmg_temp/"
	@ln -s /Applications "$(BUILD_DIR)/dmg_temp/Applications"
	@rm -f "$(BUILD_DIR)/$(APP_NAME)-v$(VERSION)-macOS.dmg"
	@hdiutil create -volname "$(APP_NAME)" -srcfolder "$(BUILD_DIR)/dmg_temp" -ov -format UDZO "$(BUILD_DIR)/$(APP_NAME)-v$(VERSION)-macOS.dmg"
	@rm -rf "$(BUILD_DIR)/dmg_temp"
	@echo "==> DMG created at $(BUILD_DIR)/$(APP_NAME)-v$(VERSION)-macOS.dmg"

## clean: Remove all build outputs
clean:
	@echo "==> Cleaning build artifacts..."
	@rm -rf .build "$(BUILD_DIR)" .cache .tmp
	@echo "==> Clean complete."

## release: Test and build .app bundle, zip, and dmg
release: test zip dmg
	@echo "========================================================================"
	@echo "==> Release bundle:  $(APP_BUNDLE)"
	@echo "==> Release zip:     $(BUILD_DIR)/$(APP_NAME)-v$(VERSION)-macOS.zip"
	@echo "==> Release DMG:     $(BUILD_DIR)/$(APP_NAME)-v$(VERSION)-macOS.dmg"
	@echo "========================================================================"
