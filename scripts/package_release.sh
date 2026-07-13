#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-0.1.0}"
BUILD_NUMBER="${2:-1}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCTS="$ROOT/.build/apple/Products/Release"
DIST="$ROOT/dist"
APP="$DIST/AI Limit Notch.app"
CONTENTS="$APP/Contents"
IDENTITY="${CODE_SIGN_IDENTITY:-Apple Development: Attapol Mongkol (45RPXTS4LC)}"

cd "$ROOT"
swift build -c release --arch arm64 --arch x86_64

rm -rf "$DIST"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Frameworks" "$CONTENTS/Resources"

cp "$PRODUCTS/AILimitNotch" "$CONTENTS/MacOS/AILimitNotch"
cp -R "$PRODUCTS/Frameworks/Sparkle.framework" "$CONTENTS/Frameworks/Sparkle.framework"
cp -R "$PRODUCTS/AILimitNotch_AILimitNotch.bundle" "$CONTENTS/Resources/AILimitNotch_AILimitNotch.bundle"
cp "$ROOT/Packaging/Info.plist" "$CONTENTS/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$CONTENTS/Info.plist"

ICON_WORK="$DIST/AppIcon.iconset"
mkdir -p "$ICON_WORK"
swift "$ROOT/scripts/generate_app_icon.swift" "$DIST/AppIcon-1024.png"
for spec in "16 16" "16 16@2x" "32 32" "32 32@2x" "128 128" "128 128@2x" "256 256" "256 256@2x" "512 512" "512 512@2x"; do
    set -- $spec
    points="$1"
    suffix="$2"
    pixels="$points"
    [[ "$suffix" == *@2x ]] && pixels=$((points * 2))
    sips -z "$pixels" "$pixels" "$DIST/AppIcon-1024.png" --out "$ICON_WORK/icon_${suffix}.png" >/dev/null
done
iconutil -c icns "$ICON_WORK" -o "$CONTENTS/Resources/AppIcon.icns"
rm -rf "$ICON_WORK" "$DIST/AppIcon-1024.png"

if ! otool -l "$CONTENTS/MacOS/AILimitNotch" | grep -q '@executable_path/../Frameworks'; then
    install_name_tool -add_rpath '@executable_path/../Frameworks' "$CONTENTS/MacOS/AILimitNotch"
fi

codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$CONTENTS/Frameworks/Sparkle.framework"
codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

ARCHIVE="$DIST/AI-Limit-Notch-$VERSION.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ARCHIVE"
shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256"

printf '%s\n' "$ARCHIVE"
