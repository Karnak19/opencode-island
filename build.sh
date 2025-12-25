#!/bin/bash
set -e

APP_NAME="Opencode Island"
BUNDLE_ID="com.opencodeisland.app"
EXECUTABLE_NAME="OpencodeIsland"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Building ${APP_NAME}...${NC}"

# Build the Swift package
swift build -c release

# Get the path to the built executable
BUILD_PATH=".build/release/${EXECUTABLE_NAME}"

if [ ! -f "$BUILD_PATH" ]; then
    echo -e "${RED}Error: Build failed - executable not found at ${BUILD_PATH}${NC}"
    exit 1
fi

echo -e "${GREEN}Build successful!${NC}"

# Create the .app bundle structure
APP_DIR="dist/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo -e "${YELLOW}Creating app bundle...${NC}"

# Clean and create directories
rm -rf "dist"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy executable
cp "${BUILD_PATH}" "${MACOS_DIR}/${EXECUTABLE_NAME}"

# Copy Info.plist
cp "Sources/Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"

# Create PkgInfo
echo -n "APPL????" > "${CONTENTS_DIR}/PkgInfo"

echo -e "${GREEN}App bundle created at: ${APP_DIR}${NC}"
echo ""
echo -e "${YELLOW}To run the app:${NC}"
echo "  open \"${APP_DIR}\""
echo ""
echo -e "${YELLOW}To install:${NC}"
echo "  cp -r \"${APP_DIR}\" /Applications/"
