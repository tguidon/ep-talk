#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"

mkdir -p .build/modules
export CLANG_MODULE_CACHE_PATH="$PWD/.build/modules"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/modules"
swift build --disable-sandbox --manifest-cache local -c release -debug-info-format none
binary_dir="$(swift build --disable-sandbox --manifest-cache local -c release --show-bin-path)"
mkdir -p dist
stage="$(mktemp -d "$PWD/dist/.build.XXXXXXXX")"
trap 'rm -rf "$stage"' EXIT
bundle="$stage/EP Talk.app"
contents="$bundle/Contents"
mkdir -p "$contents/MacOS" "$contents/Resources"
cp "$binary_dir/EPTalk" "$contents/MacOS/"
cp Packaging/Info.plist "$contents/"
cp -R Sources/EPTalk/Resources/Mic "$contents/Resources/"
cp ThirdParty/*.txt "$contents/Resources/"
swift -module-cache-path "$PWD/.build/icon-cache" Packaging/MakeIcon.swift "$contents/Resources/EP Talk.icns"
codesign --force --sign "${EP_TALK_SIGN_IDENTITY:--}" "$bundle"
codesign --verify --strict "$bundle"
plutil -lint "$contents/Info.plist"

destination="$PWD/dist/EP Talk.app"
if [[ -e "$destination" ]]; then
    mv "$destination" "$stage/previous.app"
fi
if ! mv "$bundle" "$destination"; then
    if [[ -e "$stage/previous.app" ]]; then mv "$stage/previous.app" "$destination"; fi
    exit 1
fi
printf 'Built %s\n' "$destination"
