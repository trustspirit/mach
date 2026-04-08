#!/bin/bash
set -euo pipefail

# Mach - Build & Package Script
# Builds a Release .app, ad-hoc signs it, and creates a DMG for distribution.

APP_NAME="Mach"
SCHEME="Mach"
BUILD_DIR="$(pwd)/build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
APP_PATH="${EXPORT_PATH}/${APP_NAME}.app"
DMG_PATH="${BUILD_DIR}/${APP_NAME}.dmg"

# Read version from Info.plist
VERSION=$(defaults read "$(pwd)/Mach/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")

echo "==> Building ${APP_NAME} v${VERSION}"

# Clean previous build
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Generate Xcode project if xcodegen is available
if command -v xcodegen &>/dev/null; then
    echo "==> Generating Xcode project with XcodeGen..."
    xcodegen generate
fi

# Archive
echo "==> Archiving..."
xcodebuild archive \
    -project "${APP_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    ONLY_ACTIVE_ARCH=NO \
    | tail -1

# Export .app from archive
echo "==> Exporting app..."
mkdir -p "${EXPORT_PATH}"
cp -R "${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app" "${APP_PATH}"

# Ad-hoc sign (allows running without Developer ID, users need to bypass Gatekeeper)
echo "==> Ad-hoc signing..."
codesign --force --deep --sign - "${APP_PATH}"

# Verify signature
echo "==> Verifying signature..."
codesign --verify --verbose "${APP_PATH}"

# Create DMG
echo "==> Creating DMG..."
DMG_TEMP="${BUILD_DIR}/dmg_temp"
mkdir -p "${DMG_TEMP}"
cp -R "${APP_PATH}" "${DMG_TEMP}/"
ln -s /Applications "${DMG_TEMP}/Applications"

hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_TEMP}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"

rm -rf "${DMG_TEMP}"

# Summary
DMG_SIZE=$(du -h "${DMG_PATH}" | cut -f1)
echo ""
echo "==> Build complete!"
echo "    App:     ${APP_PATH}"
echo "    DMG:     ${DMG_PATH} (${DMG_SIZE})"
echo "    Version: ${VERSION}"
echo ""
echo "NOTE: This build is ad-hoc signed. Users must run one of the following after download:"
echo "    xattr -cr ${APP_NAME}.app"
echo "  or right-click > Open to bypass Gatekeeper."
