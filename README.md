# Stretch Goal

A macOS menu bar app that nags you, kindly, to take care of yourself while you work: get up,
stretch, drink water, rest your eyes. It scores your day, keeps a streak, and soon will sync a
weekly leaderboard with the rest of the team through our shared OneDrive.

Requires **macOS 26 (Tahoe) or later**.

## Install

### Homebrew (recommended)

```bash
brew tap tommy-car-wash-systems-software/tap
brew trust tommy-car-wash-systems-software/tap
brew install --cask stretch-goal
```

`brew trust` is a one-time step recent Homebrew requires for third-party taps. Updates later
are just `brew upgrade`.

### Manual

Download `StretchGoal-<version>.zip` from the [latest release](../../releases/latest), unzip,
and drag **Stretch Goal.app** into `/Applications`.

### First launch (either way)

The app is signed but not notarized with a paid Apple Developer ID, so macOS blocks the first
launch with "Apple could not verify Stretch Goal is free of malware." Pick one:

- Click **Done**, open **System Settings → Privacy & Security**, scroll down and click
  **Open Anyway**. One time only.
- Or, in Terminal, clear the quarantine flag and launch:

  ```bash
  xattr -dr com.apple.quarantine "/Applications/Stretch Goal.app" && open "/Applications/Stretch Goal.app"
  ```

Then look for the walking figure in your menu bar. Turn on **Launch at login** in Settings so
it is always there.

## What it does

- **Sitting timer.** Detects keyboard and mouse activity. Idle for 3 minutes, or lock the
  screen, and your sit ends. Sit 20+ minutes before that and it counts as an earned break.
- **Nudges.** After 45 minutes of sitting (adjustable) a card slides in under your menu bar on
  every screen with one-click breaks. Too easy to ignore? Switch to the full-screen style in
  Settings. Repeats every 15 minutes until you actually move.
- **Guided breaks.** Move (3 min walk), Stretch (8 desk stretches, 4 min), Breathe (box
  breathing, 2 min), Eye rest (20 s). Only completed sessions count.
- **Water.** Tap 250 ml or 500 ml. Undo if you fat-fingered it.
- **Daily goals.** 6 breaks, 8 drinks, 2 mindful sessions. Hit all three for a bonus, hit them
  on consecutive weekdays for a streak multiplier. Weekends don't count for or against you.
- **History.** Last 30 days in a table.

### Scoring

| Action | Points | Daily goal | Daily cap |
|---|---|---|---|
| Break (detected or completed Move/Stretch) | 10 | 6 | 8 |
| Water | 3 | 8 | 10 |
| Mindful (completed Breathe/Eye rest) | 8 | 2 | 4 |
| All three goals hit | +25 | | |

Streak multiplier: +5% per consecutive perfect weekday carried into today, max +50%. Caps are
there so nobody wins by clicking the water button 400 times.

## Privacy

Everything is stored locally in `~/Library/Application Support/Stretch Goal/`. Nothing leaves
your Mac yet. When the team leaderboard ships, only daily totals (breaks, drinks, mindful
sessions, active time) will be shared, sharing will be opt-in, and you pick your nickname. Raw
activity timelines never leave the machine.

## Roadmap

1. ~~Local tracker~~ (this release)
2. Team leaderboard synced via the shared OneDrive library, one file per person so nobody
   overwrites anybody.
3. If it takes off: proper backend, iOS and watch apps on the same core package, Windows and
   Android clients.

## Development

```bash
brew install xcodegen
xcodegen generate
open StretchGoal.xcodeproj
```

Core logic (scoring, streaks, tracker state machine, sync format) is a pure Swift package with
no AppKit dependency so it can be reused on other platforms:

```bash
cd Packages/StretchGoalCore && swift test
```

Cut a release with `scripts/release.sh` (needs a checkout of the tap at `../homebrew-tap`).
The app icon is generated, not drawn by hand: `swift scripts/make-icon.swift out.png`, then
resize into `StretchGoal/Resources/Assets.xcassets/AppIcon.appiconset/`.
Design notes and the sync protocol are in [docs/SPEC.md](docs/SPEC.md).

## Why

We are good at closing tickets and bad at standing up. Built by Brian Phillips as a side
project for the software team. Suggestions and PRs welcome.
