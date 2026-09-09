#!/bin/bash
set -e

APP_NAME="MyMacTools"
BUILD_DIR=".build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

echo "Building ${APP_NAME}..."
swift build -c release

echo "Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS}" "${RESOURCES}"

cp "${BUILD_DIR}/release/MyMacTools" "${MACOS}/${APP_NAME}"
cp "Resources/Info.plist" "${CONTENTS}/Info.plist"

# 다국어 리소스. Bundle.main 이 Contents/Resources 를 보므로 lproj 를 그대로 옮긴다.
# (SwiftPM resources/Bundle.module 을 쓰지 않는 이유는 docs/i18n-design.md 참고)
mkdir -p "${RESOURCES}"
for lproj in Resources/*.lproj; do
    [ -d "${lproj}" ] || continue
    rm -rf "${RESOURCES}/$(basename "${lproj}")"
    cp -R "${lproj}" "${RESOURCES}/"
    echo "  + $(basename "${lproj}")"
done

echo "Done! App bundle created at: ${APP_BUNDLE}"
echo ""
echo "To run:  open ${APP_BUNDLE}"
echo "To install: cp -r ${APP_BUNDLE} /Applications/"
