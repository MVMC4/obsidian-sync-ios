#!/usr/bin/env bash
set -euo pipefail

readonly mobile_version="v0.0.0-20260730202154-c700fe717e6e"
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "The iOS XCFramework must be built on macOS with Xcode installed." >&2
  exit 1
fi

for command_name in go xcodebuild; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "$command_name is required." >&2
    exit 1
  fi
done

tool_bin="$(go env GOPATH)/bin"
go install "golang.org/x/mobile/cmd/gomobile@$mobile_version"
go install "golang.org/x/mobile/cmd/gobind@$mobile_version"

mkdir -p "$repository_root/core/build"
cd "$repository_root/core"
"$tool_bin/gomobile" bind \
  -target=ios \
  -iosversion=17.0 \
  -tags=noassets \
  -trimpath \
  -o build/Mobilecore.xcframework \
  ./mobilecore
