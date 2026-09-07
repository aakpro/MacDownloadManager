# Makefile Guide for MacDownloader

This guide explains the command-line build, test, and release targets provided in the project `Makefile`.

---

## Target Reference

### 1. `make build`
Compiles all targets (core library, executable, and tests) in release mode using Swift Package Manager.
```bash
make build
```

### 2. `make test`
Executes the full test suite (unit tests, integration tests, and simulated network tests) with detailed verbose output.
```bash
make test
```

### 3. `make run`
Builds and launches the native macOS SwiftUI application directly.
```bash
make run
```

### 4. `make app`
Packages the compiled release binary into a standalone macOS Application Bundle (`build/MacDownloader.app`) including:
- `Contents/MacOS/MacDownloader` (executable)
- `Contents/Info.plist` (bundle identifier, name, version, entitlements)
- `Contents/Resources/`
```bash
make app
open build/MacDownloader.app
```

### 5. `make clean`
Removes `.build/`, `build/`, `.cache/`, and temporary build artifacts.
```bash
make clean
```

### 6. `make release`
Runs the complete release checklist:
1. Cleans previous artifacts.
2. Runs all unit and integration tests.
3. Builds the optimized release binary.
4. Packages `build/MacDownloader.app`.
```bash
make release
```

### 7. `make help`
Prints an overview of all available targets with descriptions.
```bash
make help
```
