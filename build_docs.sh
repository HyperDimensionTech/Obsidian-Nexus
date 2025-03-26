#!/bin/bash

# build_docs.sh
# Script to build and export DocC documentation for Obsidian Nexus

# Configuration
PROJECT_NAME="Obsidian Nexus"
SCHEME_NAME="Obsidian Nexus"
DOCC_PATH="Obsidian Nexus/ObsidianNexus.docc"
OUTPUT_PATH="./docs"
HOSTING_BASE_PATH="/Obsidian-Nexus"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "${BLUE}Building DocC documentation for ${PROJECT_NAME}...${NC}"

# Ensure the output directory exists
mkdir -p "${OUTPUT_PATH}"

# Build documentation
echo "${BLUE}Step 1: Building DocC archive...${NC}"
xcodebuild docbuild \
    -scheme "${SCHEME_NAME}" \
    -derivedDataPath "./.derivedData" \
    -destination 'platform=iOS Simulator,name=iPhone 14'

if [ $? -ne 0 ]; then
    echo "${RED}Error: Documentation build failed${NC}"
    exit 1
fi

echo "${GREEN}Documentation archive built successfully${NC}"

# Find the DocC archive
DOCC_ARCHIVE=$(find ./.derivedData -name "*.doccarchive")

if [ -z "$DOCC_ARCHIVE" ]; then
    echo "${RED}Error: Could not find DocC archive in derived data${NC}"
    exit 1
fi

echo "${BLUE}Found DocC archive at: ${DOCC_ARCHIVE}${NC}"

# Export to static HTML for hosting
echo "${BLUE}Step 2: Converting to static HTML...${NC}"
$(xcrun --find docc) process-archive \
    transform-for-static-hosting "${DOCC_ARCHIVE}" \
    --hosting-base-path "${HOSTING_BASE_PATH}" \
    --output-path "${OUTPUT_PATH}"

if [ $? -ne 0 ]; then
    echo "${RED}Error: Static HTML conversion failed${NC}"
    exit 1
fi

echo "${GREEN}Documentation successfully exported to ${OUTPUT_PATH}${NC}"

# Clean up
echo "${BLUE}Step 3: Cleaning up...${NC}"
rm -rf ./.derivedData

echo "${GREEN}Documentation build complete!${NC}"
echo "You can now deploy the contents of ${OUTPUT_PATH} to your web server."
echo "For GitHub Pages, push the contents to the gh-pages branch."

exit 0 