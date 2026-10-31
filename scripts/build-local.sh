#!/bin/bash
# Build a locally signed app using Apple's Command Line Tools or full Xcode.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != Darwin ]]; then
    echo "Subvox requires macOS 14 or later." >&2
    exit 1
fi

if ! xcrun --find swiftc >/dev/null 2>&1; then
    echo "Install Apple's developer tools with: xcode-select --install" >&2
    exit 1
fi

sdk=$(xcrun --sdk macosx --show-sdk-path)
app="$PWD/build/Subvox.app"
mkdir -p "$app/Contents/MacOS" "$PWD/build/ModuleCache"
sources=()
while IFS= read -r source; do
    sources+=("$source")
done < <(find Subvox -name '*.swift' -type f | sort)

xcrun swiftc -swift-version 5 -parse-as-library -O \
    -sdk "$sdk" \
    -target "$(uname -m)-apple-macosx14.0" \
    -module-cache-path "$PWD/build/ModuleCache" \
    -module-name Subvox "${sources[@]}" -o "$app/Contents/MacOS/Subvox"

cp Subvox/Info.plist "$app/Contents/Info.plist"
plist="$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable Subvox' "$plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.joeblau.subvox' "$plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName Subvox' "$plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleDevelopmentRegion en' "$plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 0.1.0' "$plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleVersion 1' "$plist"
/usr/libexec/PlistBuddy -c 'Add :LSMinimumSystemVersion string 14.0' "$plist"
plutil -lint "$plist"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
echo "Built $app"
echo 'Launch with: open build/Subvox.app'
