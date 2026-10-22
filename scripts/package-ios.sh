#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
derived_data="${KAIIFOOD_DERIVED_DATA:-$HOME/Library/Caches/cn.kaii.food.public-release/DerivedData}"
python3 "$project_root/scripts/check-public.py"
xcodebuild -project "$project_root/KaiiFood.xcodeproj" -scheme KaiiFood \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath "$derived_data" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY='' DEVELOPMENT_TEAM='' build

mkdir -p "$project_root/dist"
output="$project_root/dist/kaii-food-v1.0-ios-unsigned.ipa"
if [[ -e "$output" ]]; then
  printf '%s\n' 'An IPA already exists in dist. Move it aside before packaging again.' >&2
  exit 1
fi
python3 - "$derived_data/Build/Products/Release-iphoneos/kaii食记.app" "$output" <<'PY'
from pathlib import Path
import sys
import zipfile

app = Path(sys.argv[1])
with zipfile.ZipFile(sys.argv[2], 'x', zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(app.rglob('*')):
        if path.is_file():
            archive.write(path, str(Path('Payload/KaiiFood.app') / path.relative_to(app)))
PY
python3 "$project_root/scripts/check-public.py" "$output"
printf 'IPA ready for personal signing: %s\n' "$output"
