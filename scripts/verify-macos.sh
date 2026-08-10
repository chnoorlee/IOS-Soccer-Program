#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is required. Install it with: brew install xcodegen" >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is unavailable. Install and select the full Xcode app." >&2
  exit 1
fi

xcodegen generate

xcodebuild \
  -project SportsHub.xcodeproj \
  -scheme SportsHub \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "SportsHub macOS compile gate: PASS"
echo "Run tests next with an installed simulator destination, for example:"
echo "xcodebuild -project SportsHub.xcodeproj -scheme SportsHub -destination 'platform=iOS Simulator,name=<available iPhone>' test"

