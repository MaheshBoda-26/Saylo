#!/bin/bash
# Saylo.app bundle script
# Builds a double-clickable .app from the SwiftPM project

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/.build"
APP_NAME="Saylo"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "🔨 Building Saylo..."

# Clean previous build
rm -rf "${APP_DIR}"

# Build the executable
echo "📦 Building with SwiftPM..."
cd "${PROJECT_DIR}"
swift build -c release --product Saylo

# Create app bundle structure
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy executable
EXECUTABLE="${BUILD_DIR}/release/Saylo"
cp "${EXECUTABLE}" "${MACOS_DIR}/${APP_NAME}"

# Copy Resources (SwiftPM target resources live under Sources/SayloApp/Resources)
RES_SRC="${PROJECT_DIR}/Sources/SayloApp/Resources"
cp "${RES_SRC}/Info.plist" "${CONTENTS_DIR}/Info.plist"
cp "${RES_SRC}/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
cp "${RES_SRC}/whistle.cact" "${RESOURCES_DIR}/whistle.cact"

# Copy the design-system fonts (Inter, Instrument Serif, Geist Mono) so
# DesignSystem.registerBundledFonts() finds them in the shipped app too.
if [[ -d "${RES_SRC}/Fonts" ]]; then
    mkdir -p "${RESOURCES_DIR}/Fonts"
    cp "${RES_SRC}/Fonts"/*.ttf "${RESOURCES_DIR}/Fonts/"
    echo "  ✓ Fonts"
fi

# The Swift runtime and SwiftUI ship with macOS 14+ (the deployment target), so
# bundling toolchain dylibs only duplicated system libraries.

# Create PkgInfo
echo "APPL????" > "${CONTENTS_DIR}/PkgInfo"

# Sign the app (ad-hoc)
#
# The explicit designated requirement matters: without it, ad-hoc signing
# falls back to a cdhash-based requirement. Every rebuild changes the
# binary, so the cdhash changes, and macOS TCC treats the app as a
# different app — the Accessibility grant silently stops applying and
# the global-hotkey event tap fails with "check Accessibility
# permissions". Pinning the requirement to the bundle identifier keeps
# the TCC identity stable across rebuilds.
#
# `--deep` is deliberately not used: the bundle contains no nested code, and
# Apple deprecates it for signing.
echo "✍️  Signing app (ad-hoc, stable requirement)..."
codesign --force --sign - \
  -r '=designated => identifier "com.saylo.app"' \
  "${APP_DIR}"

# Verify signature
codesign --verify --strict "${APP_DIR}" && echo "✅ Signature verified"

echo ""
echo "✨ Done! App bundle at: ${APP_DIR}"
echo ""
echo "To install: cp -r \"${APP_DIR}\" /Applications/"
echo "To run: open \"${APP_DIR}\""
