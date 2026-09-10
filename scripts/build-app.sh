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

# 앱 아이콘. 원본 PNG 하나에서 필요한 크기를 만들어 .icns 로 굽는다.
# 원본이 더 새로울 때만 다시 굽는다(재실행해도 안전, 매 빌드마다 갈지 않음).
# 번들은 매번 rm -rf 되므로 캐시는 .build 아래에 둔다. 그래야 원본이 그대로일 때 건너뛴다.
ICON_SRC="Resources/AppIcon.png"
ICON_CACHE="${BUILD_DIR}/AppIcon.icns"
if [ -f "${ICON_SRC}" ]; then
    if [ ! -f "${ICON_CACHE}" ] || [ "${ICON_SRC}" -nt "${ICON_CACHE}" ]; then
        ICONSET="${BUILD_DIR}/AppIcon.iconset"
        rm -rf "${ICONSET}"; mkdir -p "${ICONSET}"
        for size in 16 32 128 256 512; do
            sips -z ${size} ${size}         "${ICON_SRC}" --out "${ICONSET}/icon_${size}x${size}.png"    >/dev/null
            sips -z $((size*2)) $((size*2)) "${ICON_SRC}" --out "${ICONSET}/icon_${size}x${size}@2x.png" >/dev/null
        done
        iconutil -c icns "${ICONSET}" -o "${ICON_CACHE}"
        rm -rf "${ICONSET}"
        echo "  + AppIcon.icns (생성)"
    else
        echo "  = AppIcon.icns (캐시 재사용)"
    fi
    cp "${ICON_CACHE}" "${RESOURCES}/AppIcon.icns"
fi

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
