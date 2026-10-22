#!/bin/bash
set -euo pipefail

native_project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "$(uname -s)" != "Darwin" ]]; then
  printf '%s\n' 'Native smoke tests require macOS (Vision, ImageIO and AppKit).' >&2
  exit 2
fi

native_build_directory="$(mktemp -d /tmp/kaii-native-build.XXXXXX)"
swiftc -swift-version 5 -parse-as-library -D NATIVE_SERVICE_SMOKE_TEST \
  "$native_project_root"/App/Services/*.swift \
  "$native_project_root/TestsNative/NativeSmoke.swift" \
  "$native_project_root/TestsNative/PrivateProviderSetupChecks.swift" \
  -o "$native_build_directory/native-smoke"
"$native_build_directory/native-smoke"
printf 'Native smoke tests passed. Build retained at: %s\n' "$native_build_directory"
printf '%s\n' 'Test fixture UUID directory was removed. Actual diary and Keychain were not accessed.'
printf '%s\n' 'This does not compile or validate iOS camera/sharing, signing or live model requests.'
