# ==============================================================================
# MacDownloader - Native macOS Download Manager Makefile
# ==============================================================================

APP_NAME = MacDownloader
BUNDLE_ID = com.macdownloader.app
VERSION = 1.0.0
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
MACOS_DIR = $(APP_BUNDLE)/Contents/MacOS
RESOURCES_DIR = $(APP_BUNDLE)/Contents/Resources

SWIFT_FLAGS = --disable-sandbox

export TMPDIR = $(CURDIR)/.tmp
export CLANG_MODULE_CACHE_PATH = $(CURDIR)/.cache/clang
export SWIFTPM_MODULECACHE_OVERRIDE = $(CURDIR)/.cache/swiftpm

.PHONY: all build test run app clean release help


all: build

## help: Print available targets
help:
	@echo "========================================================================"
	@echo "MacDownloader - Build & Automation System"
	@echo "========================================================================"
	@echo "  make build      - Build release binary"
	@echo "  make test       - Run all unit and integration tests"
	@echo "  make run        - Build and run the macOS SwiftUI application"
	@echo "  make app        - Package release binary into MacDownloader.app bundle"
	@echo "  make clean      - Remove build artifacts and caches"
	@echo "  make release    - Run test suite and assemble release .app bundle"
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

## app: Package into standalone macOS Application (.app)
app: build
	@echo "==> Creating macOS Application Bundle at $(APP_BUNDLE)..."
	@mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)"
	@cp -f ".build/release/$(APP_NAME)" "$(MACOS_DIR)/$(APP_NAME)"
	@chmod +x "$(MACOS_DIR)/$(APP_NAME)"
	@cp -f Resources/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	@echo "==> Application bundle successfully created at $(APP_BUNDLE)"

## clean: Remove all build outputs
clean:
	@echo "==> Cleaning build artifacts..."
	@rm -rf .build "$(BUILD_DIR)" .cache
	@echo "==> Clean complete."

## release: Test and build .app bundle
release: test app
	@echo "========================================================================"
	@echo "==> Release build ready: $(APP_BUNDLE)"
	@echo "========================================================================"
