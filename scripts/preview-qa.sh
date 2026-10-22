#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="$HOME/Library/Caches/cn.kaii.food.build"
bundle_dir="$HOME/Library/Caches/cn.kaii.food.public-qa/kaii食记测试.app"
swift build --package-path "$project_root" --scratch-path "$build_dir" -j 4 -Xswiftc -DPUBLIC_UI_TEST --product KaiiFoodPreview
binary_dir="$(swift build --package-path "$project_root" --scratch-path "$build_dir" --show-bin-path)"
mkdir -p "$bundle_dir/Contents/MacOS" "$bundle_dir/Contents/Resources"
cp -X "$binary_dir/KaiiFoodPreview" "$bundle_dir/Contents/MacOS/KaiiFoodPreview"
cp -RX "$binary_dir/KaiiFood_KaiiFoodPreview.bundle" "$bundle_dir/Contents/Resources/"
cp -X "$project_root/Config/MacPreview-Info.plist" "$bundle_dir/Contents/Info.plist"
/usr/bin/plutil -replace CFBundleIdentifier -string cn.kaii.food.public-qa "$bundle_dir/Contents/Info.plist"
/usr/bin/plutil -replace CFBundleDisplayName -string kaii食记测试 "$bundle_dir/Contents/Info.plist"
/usr/bin/xattr -d com.apple.FinderInfo "$bundle_dir" 2>/dev/null || true
/usr/bin/codesign --force --sign - --identifier cn.kaii.food.public-qa "$bundle_dir"
/usr/bin/open "$bundle_dir"
