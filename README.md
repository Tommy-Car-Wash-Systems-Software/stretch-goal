# Stretch Goal

Menu bar app for macOS 26+ that nudges you to move, drink water, stretch and rest your eyes,
with a weekly team leaderboard synced through a shared OneDrive folder. See `docs/SPEC.md`.

## Build

```bash
brew install xcodegen
xcodegen generate
open StretchGoal.xcodeproj
```

Core logic and tests live in `Packages/StretchGoalCore`:

```bash
cd Packages/StretchGoalCore && swift test
```
