#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="$HOME/Library/Caches/cn.kaii.food.build"
launch_app=true
if [[ "${1:-}" == "--no-open" ]]; then
  launch_app=false
elif [[ $# -gt 0 ]]; then
  printf '%s\n' 'Usage: bash scripts/run-mac-preview.sh [--no-open]' >&2
  exit 64
fi

swift build --package-path "$project_root" --scratch-path "$build_dir" -j 4 --product KaiiFoodPreview
binary_dir="$(swift build --package-path "$project_root" --scratch-path "$build_dir" --show-bin-path)"
# Keep signed output outside synced Documents/Desktop: file-provider Finder metadata
# can be re-added during signing and invalidate an otherwise correct local bundle.
bundle_dir="$HOME/Library/Caches/cn.kaii.food.preview/kaii食记预览.app"
if [[ -L "$bundle_dir" ]]; then
  printf '%s\n' 'Refusing to replace a symlink at the preview bundle location.' >&2
  exit 1
fi
mkdir -p "$bundle_dir/Contents/MacOS" "$bundle_dir/Contents/Resources"
cp -X "$binary_dir/KaiiFoodPreview" "$bundle_dir/Contents/MacOS/KaiiFoodPreview"
cp -X "$project_root/Config/MacPreview-Info.plist" "$bundle_dir/Contents/Info.plist"
cp -RX "$binary_dir/KaiiFood_KaiiFoodPreview.bundle" "$bundle_dir/Contents/Resources/"
if [[ -f "$project_root/App/PrivateProviders.json" ]]; then
  cp -X "$project_root/App/PrivateProviders.json" "$bundle_dir/Contents/Resources/PrivateProviders.json"
  chmod 600 "$bundle_dir/Contents/Resources/PrivateProviders.json"
else
  # Remove only the generated private-config copy from this preview bundle.
  if [[ -f "$bundle_dir/Contents/Resources/PrivateProviders.json" ]]; then
    /bin/rm "$bundle_dir/Contents/Resources/PrivateProviders.json"
  fi
fi
/usr/bin/plutil -lint "$bundle_dir/Contents/Info.plist"
# Opening a generated bundle can add FinderInfo, which codesign rejects on a rebuild.
# Remove only that known metadata attribute from this generated bundle, never source/user files.
/usr/bin/xattr -d com.apple.FinderInfo "$bundle_dir" 2>/dev/null || true
# Ad-hoc local macOS signing uses no Apple account or distribution certificate.
# This is not iOS signing, App Store distribution, or notarization.
/usr/bin/codesign --force --sign - --identifier cn.kaii.food.preview "$bundle_dir"
printf 'Native macOS preview bundle: %s\n' "$bundle_dir"
printf '%s\n' 'This is the Mac preview, not an app installed on your iPhone. It does not verify the iOS camera, permissions, or sharing flow.'
if [[ "$launch_app" == true ]]; then
  /usr/bin/open "$bundle_dir"
fi
