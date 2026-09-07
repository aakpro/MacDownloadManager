#!/usr/bin/env bash
set -e

# ==============================================================================
# MacDownloader Browser Extension - Native Messaging Host Installer
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_NAME="com.macdownloader.nativehost"
SOURCE_MANIFEST="$SCRIPT_DIR/$HOST_NAME.json"

CHROME_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
BRAVE_DIR="$HOME/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts"
EDGE_DIR="$HOME/Library/Application Support/Microsoft Edge/NativeMessagingHosts"
FIREFOX_DIR="$HOME/Library/Application Support/Mozilla/NativeMessagingHosts"

TARGET_DIRS=("$CHROME_DIR" "$BRAVE_DIR" "$EDGE_DIR" "$FIREFOX_DIR")

echo "==> Registering MacDownloader Native Messaging Host ($HOST_NAME)..."

for dir in "${TARGET_DIRS[@]}"; do
    mkdir -p "$dir"
    cp -f "$SOURCE_MANIFEST" "$dir/$HOST_NAME.json"
    echo "  [✓] Installed to: $dir/$HOST_NAME.json"
done

echo "==> Native Messaging Host installation complete!"
