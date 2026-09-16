#!/bin/zsh
# Builds a Release copy of the app into build/Stretch Goal.app (ad-hoc signed, not notarized).
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate >/dev/null
xcodebuild -project StretchGoal.xcodeproj -scheme StretchGoal -configuration Release \
  -derivedDataPath build/DerivedData build 2>&1 | grep -E "error:|warning: .*StretchGoal/|BUILD" || true
APP="build/DerivedData/Build/Products/Release/Stretch Goal.app"
rm -rf "build/Stretch Goal.app"
cp -R "$APP" build/
codesign --force --deep --sign - "build/Stretch Goal.app"
echo "built: build/Stretch Goal.app ($(defaults read "$PWD/build/Stretch Goal.app/Contents/Info.plist" CFBundleShortVersionString))"
