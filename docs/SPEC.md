# Stretch Goal — MVP Spec

Desk-wellness menu bar app for macOS with a friendly team leaderboard synced through a shared
OneDrive/SharePoint folder. Side project by Brian Phillips; no company build infrastructure.

**Status:** MVP complete. Phases 1–4 shipped between 2026-09-16 (0.1.0) and 2026-09-21 (0.5.x).
This document is the design record; the README is the user-facing description.

Name: **Stretch Goal**. Bundle id `com.tommycarwash.StretchGoal`.

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

Mirrors Brian's earlier personal menu bar app, plus the team leaderboard.

**Menu bar popover**
- Header: sitting timer ("Sitting for 3h 10m"), today's active time, longest sit.
- Rings: Breaks x/8, Water ml/2,000, Mindful x/2. Eye rests and steps as rows.
- Water: tap +250 ml / +500 ml, undo. Drops fill per 250 ml glass.
- Take a break: Move (3 min), Breathe (4-4-4-4, 2 min), Stretch (full desk, ~4 min), Eye rest (20 s). Each is a guided countdown sheet. Scoring only on completion.
- Week strip: dots for each weekday showing goals hit.
- Today's points and current streak.
- Buttons: Leaderboard, History, Settings, Quit.

**Leaderboard window**
- This week / last week segmented picker (Mon–Sun, local time): rank, nickname, points, streak,
  perfect days, steps, goals-hit-today badge. Crown on first place; own row marked "you".
- Status line: synced-when, members sharing, skipped files; orange when the folder is missing
  or a sync failed. Empty states for sharing-off and only-you.
- Reachable via `stretchgoal://leaderboard`.

**Detection**
- Idle seconds via `CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: ...)`, sampled every 10 s.
- Screen lock / sleep / session resign via `NSWorkspace` + `DistributedNotificationCenter` count as away.
- Sitting timer starts on activity, resets after ≥ 3 min idle. A reset after ≥ 20 min of sitting = one detected break.
- Nudge at 45 min sitting (configurable), repeats every 15 min until a break. Three styles in
  Settings: **floating panel** (default; a non-activating card under the menu bar on every
  screen, never steals keyboard focus, auto-dismisses after 60 s), **full screen** (dims every
  screen until a break is picked or snoozed), or **system banner only**. A detected break, a
  started session, or a screen lock dismisses any visible nudge.
- Optional work-hours window in Settings (default 07:00–18:00); nothing is counted outside it.
- Guided sessions run in their own floating window (the menu bar popover closes on focus loss).
  The window is also reachable via `stretchgoal://session/<move|breathe|stretch|eyeRest>`, which
  is how notification actions open it.

**Settings**
- Nickname (shown to the team), opt-in to sharing (default off until they flip it).
- Nudge interval and repeat. Daily goals are **not** user-configurable: everyone scores against
  the same `ScoringRules.standard` so the leaderboard stays comparable.
- Shared folder (auto-detected, with Choose… fallback).
- Launch at login (`SMAppService`).
- Reminders (added 0.7.0): water card after N min (default 60) with no water logged, anchored
  to the last entry or first activity of the day; steps card once a day at a chosen time
  (default 16:00) if today's steps are 0. Both only in work hours and only when no other card
  is up. Steps editable for today and the previous two days; past-day edits republish that
  day's sync file.

## 4. Scoring

Per day, all counts capped so spamming cannot win.

| Action | Points | Daily goal | Daily cap |
|---|---|---|---|
| Break (detected, or completed Move/Stretch) | 10 | 8 | 12 |
| Water, per 250 ml glass (synced as `waterMl`) | 3 | 2,000 ml | 2,000 ml (logging stops; 750 ml / 30 min burst limit) |
| Mindful (completed Breathe) | 8 | 2 | 4 |
| Eye rest (completed 20 s) | 2 | 4 | 12 |
| Steps (per 1,000, manual entry) | 2 | 8,000 | 15,000 |
| Breaks + water + mindful goals hit (steps, eyes excluded) | +25 bonus | | |

Targets follow published guidance (see README "Where the numbers come from"); revised
2026-09-16 after Brian caught water scoring by tap instead of volume.

Streak = consecutive weekdays with all goals hit. Weekend days neither extend nor break a streak.
The multiplier on a day's total uses the streak **carried in** from preceding weekdays:
`1 + min(carried, 10) * 0.05` (max 1.5×). Day N of a run is scored at N-1 steps, so a lone
perfect day earns no multiplier and consistency is what pays.

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
  "waterMl": 1500,
  "mindful": 1,
  "eyeRests": 3,
  "steps": 8200,
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
- Ad-hoc codesign. Homebrew 7 quarantines every cask with no opt-out, so first launch needs a
  one-time Privacy & Security → Open Anyway, or `xattr -dr com.apple.quarantine`. Documented in
  README. Developer ID + notarization would remove that step; not done.
- Repo `Tommy-Car-Wash-Systems-Software/stretch-goal`; zips published as GitHub Releases by
  `scripts/release.sh` (decision 2026-09-16: company org is fine, company CI is not).
- Homebrew tap `Tommy-Car-Wash-Systems-Software/homebrew-tap` with cask `stretch-goal`:
  `brew tap` + `brew trust` + `brew install --cask stretch-goal`; updates are `brew upgrade`.
  Casks download with plain curl, so both repos are public (Brian's call, 2026-09-16).

## 9. Phases

1. ~~**Scaffold**~~ — done 2026-09-16.
2. ~~**Local tracker**~~ — done 2026-09-16 (0.1.0). Steps + voice 0.2.x, real-world targets 0.3.0,
   anti-cheat 0.4.x followed from issue #1 and Brian's review.
3. ~~**Sync + leaderboard**~~ — done 2026-09-21 (0.5.0), once OneDrive was back.
4. ~~**Ship**~~ — done 2026-09-16 (0.1.0 on GitHub Releases + brew tap); README tour 0.5.1.
5. **Later, if it takes off** — backend + accounts, iOS/watch targets on the same Core package
   (HealthKit step sync, the open half of issue #1), Windows/Android clients writing the same DaySummary.

## 9b. Post-MVP additions (0.6–0.8, 2026-09-21 → 23)

- Share card (0.6): 1200×630 render of the day with rings, tiles, quip, repo QR; copy/text/share/save.
- Reminders (0.7): water after N min, steps once a day; steps editable for 3 days.
- 0.8: microphone-in-use = in a call (sit continues, no credit, nudges hold); standing-desk mode
  (sit ends without credit, held until toggled off); menu bar icon reflects state; first-run
  welcome window; Monday recap card + pasteable team recap; stop-sharing-and-remove-my-files;
  update check against GitHub Releases every 6 h. Notarization deliberately still not done.

## 10. Voice (issue #1, 2026-09-16)

Amanda's step-tracking request came with a register the team liked, so the whole app speaks
it: lowercase, slang-forward, workplace-safe. Lines live in `Quips` (Core), are picked
deterministically from a seed so views do not flicker, and rotate on a 15-minute bucket. Rules:
functional labels (buttons, settings, table headers) stay plain; flavor is secondary text only.

## 11. Open items

- ~~Shared library path~~ verified 2026-09-21: the mount name carries a numeric suffix on
  Brian's Mac (`OneDrive-SharedLibraries-TommyCarWashSystems 2 2`), so discovery lists
  `~/Library/CloudStorage/OneDrive-SharedLibraries-*` and picks the first containing the library.
- Whether two-Mac users are common enough to warrant showing per-device detail. Today: max-merge silently.
- ~~Stretch routine content~~ — eight 30 s steps, in `GuidedSession.standard(.stretch)`.
- Notarization, if the Gatekeeper step turns out to cost adoption.
