#!/bin/bash

# Apex - App Store Build & Export Script
# Usage: ./build-appstore.sh

set -e  # Exit on error

echo "🚀 Apex - App Store Build Process"
echo "=================================="
echo ""

# Configuration
PROJECT_NAME="Apex"
SCHEME="Apex"
CONFIGURATION="AppStore"
ARCHIVE_PATH="./build/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="./build/AppStore"
EXPORT_OPTIONS="./exportOptions.plist"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf ./build
mkdir -p ./build

# Step 2: Check for required files
echo ""
echo "📋 Checking requirements..."

if [ ! -f "Apex-AppStore.entitlements" ]; then
    echo -e "${RED}❌ Missing: Apex-AppStore.entitlements${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Entitlements found${NC}"

if [ ! -f "$EXPORT_OPTIONS" ]; then
    echo -e "${RED}❌ Missing: exportOptions.plist${NC}"
    echo "   Update YOUR_TEAM_ID_HERE with your Apple Developer Team ID"
    exit 1
fi

# Check if Team ID is set
if grep -q "YOUR_TEAM_ID_HERE" "$EXPORT_OPTIONS"; then
    echo -e "${RED}❌ Export options not configured${NC}"
    echo "   Edit exportOptions.plist and replace YOUR_TEAM_ID_HERE"
    exit 1
fi
echo -e "${GREEN}✅ Export options configured${NC}"

# Check for Xcode project
if [ ! -d "${PROJECT_NAME}.xcodeproj" ]; then
    echo -e "${YELLOW}⚠️  No .xcodeproj found. Running xcodegen...${NC}"
    if command -v xcodegen &> /dev/null; then
        xcodegen generate
    else
        echo -e "${RED}❌ xcodegen not found. Install with: brew install xcodegen${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✅ Xcode project ready${NC}"

# Step 3: Archive the app
echo ""
echo "📦 Creating archive..."
xcodebuild archive \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM=\$(grep -A 1 "teamID" "$EXPORT_OPTIONS" | tail -1 | sed 's/<[^>]*>//g' | xargs) \
    | xcpretty || xcodebuild archive \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -archivePath "$ARCHIVE_PATH"

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo -e "${RED}❌ Archive failed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Archive created successfully${NC}"

# Step 4: Export for App Store
echo ""
echo "📤 Exporting for App Store..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    | xcpretty || xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS"

if [ ! -f "$EXPORT_PATH/${PROJECT_NAME}.pkg" ]; then
    echo -e "${RED}❌ Export failed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Export successful${NC}"

# Step 5: Summary
echo ""
echo "✨ Build Complete!"
echo "================="
echo ""
echo "📦 Archive: $ARCHIVE_PATH"
echo "📤 Package: $EXPORT_PATH/${PROJECT_NAME}.pkg"
echo ""
echo "🚀 Next Steps:"
echo "   1. Download 'Transporter' app from Mac App Store"
echo "   2. Drag ${PROJECT_NAME}.pkg into Transporter"
echo "   3. Click 'Deliver' to upload to App Store Connect"
echo ""
echo "   Alternative (command line):"
echo "   xcrun altool --upload-app \\"
echo "     --type macos \\"
echo "     --file \"$EXPORT_PATH/${PROJECT_NAME}.pkg\" \\"
echo "     --username \"your@apple.id\" \\"
echo "     --password \"app-specific-password\""
echo ""
echo -e "${GREEN}✅ Ready for App Store submission!${NC}"
