#!/bin/zsh
# Cuts a release: builds, zips, tags, publishes a GitHub release, and bumps the Homebrew cask.
# Usage: scripts/release.sh            (uses MARKETING_VERSION from project.yml)
# Env:   TAP_DIR=../homebrew-tap       (checkout of Tommy-Car-Wash-Systems-Software/homebrew-tap)
set -euo pipefail
cd "$(dirname "$0")/.."
ORG="Tommy-Car-Wash-Systems-Software"
REPO="stretch-goal"
TAP_DIR="${TAP_DIR:-../homebrew-tap}"

if [[ -n "$(git status --porcelain)" ]]; then echo "working tree not clean"; exit 1; fi
VERSION=$(grep -E '^\s*MARKETING_VERSION:' project.yml | sed -E 's/.*"([^"]+)".*/\1/')
TAG="v$VERSION"
ZIP="build/StretchGoal-$VERSION.zip"

scripts/build.sh
rm -f "$ZIP"
ditto -c -k --keepParent "build/Stretch Goal.app" "$ZIP"
SHA=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)
echo "sha256 $SHA"

git tag -f "$TAG"
git push origin main
git push -f origin "$TAG"
if gh release view "$TAG" -R "$ORG/$REPO" >/dev/null 2>&1; then
  gh release upload "$TAG" "$ZIP" --clobber -R "$ORG/$REPO"
else
  gh release create "$TAG" "$ZIP" -R "$ORG/$REPO" --title "Stretch Goal $VERSION" --generate-notes
fi

CASK="$TAP_DIR/Casks/stretch-goal.rb"
if [[ -f "$CASK" ]]; then
  sed -i '' -E "s/^  version \".*\"/  version \"$VERSION\"/; s/^  sha256 \".*\"/  sha256 \"$SHA\"/" "$CASK"
  (cd "$TAP_DIR" && git add Casks/stretch-goal.rb && git commit -qm "stretch-goal $VERSION" && git push origin main)
  echo "cask bumped to $VERSION"
else
  echo "cask not found at $CASK; skipped"
fi
