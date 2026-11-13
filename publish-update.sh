#!/bin/bash

# ApexFlow - Sparkle Update Publisher
# Creates a signed .zip update archive and appcast.xml from an already-built
# Release app. Run ./build-dmg.sh first to produce build/Release/ApexFlow.app.
#
# Prerequisites:
#   - generate_appcast from Sparkle in your PATH, or let this script download it.
#   - A public URL to host appcast.xml and the update archive.
#
# Usage:
#   ./build-dmg.sh
#   ./publish-update.sh

set -e

PROJECT_NAME="ApexFlow"
APP_NAME="ApexFlow.app"
APP_PATH="./build/Release/${APP_NAME}"
RELEASES_DIR="./build/releases"

# Read version from Info.plist
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "Apex/Info.plist" 2>/dev/null || echo "unknown")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "Apex/Info.plist" 2>/dev/null || echo "0")

# Developer ID signing identity — replace with your own before distributing.
CODE_SIGN_IDENTITY="Developer ID Application: YOUR NAME (YOUR_TEAM_ID)"

# Public URL where you will host appcast.xml (set in Apex/Info.plist SUFeedURL).
FEED_URL=$(/usr/libexec/PlistBuddy -c "Print SUFeedURL" "Apex/Info.plist" 2>/dev/null || echo "https://your-server.com/ApexFlow/appcast.xml")

echo "🚀 ApexFlow Update Publisher"
echo "=============================="
echo ""
echo "Version: ${VERSION} (build ${BUILD})"
echo "Feed URL: ${FEED_URL}"
echo ""

# Verify the app exists
if [ ! -d "${APP_PATH}" ]; then
    echo "❌ Built app not found at ${APP_PATH}"
    echo "   Run ./build-dmg.sh first to build a signed Release app."
    exit 1
fi

# Prepare releases directory
mkdir -p "${RELEASES_DIR}"

# Create a signed .zip archive for Sparkle updates
ZIP_NAME="${PROJECT_NAME}-${VERSION}.zip"
ZIP_PATH="${RELEASES_DIR}/${ZIP_NAME}"

echo "🤐 Creating update archive: ${ZIP_PATH}"
rm -f "${ZIP_PATH}"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"

# Ensure the archive is signed (Sparkle verifies the app signature inside)
echo "🔏 Signing update archive..."
codesign --sign "${CODE_SIGN_IDENTITY}" --timestamp "${ZIP_PATH}"

# Generate or fetch generate_appcast
GENERATE_APPCAST=$(command -v generate_appcast || true)
if [ -z "${GENERATE_APPCAST}" ]; then
    SPARKLE_VERSION="2.6.4"
    SPARKLE_TOOLS_DIR="./build/sparkle-tools"
    SPARKLE_ARCHIVE="${SPARKLE_TOOLS_DIR}/Sparkle-${SPARKLE_VERSION}.tar.xz"
    GENERATE_APPCAST="${SPARKLE_TOOLS_DIR}/Sparkle-${SPARKLE_VERSION}/bin/generate_appcast"

    if [ ! -f "${GENERATE_APPCAST}" ]; then
        echo "⬇️  Downloading Sparkle ${SPARKLE_VERSION} tools..."
        mkdir -p "${SPARKLE_TOOLS_DIR}"
        curl -L \
            "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz" \
            -o "${SPARKLE_ARCHIVE}"
        tar -xf "${SPARKLE_ARCHIVE}" -C "${SPARKLE_TOOLS_DIR}"
    fi
fi

# Generate appcast.xml
echo "📡 Generating appcast.xml..."
"${GENERATE_APPCAST}" "${RELEASES_DIR}"

echo ""
echo "✨ Update artifacts ready"
echo "========================="
echo "📦 Archive: ${ZIP_PATH}"
echo "📡 Appcast: ${RELEASES_DIR}/appcast.xml"
echo ""
echo "Next steps:"
echo "1. Upload ${ZIP_PATH} and ${RELEASES_DIR}/appcast.xml to your server."
echo "2. Ensure the URL in Apex/Info.plist SUFeedURL matches:"
echo "   ${FEED_URL}"
echo "3. Users running the previous version will be prompted to update."
echo ""
echo "⚠️  Remember to replace CODE_SIGN_IDENTITY with your real Developer ID"
echo "   value before publishing."
