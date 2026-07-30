#!/bin/bash
#
# build.sh — Build sergey.app and package it into a DMG
#
# Usage:
#   ./build.sh              # Build Release + create DMG
#   ./build.sh --no-dmg     # Build only, skip DMG creation
#   ./build.sh --dmg-only   # Skip build, create DMG from existing .app in DerivedData
#   ./build.sh --clean      # Clean build + DMG
#
# The DMG will be placed in: ./build/Sergey-<version>.dmg
#

set -euo pipefail

PROJECT_NAME="sergey"
SCHEME="${PROJECT_NAME}"
CONFIGURATION="${CONFIGURATION:-Release}"
BUILD_DIR="./build"
DERIVED_DATA_PATH="${DERIVED_DATA:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

# Parse arguments
DO_BUILD=true
DO_DMG=true
DO_CLEAN=false

for arg in "$@"; do
    case "$arg" in
        --no-dmg)    DO_DMG=false ;;
        --dmg-only)  DO_BUILD=false ;;
        --clean)     DO_CLEAN=true ;;
        *)           warn "Unknown argument: $arg" ;;
    esac
done

# Resolve derived data path
if [ -z "$DERIVED_DATA_PATH" ]; then
    # Check if there's an existing DerivedData in the standard Xcode location
    XCODE_DERIVED=~/Library/Developer/Xcode/DerivedData
    if [ -d "${XCODE_DERIVED}" ]; then
        # Find the most recent sergey DerivedData folder
        SERGEY_DD=$(ls -dt "${XCODE_DERIVED}/sergey-"* 2>/dev/null | head -1 || true)
        if [ -n "${SERGEY_DD}" ] && [ -d "${SERGEY_DD}" ]; then
            DERIVED_DATA_PATH="${SERGEY_DD}"
            info "Using existing DerivedData: ${DERIVED_DATA_PATH}"
        else
            DERIVED_DATA_PATH="${BUILD_DIR}/DerivedData"
        fi
    else
        DERIVED_DATA_PATH="${BUILD_DIR}/DerivedData"
    fi
fi

ARCHIVE_PATH="${BUILD_DIR}/${PROJECT_NAME}.xcarchive"
APP_BASENAME="${PROJECT_NAME}.app"
DMG_NAME="${PROJECT_NAME}.dmg"
VERSION=""

# ---------- Step 1: Build ----------
if [ "$DO_BUILD" = true ]; then
    info "Building ${PROJECT_NAME} (${CONFIGURATION})..."

    mkdir -p "${BUILD_DIR}"

    # Check if xcpretty is available
    if command -v xcpretty &>/dev/null; then
        PRETTY_FILTER="xcpretty"
    else
        PRETTY_FILTER="cat"
        warn "xcpretty not found — install it with: gem install xcpretty (optional, for prettier logs)"
    fi

    if [ "$DO_CLEAN" = true ]; then
        info "Cleaning..."
        xcodebuild clean \
            -project "${PROJECT_NAME}.xcodeproj" \
            -scheme "${SCHEME}" \
            -configuration "${CONFIGURATION}" \
            -derivedDataPath "${DERIVED_DATA_PATH}" \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO \
            2>&1 | ${PRETTY_FILTER} || true
    fi

    xcodebuild build \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "${SCHEME}" \
        -configuration "${CONFIGURATION}" \
        -derivedDataPath "${DERIVED_DATA_PATH}" \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        2>&1 | ${PRETTY_FILTER}

    info "Build complete!"
fi

# ---------- Step 2: Locate the .app ----------
APP_SOURCE=""

# Search paths in priority order
SEARCH_PATHS=(
    "${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/${APP_BASENAME}"
    "${DERIVED_DATA_PATH}/Build/Products/Debug/${APP_BASENAME}"
    "${DERIVED_DATA_PATH}/Build/Products/Release/${APP_BASENAME}"
)

for path in "${SEARCH_PATHS[@]}"; do
    if [ -d "${path}" ]; then
        APP_SOURCE="${path}"
        break
    fi
done

# If still not found, do a broader search
if [ -z "${APP_SOURCE}" ]; then
    APP_SOURCE=$(find "${DERIVED_DATA_PATH}" -name "${APP_BASENAME}" -type d -maxdepth 6 2>/dev/null | head -1 || true)
fi

if [ ! -d "${APP_SOURCE}" ]; then
    error "Could not find ${APP_BASENAME} in ${DERIVED_DATA_PATH}"
    echo "  Searched paths:"
    for path in "${SEARCH_PATHS[@]}"; do
        echo "    - ${path}"
    done
    echo ""
    echo "  Try building first with: ./build.sh"
    exit 1
fi

info "Found .app at: ${APP_SOURCE}"

# Extract version from Info.plist
VERSION=$(plutil -p "${APP_SOURCE}/Contents/Info.plist" 2>/dev/null | grep "CFBundleShortVersionString" | awk -F'"' '{print $4}' || echo "1.0")
info "Version: ${VERSION}"

# ---------- Step 3: Create DMG ----------
if [ "$DO_DMG" = true ]; then
    FINAL_DMG_NAME="${BUILD_DIR}/Sergey-${VERSION}.dmg"
    STAGING_DIR="${BUILD_DIR}/dmg-staging"
    DMG_TEMP="${BUILD_DIR}/sergey-temp.dmg"

    info "Creating DMG..."

    # Prepare staging directory
    rm -rf "${STAGING_DIR}"
    mkdir -p "${STAGING_DIR}"

    # Copy the .app into staging
    ditto "${APP_SOURCE}" "${STAGING_DIR}/${APP_BASENAME}"

    # Create a symbolic link to /Applications for drag-and-drop install
    ln -s /Applications "${STAGING_DIR}/Applications"

    # Create the DMG
    rm -f "${DMG_TEMP}" "${FINAL_DMG_NAME}"

    hdiutil create \
        -volname "Sergey ${VERSION}" \
        -srcfolder "${STAGING_DIR}" \
        -ov -format UDZO \
        -size 512m \
        "${DMG_TEMP}"

    # Compress (optional: convert to UDZO if not already)
    hdiutil convert "${DMG_TEMP}" -format UDZO -o "${FINAL_DMG_NAME}"

    # Cleanup temp
    rm -f "${DMG_TEMP}"
    rm -rf "${STAGING_DIR}"

    info "DMG created: ${FINAL_DMG_NAME}"
    echo ""
    echo "  To install, open the DMG and drag ${PROJECT_NAME}.app into Applications."
    echo ""
fi

# ---------- Summary ----------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Project: ${PROJECT_NAME}"
echo "  Version: ${VERSION}"
echo "  Config:  ${CONFIGURATION}"
echo "  App:     ${APP_SOURCE}"
if [ "$DO_DMG" = true ]; then
    echo "  DMG:     ${FINAL_DMG_NAME}"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
