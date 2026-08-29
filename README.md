# WoW Workout Tracker

[![Interface](https://img.shields.io/badge/Interface-12.1.0-blue)](https://github.com/JamesBuster04/WoW-WorkoutTracker)
[![Release](https://img.shields.io/badge/release-v1.0.2-brightgreen)](https://github.com/JamesBuster04/WoW-WorkoutTracker/releases/latest)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

A lightweight World of Warcraft addon that converts your Mythic+ death counter into a real-world calisthenics program. No dependencies, no bloat — just a `Frame`, a `CombatLogGetCurrentEventInfo()` hook, and a reason to hate wiping slightly less.

Every death is logged automatically from the combat log. Every fifth death escalates you to a harder tier of exercises, displayed both in an in-game UI panel and in chat. Built for **WoW 12.1 (Midnight)**.

---

## Table of Contents

- [Compatibility](#compatibility)
- [Installation](#installation)
- [Usage](#usage)
- [Tier System](#tier-system)
- [Architecture](#architecture)
- [SavedVariables](#savedvariables)
- [Known Limitations](#known-limitations)
- [Troubleshooting](#troubleshooting)
- [Changelog](#changelog)
- [Contributing](#contributing)
- [License](#license)

---

## Compatibility

| WoW Version | Interface Number | Status |
|---|---|---|
| 12.1.x (Midnight) | `120100` | ✅ Supported (primary target) |
| 11.x (The War Within) | `110000` | ⚠️ Untested — API surface used here is stable across expansions, but not validated |
| Classic / Wrath Classic | — | ❌ Not supported |

The addon relies only on long-standing, stable Blizzard APIs (`CreateFrame`, `CombatLogGetCurrentEventInfo`, `GetInstanceInfo`, `UnitGUID`) rather than anything Dragonflight/Midnight-specific, so it should degrade gracefully on adjacent patch versions. That said, the `## Interface` directive in the `.toc` is pinned to `120100` — if the client's Interface version doesn't match closely enough, WoW will flag it as out of date on the AddOns screen. You can force-load it via **AddOns → Load out of date AddOns** if needed, at your own risk.

## Installation

### Option A — WoWUp / WoWUp-CF (recommended)

1. Open WoWUp
2. **Get Addons → Install from URL**
3. Paste the repo URL:
   ```
   https://github.com/JamesBuster04/WoW-WorkoutTracker
   ```
4. Install, then enable **WoW Workout Tracker** on the character-select AddOns screen

> WoWUp resolves installs against **GitHub Releases**, not the raw repo tree. If an install ever fails with "no valid zip," check that a [release](https://github.com/JamesBuster04/WoW-WorkoutTracker/releases) with an attached `.zip` asset exists — pushing to `main` alone does not produce one.

### Option B — Manual

1. Download the latest release zip: [`WoW-WorkoutTracker.zip`](https://github.com/JamesBuster04/WoW-WorkoutTracker/releases/latest)
2. Extract so the path looks like:
   ```
   World of Warcraft/_retail_/Interface/AddOns/WoW-WorkoutTracker/WoW-WorkoutTracker.toc
   ```
3. Fully restart the client (not just reload UI — a fresh addon needs a client restart to register)
4. Enable it on the AddOns screen

### Option C — Git

```bash
git clone https://github.com/JamesBuster04/WoW-WorkoutTracker.git
cp -r WoW-WorkoutTracker/WoW-WorkoutTracker "path/to/World of Warcraft/_retail_/Interface/AddOns/"
```

## Usage

The addon tracks silently in the background from login. No setup required.

| Command | Effect |
|---|---|
| `/wt show` or `/workout show` | Open the tracker UI window |
| `/wt death` | Manually increment the death counter |
| `/wt wipe` | Log a wipe (flags a rep penalty on the next workout) |
| `/wt stats` | Print current dungeon, deaths, wipes, and tier to chat |
| `/wt reset` | Zero out the session — run this before pulling a new key |

**Recommended flow:** `/wt reset` right before you accept the Mythic+ ready check, then let it run. Deaths are picked up automatically via `UNIT_DIED` on your own `UnitGUID`; you shouldn't need `/wt death` unless you're debugging.

## Tier System

Difficulty scales with cumulative deaths in the current session:

| Deaths | Tier | Focus |
|---|---|---|
| 0–4 | **Tier 1** — Foundation | Bodyweight basics, joint-friendly |
| 5–9 | **Tier 2** — Building | Added volume, incline push-ups |
| 10–14 | **Tier 3** — Challenge | Compound movements, resistance rows |
| 15+ | **Tier 4** — Beast Mode | Max-effort superset |

Every 5th death (`deaths % 5 == 0`) fires a workout prompt for the *current* tier — the tier itself only escalates at the 5/10/15/20 death thresholds, so a bad pull doesn't retroactively make earlier workouts harder. Wipes don't change tier; they add a rep penalty to whichever workout triggers next.

## Architecture

Deliberately dependency-free — no Ace3, no LibStub shims, no external libraries to break on API changes. Three files, single responsibility each:

```
WoW-WorkoutTracker/
├── WoW-WorkoutTracker.toc   # Metadata, load order, Interface pin
├── Core.lua                 # Event registration, state machine, tier logic, slash commands
├── UI.lua                   # Frame construction (vanilla widget API, not AceGUI)
└── Events.lua               # Reserved for future event-handling separation
```

**Event flow:**

```
ADDON_LOADED               → initialize WorkoutTrackerDB
PLAYER_ENTERING_WORLD      → capture current instance name via GetInstanceInfo()
COMBAT_LOG_EVENT_UNFILTERED → filter for UNIT_DIED where destGUID == UnitGUID("player")
                            → AddDeath() → tier recalculation → UI:Update()
```

The UI frame is built with the raw Widget API (`CreateFrame`, `CreateFontString`, `UIPanelButtonTemplate`) rather than a framework, and explicitly requests the `BackdropTemplate` mixin on frame creation — required for `SetBackdrop`/`SetBackdropColor` calls to function since the Battle for Azeroth widget API split. Omitting this mixin is a common cause of addons throwing `attempt to call method 'SetBackdrop' (a nil value)` on modern clients; this addon carries a regression check for exactly that (see `CHANGELOG` v1.0.2).

## SavedVariables

Session state persists in `WorkoutTrackerDB` (account-wide, not per-character):

```lua
WorkoutTrackerDB = {
    deaths = 0,
    wipes = 0,
    currentDungeon = "None",
    currentTier = 1,
    enabled = true,
}
```

Stored in `WTF/Account/<ACCOUNT>/SavedVariables/WoW-WorkoutTracker.lua`, written on logout/reload. Delete this file to fully reset addon state outside of `/wt reset`.

## Known Limitations

- **No party-wide wipe detection.** `PARTY_KILL` (used for `/wt wipe` parity in-code) tracks NPC kills, not group wipes — genuine wipe detection would need to poll all party member health via `UnitHealth`/`UnitIsDeadOrGhost` across `GROUP_ROSTER_UPDATE`, which isn't implemented yet. Use `/wt wipe` manually for now.
- **No Mythic+ keystone level captured**, only the dungeon name — tier scaling is death-count based, not key-level based.
- **Account-wide, not per-character** SavedVariables, so alts share one running total unless you `/wt reset` between characters.
- **Single-window UI**, non-resizable, no drag-to-edge snapping — functional, not fancy.

## Troubleshooting

**"No valid zip file" on WoWUp-CF install**
This means the repo has no GitHub Release with a `.zip` asset attached, or the release is stale relative to `main`. Check [Releases](https://github.com/JamesBuster04/WoW-WorkoutTracker/releases) for the latest tag.

**UI window doesn't open / Lua error on `/wt show`**
Confirm you're on v1.0.2 or later — earlier tags were missing the `BackdropTemplate` mixin and will throw on frame creation.

**Addon greyed out / "out of date" on AddOns screen**
The `.toc` Interface number doesn't match your client build closely enough. Enable **Load out of date AddOns** in the AddOns menu, or wait for a `.toc` bump matching your patch.

**Deaths not incrementing automatically**
Verify combat log filtering isn't blocked by another addon overriding `COMBAT_LOG_EVENT_UNFILTERED` globally (rare), and confirm you're actually the one dying — `destGUID` is matched against `UnitGUID("player")` specifically, not party members.

## Changelog

| Version | Notes |
|---|---|
| **1.0.2** | Fixed `SetBackdrop` failing on modern clients — added `BackdropTemplate` mixin to `CreateFrame` call. Verified against WoW 12.1 (Interface `120100`). |
| **1.0.1** | Bumped Interface to `120100` for WoW 12.1 (Midnight) compatibility. |
| **1.0.0** | Initial release — death tracking, tier calculation, UI window, slash commands. |

## Contributing

Issues and PRs welcome. If you're adding a feature, keep the zero-dependency philosophy — this addon is intentionally small enough to audit in one sitting. Bug reports should include your WoW build number (`/dump GetBuildInfo()`) and, if it's a Lua error, the full `!BugGrabber`/`BugSack` trace if you have one installed.

## License

MIT — do whatever you want with it, including making it into something with actual API integrations for keystone level and party-wide wipe detection.

---

**Author:** JamesBuster04
**Repo:** https://github.com/JamesBuster04/WoW-WorkoutTracker
