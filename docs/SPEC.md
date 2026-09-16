# Stretch Goal — MVP Spec

Desk-wellness menu bar app for macOS with a friendly team leaderboard synced through a shared
OneDrive/SharePoint folder. Personal project by Brian Phillips; no company build infrastructure.

Working name: **Stretch Goal** (dev pun, reads fine company-wide). Bundle id `com.brianp.StretchGoal`.
Rename is a one-line change in `project.yml` until the first release ships.

---

## 1. Goals

- Nudge developers to move, hydrate, stretch, and rest their eyes during the workday.
- Make it a light competition: weekly leaderboard across the team.
- Zero servers. Sync = each person writes their own files to a shared folder everyone syncs.
- Leave a clean path to a backend, accounts, iOS/watch, Windows/Android later.

Non-goals for MVP: accounts, server, push notifications across devices, HealthKit, step counts.

## 2. Platform and stack

| Item | Decision |
|---|---|
| Target | macOS 26.0+ only |
| Language | Swift 6.4, strict concurrency |
| UI | SwiftUI `MenuBarExtra(.window)` + one regular window (Leaderboard / History / Settings) |
| Project | XcodeGen `project.yml` → `StretchGoal.xcodeproj` (generated, gitignored) |
| Packages | `StretchGoalCore` (local SwiftPM package: model, scoring, sync format, merge) — no AppKit/SwiftUI imports, so iOS/watch/CLI can reuse it |
| Persistence | JSON files via `Codable`; no SwiftData/CoreData |
| Sandbox | Off (internal app; needs to read a shared folder freely) |
| Deps | None for MVP |

## 3. Features (MVP)

Mirrors Brian's current personal app, plus a team tab.

**Menu bar popover**
- Header: sitting timer ("Sitting for 3h 10m"), today's active time, longest sit.
- Rings: Breaks x/6, Water x/8, Mindful x/2.
- Water: tap +250 ml / +500 ml, undo.
- Take a break: Move (3 min), Breathe (4-4-4-4, 2 min), Stretch (full desk, ~4 min), Eye rest (20 s). Each is a guided countdown sheet. Scoring only on completion.
- Week strip: dots for each weekday showing goals hit.
- Today's points and current streak.
- Buttons: Leaderboard, History, Settings, Quit.

**Leaderboard window**
- This week (Mon–Sun, local time): rank, nickname, points, streak, goals-hit-today badge.
- Last week collapsed below.
- "Last synced" timestamp; offline badge when the shared folder is unreachable.

**Detection**
- Idle seconds via `CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: ...)`, sampled every 10 s.
- Screen lock / sleep / session resign via `NSWorkspace` + `DistributedNotificationCenter` count as away.
- Sitting timer starts on activity, resets after ≥ 3 min idle. A reset after ≥ 20 min of sitting = one detected break.
- Nudge notification at 45 min sitting (configurable), repeats every 15 min until a break.
- Optional work-hours window in Settings (default 07:00–18:00); nothing is counted outside it.

**Settings**
- Nickname (shown to the team), opt-in to sharing (default off until they flip it).
- Goals per day (breaks, water, mindful) and nudge interval.
- Shared folder (auto-detected, with Choose… fallback).
- Launch at login (`SMAppService`).

## 4. Scoring

Per day, all counts capped so spamming cannot win.

| Action | Points | Daily goal | Daily cap |
|---|---|---|---|
| Break (detected, or completed Move/Stretch) | 10 | 6 | 8 |
| Water tap (250 or 500 ml = 1 tap) | 3 | 8 | 10 |
| Mindful (completed Breathe/Eye rest) | 8 | 2 | 4 |
| All three goals hit | +25 bonus | | |

Streak = consecutive weekdays with all goals hit. Streak multiplier on the daily total:
`1 + min(streak, 10) * 0.05` (max 1.5×). Weekend days neither extend nor break a streak.

Weekly score = sum of daily totals Mon–Sun. Ties broken by streak, then by goals-hit days.

Scoring lives in `StretchGoalCore` as a pure function `Score.daily(DaySummary) -> Int` so every
client computes identical numbers from the same files.

## 5. Privacy

- Raw activity (idle samples, sitting segments, tap timestamps) never leaves the Mac.
- Only `DaySummary` (counts, points, goals hit, streak) is written to the shared folder.
- Sharing is opt-in. Off = app works fully solo, leaderboard shows only you.
- Nickname is the only identity shown. Folder name includes the OneDrive account slug only so
  the owner can recognize their own folder.

## 6. Sync protocol (the important part)

**Root**: `<SharePoint library>/Stretch Goal/` inside the already-synced
`Software Development Team - General` library. Auto-detected by globbing
`~/Library/CloudStorage/OneDrive-SharedLibraries-*/Software Development Team - General/Stretch Goal`.
Fallback: folder picker, path stored in UserDefaults.

**Layout** — one writer per file, always.

```
Stretch Goal/
  README.md                          # what this folder is, do not hand-edit
  members/
    <memberId>/
      profile.json                   # nickname, joined, schemaVersion  (owner writes)
      daily/
        2026-09-16.<deviceId>.json   # DaySummary                       (owner writes)
```

- `memberId` = lowercased email local-part if detectable from the OneDrive path, else a UUID
  created on first launch. Stored in Application Support; never changes.
- `deviceId` = short UUID per Mac. Two Macs for one person never touch the same file.
- Writes: serialize to a temp file in the same directory, then `rename` over the target.
  Rewrite today's file at most every 60 s and on every scoring event (debounced 5 s).
- Reads: enumerate `members/*/daily/*.json` for the current and previous ISO week only.
  Parse each; any file that is unreadable, not yet downloaded, or has an unknown
  `schemaVersion` is skipped, not fatal. Reads happen on a background task with a per-file
  timeout because File Provider may block to materialize a placeholder.
- Merge: per member per day, take the **max** of each count across device files (a laptop and
  a desktop both active double-count if summed). Points are recomputed locally from the
  merged summary, never trusted from the file.
- Refresh: `DispatchSource` file-system watch on `members/` plus a 60 s poll (OneDrive change
  events are not reliable). Last good leaderboard is cached locally so offline shows stale
  data with a badge instead of nothing.
- Nobody deletes anything. Old files are tiny; a cleanup is a later problem.

**DaySummary v1**

```json
{
  "schemaVersion": 1,
  "memberId": "brianp",
  "deviceId": "3f9a",
  "date": "2026-09-16",
  "timeZone": "America/Chicago",
  "breaks": 4,
  "waterTaps": 6,
  "mindful": 1,
  "activeSeconds": 18420,
  "longestSitSeconds": 5400,
  "updatedAt": "2026-09-16T15:42:10Z"
}
```

Streak and points are derived by readers from the sequence of days, so they cannot be edited in.

**Why this survives the backend later**: `DaySummary` is the ingest record. A future API is
`PUT /members/{id}/days/{date}` with the same body; the local writer gets a second destination
and the leaderboard reader swaps a folder enumeration for a GET.

## 7. Repo layout

```
stretch-goal/
  project.yml
  StretchGoal/                # app target: App, MenuBar, Windows, Services (idle, notifications, sync IO)
  Packages/StretchGoalCore/   # model, scoring, streaks, merge, JSON codecs, tests
  scripts/
    build.sh                  # xcodegen + xcodebuild archive → build/StretchGoal.app
    release.sh                # zip, ad-hoc sign, gh release upload, bump cask
  docs/SPEC.md
  README.md                   # install + first-run
```

## 8. Distribution (no CI, no company resources)

- Build locally with `scripts/build.sh`.
- Ad-hoc codesign for MVP. Users approve once in System Settings → Privacy & Security on first
  launch. Documented in README. Developer ID + notarization only if a personal Apple Developer
  membership is worth $99 later.
- Publish zips as GitHub Releases on a **personal** GitHub account (current `gh` login is the
  company account `brianp-tommycarwash`; switch or add a personal one before first release).
- Homebrew tap `homebrew-stretch-goal` with a cask so install is
  `brew install --cask --no-quarantine <tap>/stretch-goal` and updates are `brew upgrade`.

## 9. Phases

1. **Scaffold** — XcodeGen project, Core package with model + scoring + tests, empty menu bar app that launches. Commit.
2. **Local tracker** — idle detection, sitting timer, breaks/water/mindful, guided sessions, rings UI, nudges, local daily JSON, week strip, launch at login. Fully useful solo.
3. **Sync + leaderboard** — folder discovery, own-file writer, reader/merge, leaderboard window, offline cache, opt-in + nickname in Settings.
4. **Ship** — build/release scripts, README, brew cask, first tagged release to the team.
5. **Later, if it takes off** — backend + accounts, iOS/watch targets on the same Core package, Windows/Android clients writing the same DaySummary.

## 10. Open items

- Shared library path was not mounted when this spec was written (OneDrive cold). Auto-detect
  glob must be verified against the real path on first run.
- Whether two-Mac users are common enough to warrant showing per-device detail. MVP: max-merge silently.
- Exact stretch routine content for the guided Stretch session.
