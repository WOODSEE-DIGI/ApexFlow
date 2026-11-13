#!/bin/bash

# ApexFlow - Release DMG Builder
# Builds a signed, non-notarized Developer ID DMG for direct distribution.

set -e

PROJECT_NAME="ApexFlow"
SCHEME="ApexFlow"
CONFIGURATION="Release"
EXPORT_PATH="./build/Release"
APP_PATH="${EXPORT_PATH}/${PROJECT_NAME}.app"
VOLUME_NAME="ApexFlow"

# Developer ID signing identity — replace with your own before running.
CODE_SIGN_IDENTITY="Developer ID Application: YOUR NAME (YOUR_TEAM_ID)"
DEVELOPMENT_TEAM="YOUR_TEAM_ID"

# Read marketing version from Info.plist and use it in the DMG filename.
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "Apex/Info.plist" 2>/dev/null || echo "unknown")
DMG_PATH="./build/${PROJECT_NAME}-${VERSION}.dmg"

echo "🚀 ApexFlow Release DMG Builder"
echo "================================"
echo ""

# Check for xcodegen
if ! command -v xcodegen &> /dev/null; then
    echo "❌ xcodegen not found. Install with: brew install xcodegen"
    exit 1
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf ./build
mkdir -p "${EXPORT_PATH}"

# Generate project
echo "📋 Generating Xcode project..."
xcodegen generate

# Build Release
echo "📦 Building Release configuration..."
xcodebuild -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -destination 'platform=macOS' \
    build \
    CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY}" \
    DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}"

# Locate built app
BUILT_APP=$(find ~/Library/Developer/Xcode/DerivedData -name "${PROJECT_NAME}.app" -path "*/Build/Products/Release/*" | head -n 1)
if [ -z "${BUILT_APP}" ]; then
    echo "❌ Could not find built Release app in DerivedData"
    exit 1
fi

echo "✅ Built: ${BUILT_APP}"

# Copy to export path
cp -R "${BUILT_APP}" "${APP_PATH}"

# Verify code signature
echo "🔏 Verifying code signature..."
codesign -dv --verbose=4 "${APP_PATH}" 2>&1 | grep -E "Authority|TeamIdentifier|Identifier"

# Create staging folder for DMG
STAGING_DIR="./build/dmg-staging"
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"
cp -R "${APP_PATH}" "${STAGING_DIR}/"

# Create a symlink to /Applications for drag-and-drop install
ln -s /Applications "${STAGING_DIR}/Applications"

# Remove any previous generic or versioned DMG so only the current one remains
rm -f "./build/${PROJECT_NAME}-Release.dmg"

# Create DMG
echo "💿 Creating DMG..."
hdiutil create \
    -volname "${VOLUME_NAME} ${VERSION}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    -size 100m \
    "${DMG_PATH}"

# Clean up the staging copy now that the DMG is built
rm -rf "${STAGING_DIR}"

# Sign the DMG
echo "🔏 Signing DMG..."
codesign --sign "${CODE_SIGN_IDENTITY}" --timestamp "${DMG_PATH}"

echo ""
echo "✨ Build Complete!"
echo "=================="
echo "📦 App: ${APP_PATH}"
echo "💿 DMG: ${DMG_PATH}"
echo ""
echo "⚠️  This DMG is signed with Developer ID but NOT notarized."
echo "   On first launch, users may need to right-click the app and choose Open."
echo "   To notarize, run:"
echo "     xcrun notarytool submit \"${DMG_PATH}\" --keychain-profile \"AC_PASSWORD\" --wait"
echo "   Then staple:"
echo "     xcrun stapler staple \"${DMG_PATH}\""
echo ""
