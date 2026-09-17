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
it is always there. Only the copy in `/Applications` can register itself, and a second copy
launching while one is running quits immediately, so dev builds can't double up.

## What it does

- **Sitting timer.** Detects keyboard and mouse activity. Idle for 3 minutes, or lock the
  screen, and your sit ends. Sit 20+ minutes before that and it counts as an earned break.
- **Nudges.** After 45 minutes of sitting (adjustable) a card slides in under your menu bar on
  every screen with one-click breaks. Too easy to ignore? Switch to the full-screen style in
  Settings. Repeats every 15 minutes until you actually move.
- **Guided breaks.** Move (3 min walk), Stretch (8 desk stretches, 4 min), Breathe (box
  breathing, 2 min), Eye rest (20 s, the 20-20-20 rule). Only completed sessions count.
- **Water.** Tap 250 ml (a glass) or 500 ml (a bottle). Scored by volume: one drop per 250 ml,
  so 500 ml fills two. Stops at 2 L. Undo if you fat-fingered it.
- **Steps.** Log today's total off your phone or watch, or quick-add a walk. Milestones come
  with unhinged unit conversions (desk-to-Keurig runs, laps of the wash tunnel). Steps score
  and will have their own leaderboard column, but they don't gate the all-goals bonus, so
  people without a step counter can still streak. Automatic sync needs HealthKit, which
  doesn't exist on macOS; it lands with the iOS app.
- **Daily goals.** 8 breaks, 2 litres of water, 2 breathing sessions. Hit all three for a bonus,
  hit them on consecutive weekdays for a streak multiplier. Weekends don't count for or against
  you. Steps and eye rests score on top but never gate the bonus.
- **History.** Last 30 days in a table.
- **The voice.** Status lines, nudges, and celebrations rotate through a pool of lines in the
  register of [issue #1](../../issues/1). Functional labels stay plain; the flavor is in the
  secondary text. Add lines in `Packages/StretchGoalCore/Sources/StretchGoalCore/Quips.swift`.

### Scoring

| Action | Points | Daily goal | Daily cap |
|---|---|---|---|
| Break (20+ min sit ended by 3+ min away, or completed Move/Stretch) | 10 | 8 | 12 |
| Water, per 250 ml glass | 3 | 2,000 ml | 2,000 ml |
| Mindful (completed Breathe) | 8 | 2 | 4 |
| Eye rest (completed 20 s) | 2 | 4 | 12 |
| Steps, per 1,000 | 2 | 8,000 | 15,000 |
| Breaks + water + mindful goals all hit | +25 | | |

Streak multiplier: +5% per consecutive perfect weekday carried into today, max +50%. Caps are
there so nobody wins by clicking the water button 400 times.

### Where the numbers come from

This is a health app, so the targets follow commonly cited guidance rather than vibes:

- **Breaks, 8/day.** Public-health guidance on sedentary time says to break up sitting every
  30 to 60 minutes. Hourly over an 8-hour workday is 8. A break only counts after 20+ minutes
  seated and 3+ minutes away, so idle flapping can't farm it.
- **Water, 2,000 ml.** The "eight 8-oz glasses" heuristic, and inside the 2.0 to 2.5 L per day
  from beverages that EFSA and the US Institute of Medicine describe as adequate for adults.
  Coffee and tea count. Logging stops at 2 L: more is not a health target, so the app won't
  record it.
- **Breathing, 2 × 2 min.** Short daily breathwork of a few minutes shows measurable mood and
  stress effects in controlled studies; box breathing at 4-4-4-4 is the simplest version.
- **Eye rests, 4/day.** Optometry's 20-20-20 rule: every 20 minutes, look 20 feet away for 20
  seconds. Doing it every 20 minutes all day is ~24; four is the floor we celebrate.
- **Steps, 8,000.** A 2022 meta-analysis of 15 cohorts found mortality benefit plateauing around
  8,000 to 10,000 steps for adults under 60 and 6,000 to 8,000 over 60.

If you have better sources, open an issue. The rules live in one struct, `ScoringRules`.

### Nobody cheats

This is a competition, so every input has a guard:

- **Water** stops at the 2 L recommendation and refuses more than 750 ml in any 30 minutes.
  Nobody drinks two litres in a minute.
- **Guided breaks** watch your keyboard and mouse. Keep typing during a Move and it fails
  with no credit: 15 seconds of input tolerated for Move, 30 for Stretch, 15 for Breathe,
  5 for Eye rest. The first 3 seconds are ignored so you can lock the screen and push back
  your chair. Only real input counts: display sleep, wake, and the lock screen don't. Only
  completed, clean sessions score.
- **Detected breaks** need a 20-minute sit ended by 3+ minutes away, and a completed Move or
  Stretch consumes the current sit so it can't be credited twice.
- **Steps** are honor-system by nature, but entries clamp at 30,000 and only 15,000 score.
- **Points** are recomputed from raw counts by every reader, never trusted from a file, and
  every count is capped. Hover the points total for the exact arithmetic.

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
