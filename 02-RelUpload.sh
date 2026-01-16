#!/usr/bin/env bash
set -e

APK_DIR="/home/e/AndroidStudioProjects/shopper/build/app/outputs/flutter-apk"
PROJECT="shopper"

echo "=== Detecting latest tag ==="
TAG=$(git tag --list 'v*' | sort -V | tail -n 1)

if [[ -z "$TAG" ]]; then
    echo "ERROR: No tags found."
    exit 1
fi

echo "Tag: $TAG"

# ------------------------------------------------------------
# Parse tag: v0.7.260115+26  ->  VERSION=0.7.260115  BUILD=26
# ------------------------------------------------------------
CLEAN_TAG="${TAG#v}"
VERSION="${CLEAN_TAG%%+*}"
BUILD="${CLEAN_TAG##*+}"

if [[ -z "$VERSION" || -z "$BUILD" ]]; then
    echo "ERROR: Failed to parse tag: $TAG"
    exit 1
fi

echo "Version: $VERSION"
echo "Build:   $BUILD"

# ------------------------------------------------------------
# Real file names on disk (app-*)
# ------------------------------------------------------------
SRC_APK_MAIN="app-release-${VERSION}-${BUILD}.apk"
SRC_SHA_MAIN="app-release.apk.sha1"

SRC_APK_ARM64="app-arm64-v8a-release-${VERSION}-${BUILD}.apk"
SRC_SHA_ARM64="app-arm64-v8a-release.apk.sha1"

# ------------------------------------------------------------
# Target file names in GitHub Release (shopper-*)
# ------------------------------------------------------------
DST_APK_MAIN="${PROJECT}-release-${VERSION}-${BUILD}.apk"
DST_SHA_MAIN="${PROJECT}-release.apk.sha1"

DST_APK_ARM64="${PROJECT}-arm64-v8a-release-${VERSION}-${BUILD}.apk"
DST_SHA_ARM64="${PROJECT}-arm64-v8a-release.apk.sha1"

FILES=(
    "$SRC_APK_MAIN#$DST_APK_MAIN"
    "$SRC_SHA_MAIN#$DST_SHA_MAIN"
    "$SRC_APK_ARM64#$DST_APK_ARM64"
    "$SRC_SHA_ARM64#$DST_SHA_ARM64"
)

echo "=== Checking source files in $APK_DIR ==="

for pair in "${FILES[@]}"; do
    SRC="${pair%%#*}"
    if [[ ! -f "$APK_DIR/$SRC" ]]; then
        echo "ERROR: File not found: $APK_DIR/$SRC"
        exit 1
    fi
    echo "OK: $SRC"
done

# ------------------------------------------------------------
# Create release if not exists
# ------------------------------------------------------------
echo "=== Checking if GitHub Release exists ==="

if gh release view "$TAG" >/dev/null 2>&1; then
    echo "Release already exists."
else
    echo "Creating GitHub Release..."
    gh release create "$TAG" \
        --title "Release $TAG" \
        --notes "Automated release for $PROJECT $TAG"
fi

# ------------------------------------------------------------
# Upload files with renaming
# ------------------------------------------------------------
echo "=== Uploading files to Release ==="

for pair in "${FILES[@]}"; do
    SRC="${pair%%#*}"
    echo "Uploading: $SRC -> ${pair##*#}"
    gh release upload "$TAG" "$APK_DIR/$pair" --clobber
done

echo "=== Release upload completed successfully ==="
