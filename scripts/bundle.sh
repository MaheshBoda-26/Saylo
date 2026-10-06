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
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"

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
mkdir -p "${FRAMEWORKS_DIR}"

# Copy executable
EXECUTABLE="${BUILD_DIR}/release/Saylo"
cp "${EXECUTABLE}" "${MACOS_DIR}/${APP_NAME}"

# Copy Resources (SwiftPM target resources live under Sources/SayloApp/Resources)
RES_SRC="${PROJECT_DIR}/Sources/SayloApp/Resources"
cp "${RES_SRC}/Info.plist" "${CONTENTS_DIR}/Info.plist"
cp "${RES_SRC}/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
cp "${RES_SRC}/whistle.cact" "${RESOURCES_DIR}/whistle.cact"

# Copy vendor libraries
mkdir -p "${RESOURCES_DIR}/vendor/macos-arm64"
cp "${PROJECT_DIR}/vendor/macos-arm64/libneedle.a" "${RESOURCES_DIR}/vendor/macos-arm64/"

# Find and copy Swift runtime libraries
echo "📚 Copying Swift runtime libraries..."
SWIFT_LIBS=(
    "libswiftCore.dylib"
    "libswiftSwiftUI.dylib"
    "libswiftAppKit.dylib"
    "libswiftFoundation.dylib"
    "libswiftDarwin.dylib"
    "libswiftObjectiveC.dylib"
    "libswiftDispatch.dylib"
    "libswiftMetal.dylib"
    "libswiftQuartzCore.dylib"
)

for lib in "${SWIFT_LIBS[@]}"; do
    # Find in Xcode toolchain or system
    LIB_PATH=$(find /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx -name "${lib}" 2>/dev/null | head -1)
    if [[ -z "${LIB_PATH}" ]]; then
        LIB_PATH=$(find /Library/Developer/CommandLineTools/usr/lib/swift/macosx -name "${lib}" 2>/dev/null | head -1)
    fi
    if [[ -n "${LIB_PATH}" && -f "${LIB_PATH}" ]]; then
        cp "${LIB_PATH}" "${FRAMEWORKS_DIR}/"
        echo "  ✓ ${lib}"
    else
        echo "  ⚠ ${lib} not found"
    fi
done

# Fix library paths in executable
echo "🔧 Fixing library paths..."
install_name_tool -add_rpath "@executable_path/../Frameworks" "${MACOS_DIR}/${APP_NAME}"

# Fix rpath for libneedle.a (it's static, but ensure the executable finds it)
# libneedle is statically linked, so no runtime dependency

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
echo "✍️  Signing app (ad-hoc, stable requirement)..."
codesign --force --deep --sign - \
  -r '=designated => identifier "com.saylo.app"' \
  "${APP_DIR}"

# Verify signature
codesign --verify --deep --strict "${APP_DIR}" && echo "✅ Signature verified"

echo ""
echo "✨ Done! App bundle at: ${APP_DIR}"
echo ""
echo "To install: cp -r \"${APP_DIR}\" /Applications/"
echo "To run: open \"${APP_DIR}\""