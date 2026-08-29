# WoW Workout Tracker

[![Interface](https://img.shields.io/badge/Interface-12.1.0-blue)](https://github.com/JamesBuster04/WoW-WorkoutTracker)
[![Release](https://img.shields.io/badge/release-v1.1.0-brightgreen)](https://github.com/JamesBuster04/WoW-WorkoutTracker/releases/latest)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

A lightweight World of Warcraft addon that converts your Mythic+ death counter — and now your boss wipes — into a real-world calisthenics program. Zero hard dependencies, just a `Frame`, a `CombatLogGetCurrentEventInfo()` hook, and an optional soft-integration with BigWigs/LittleWigs for real party-wide wipe detection.

Every death is logged automatically from the combat log. Every boss wipe (detected via BigWigs/LittleWigs, if installed) escalates difficulty further, weighted more heavily than a single death. Current keystone level is tracked and displayed. All of it surfaces in an in-game UI panel and in chat. Built for **WoW 12.1 (Midnight)**.

---

## Table of Contents

- [Compatibility](#compatibility)
- [Installation](#installation)
- [Usage](#usage)
- [Tier System](#tier-system)
- [BigWigs / LittleWigs Integration](#bigwigs--littlewigs-integration)
- [Keystone Tracking](#keystone-tracking)
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

The core addon relies only on long-standing, stable Blizzard APIs (`CreateFrame`, `CombatLogGetCurrentEventInfo`, `GetInstanceInfo`, `UnitGUID`, `C_ChallengeMode.GetActiveKeystoneInfo`) rather than anything Midnight-specific, so it should degrade gracefully on adjacent patch versions. That said, the `## Interface` directive in the `.toc` is pinned to `120100` — if the client's Interface version doesn't match closely enough, WoW will flag it as out of date on the AddOns screen. You can force-load it via **AddOns → Load out of date AddOns** if needed, at your own risk.

**Optional integration:** [BigWigs](https://www.curseforge.com/wow/addons/bigwigs) and/or [LittleWigs](https://www.curseforge.com/wow/addons/littlewigs) for automatic party-wide boss wipe detection. Neither is required — the addon detects their presence at runtime and silently falls back to manual `/wt wipe` logging if absent.

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

### Optional — BigWigs / LittleWigs

For automatic boss wipe tracking, install either (or both — they share the same underlying loader):

- [BigWigs](https://www.curseforge.com/wow/addons/bigwigs)
- [LittleWigs](https://www.curseforge.com/wow/addons/littlewigs) (dungeon boss modules that plug into BigWigs' core)

No configuration needed on either side — WoW Workout Tracker detects `BigWigsLoader` at load time and hooks in automatically. If neither is installed, boss wipes just don't auto-track; everything else (deaths, keystone level, manual wipe logging) works exactly the same.

## Usage

The addon tracks silently in the background from login. No setup required.

| Command | Effect |
|---|---|
| `/wt show` or `/workout show` | Open the tracker UI window |
| `/wt death` | Manually increment the death counter |
| `/wt wipe` | Log a manual wipe (use this if BigWigs/LittleWigs isn't installed) |
| `/wt stats` | Print dungeon, keystone level, deaths, wipes, and tier to chat |
| `/wt reset` | Zero out the session — run this before pulling a new key |

**Recommended flow:** `/wt reset` right before you accept the Mythic+ ready check, then let it run. Deaths are picked up automatically by polling your own alive/dead state twice a second. If BigWigs/LittleWigs is installed, boss wipes are picked up automatically too — you shouldn't need `/wt death` or `/wt wipe` unless you're debugging or running without a boss mod.

## Tier System

Difficulty scales with **effective deaths** — personal deaths plus a weighted contribution from boss wipes:

```
effective deaths = personal deaths + (boss wipes × 3)
```

| Effective Deaths | Tier | Focus |
|---|---|---|
| 0–9 | **Tier 1** — Foundation | Bodyweight basics, joint-friendly |
| 10–14 | **Tier 2** — Building | Added volume, incline push-ups |
| 15–19 | **Tier 3** — Challenge | Compound movements, resistance rows |
| 20+ | **Tier 4** — Beast Mode | Max-effort superset |

Every 5th personal death (`deaths % 5 == 0`) *and* every boss wipe fires a workout prompt for the tier calculated at that moment. A boss wipe is weighted at 3x a personal death because it's a stronger signal of a genuinely hard pull than any one individual mistake — two wipes with zero deaths (6 effective) still won't escalate you past Tier 1, but two wipes plus a handful of deaths will tip you into Tier 2 quickly.

Manual `/wt wipe` logging (via the button or slash command) is tracked separately as a simple counter and is **not** currently weighted into the tier calculation — it exists for visibility when BigWigs/LittleWigs isn't installed. See [Known Limitations](#known-limitations).

## BigWigs / LittleWigs Integration

WoW Workout Tracker hooks BigWigs' public message bus, `BigWigsLoader`, to detect real party-wide boss wipes — not just your own deaths.

**How it works:**

1. On load, the addon checks for `_G.BigWigsLoader`. If it's missing (BigWigs/LittleWigs not installed, or not yet loaded), integration silently disables itself — no errors, no nagging.
2. If present, it registers against `BigWigs_OnBossWipe` and `BigWigs_OnBossEngage` via `BigWigsLoader.RegisterMessage(...)`.
3. The moment a wipe fires, the addon independently reads boss health from Blizzard's own `bossN` unit tokens (`UnitHealth`/`UnitHealthMax` against `boss1` through `boss8`) rather than relying on BigWigs' internal, undocumented wipe payload. This keeps the health-percent reading accurate regardless of BigWigs' internal version.
4. The boss name and lowest remaining health % across all active boss units is recorded and shown in both chat and the UI.

This was built by reading BigWigs' actual source (`Core/BossPrototype.lua`, `Plugins/Wipe.lua`, `Loader.lua`) rather than guessing at an API surface — `BigWigs_OnBossWipe` is the message BigWigs' own developers use internally for wipe detection (their code explicitly comments *"Do NOT use this for wipe detection, use BigWigs_OnBossWipe"* above the encounter-end message), so this addon follows the same pattern.

**Status indicator:** the UI window shows a footer line confirming whether BigWigs/LittleWigs was detected on load.

## Keystone Tracking

Current Mythic+ keystone level is captured via `C_ChallengeMode.GetActiveKeystoneInfo()` on two triggers:

- `CHALLENGE_MODE_START` (fires the moment the key is inserted and the timer starts)
- `PLAYER_ENTERING_WORLD` (fallback, in case of a reload or relog mid-key)

The level is purely informational right now — displayed in the UI and in `/wt stats` — and does not yet factor into tier scaling. See [Known Limitations](#known-limitations) for why, and what a keystone-weighted tier system would need.

## Architecture

Zero hard dependencies — no Ace3, no LibStub shims, no external libraries to break on API changes. BigWigs/LittleWigs are a soft, optional integration, not a build-time dependency. Three files, single responsibility each:

```
WoW-WorkoutTracker/
├── WoW-WorkoutTracker.toc   # Metadata, load order, Interface pin
├── Core.lua                 # Event registration, state machine, tier logic, keystone capture, slash commands
├── UI.lua                   # Frame construction (vanilla widget API, not AceGUI)
└── Events.lua               # BigWigs/LittleWigs soft integration (guarded, no-ops if absent)
```

**Event flow:**

```
ADDON_LOADED                → initialize WorkoutTrackerDB, call InitBossModIntegration()
PLAYER_ENTERING_WORLD       → capture instance name via GetInstanceInfo()
                             → capture keystone level via C_ChallengeMode.GetActiveKeystoneInfo()
CHALLENGE_MODE_START        → re-capture keystone level (key freshly started)
(polled every 0.2s)        → UnitIsDeadOrGhost("player") flips false->true
                             → AddDeath() → tier recalculation → UI:Update()

[If BigWigsLoader is present at ADDON_LOADED time:]
BigWigs_OnBossWipe   (via BigWigsLoader.RegisterMessage) → read boss1-boss8 health via
                                                             UnitHealth/UnitHealthMax
                                                          → RecordBossWipe() → tier
                                                             recalculation (weighted 3x)
                                                          → UI:Update()
BigWigs_OnBossEngage (via BigWigsLoader.RegisterMessage) → RecordBossEngage() (currently
                                                             informational only)
```

The UI frame is built with the raw Widget API (`CreateFrame`, `CreateFontString`, `UIPanelButtonTemplate`) rather than a framework, and explicitly requests the `BackdropTemplate` mixin on frame creation — required for `SetBackdrop`/`SetBackdropColor` calls to function since the Battle for Azeroth widget API split. Omitting this mixin is a common cause of addons throwing `attempt to call method 'SetBackdrop' (a nil value)` on modern clients; this addon carries a regression check for exactly that (see Changelog, v1.0.2).

**Why `BigWigsLoader` and not a hard `## Dependencies:` entry in the .toc:** BigWigs exposes `BigWigsLoader` as a global the moment it loads, independent of whether any consuming addon declares a formal dependency. Treating it as a soft, runtime-detected integration means WoW Workout Tracker keeps working standalone for users who don't run a boss mod, rather than refusing to load or nagging about a missing dependency.

## SavedVariables

Session state persists in `WorkoutTrackerDB` (account-wide, not per-character):

```lua
WorkoutTrackerDB = {
    enabled = true,
    deaths = 0,
    wipes = 0,                    -- manual /wt wipe count
    bossWipes = 0,                -- BigWigs/LittleWigs-detected boss wipes
    currentDungeon = "None",
    currentTier = 1,
    keystoneLevel = nil,          -- current M+ level, nil if none active
    lastBossWipeName = nil,       -- boss name from the most recent auto-tracked wipe
    lastBossWipeHealthPct = nil,  -- lowest boss health % seen at that wipe (nil if unavailable)
}
```

Stored in `WTF/Account/<ACCOUNT>/SavedVariables/WoW-WorkoutTracker.lua`, written on logout/reload. Delete this file to fully reset addon state outside of `/wt reset`. Upgrading from a pre-1.1.0 install is safe — missing keys are backfilled from defaults on load rather than requiring a clean wipe.

## Known Limitations

- **Manual wipes aren't tier-weighted.** Only BigWigs/LittleWigs-detected boss wipes count toward the 3x tier-escalation weight described in [Tier System](#tier-system). `/wt wipe` increments a separate, informational-only counter. If you don't run a boss mod, tier escalation is driven by personal deaths alone.
- **Keystone level is display-only.** It's captured and shown, but does not currently scale workout difficulty — e.g. a +20 key wipe and a +2 key wipe are weighted identically right now. A future version could factor `keystoneLevel` directly into `CalculateTier()`.
- **Boss health snapshot is instantaneous, not sustained.** Health is read the moment `BigWigs_OnBossWipe` fires, via the live `bossN` unit tokens. In fast-decaying multi-boss encounters this is generally accurate, but it reflects whatever health values are visible at that exact tick, not an average over the pull.
- **Account-wide, not per-character** SavedVariables, so alts share one running total unless you `/wt reset` between characters.
- **Single-window UI**, non-resizable, no drag-to-edge snapping — functional, not fancy.
- **`BigWigs_OnBossEngage` is currently a no-op** beyond capturing the boss name — reserved for a future per-pull attempt counter.

## Troubleshooting

**"No valid zip file" on WoWUp-CF install**
This means the repo has no GitHub Release with a `.zip` asset attached, or the release is stale relative to `main`. Check [Releases](https://github.com/JamesBuster04/WoW-WorkoutTracker/releases) for the latest tag.

**UI window doesn't open / Lua error on `/wt show`**
Confirm you're on v1.0.2 or later — earlier tags were missing the `BackdropTemplate` mixin and will throw on frame creation.

**Boss wipes aren't tracking automatically**
Check the UI window's footer status line, or run `/wt stats` and look for the note about BigWigs/LittleWigs detection. If it says not detected, confirm BigWigs (or LittleWigs, which requires BigWigs' core) is installed *and enabled*, and that it has fully loaded before WoW Workout Tracker's `ADDON_LOADED` fires — load order between addons is alphabetical-ish but not guaranteed, so if detection seems flaky after a fresh install of BigWigs, `/reload` once.

**Addon greyed out / "out of date" on AddOns screen**
The `.toc` Interface number doesn't match your client build closely enough. Enable **Load out of date AddOns** in the AddOns menu, or wait for a `.toc` bump matching your patch.

**Deaths not incrementing automatically**
As of v1.1.3, death detection no longer depends on any Blizzard death-notification event at all — it polls `UnitIsDeadOrGhost("player")` every 0.2s and counts a death on the false→true transition. This was a deliberate move away from events after `PLAYER_DEAD` (v1.1.2) missed a real fall-damage death in live testing, and there's no combat log access left post-12.0.0 to cross-check which death-cause events Blizzard does or doesn't fire consistently. Reading our own unit's live state instead of reacting to a notification sidesteps that whole class of problem. Confirm you're on v1.1.3+. If it's still not counting, run `/wt death` to confirm the counter/UI itself works (isolates a display bug from a detection bug) and check for Lua errors with BugSack/BugGrabber.

**Keystone level shows as "none active"**
This is expected outside of an active Mythic+ run — `C_ChallengeMode.GetActiveKeystoneInfo()` only returns a level once a key has been inserted and the timer started (`CHALLENGE_MODE_START`).

## Changelog

| Version | Notes |
|---|---|
| **1.1.3** | Fixed death tracking still missing deaths after v1.1.2 (confirmed live: a fall-damage death in the open world wasn't counted, though `/wt death` proved the counter/UI itself was fine). Dropped event-based death detection entirely — no more `PLAYER_DEAD`/`UNIT_DIED`/combat log dependency of any kind. Now polls `UnitIsDeadOrGhost("player")` on an OnUpdate timer (0.2s interval) and counts a death on the false->true transition, with `wasDead` seeded correctly at load so a `/reload` while already dead doesn't double-count. Sidesteps the entire class of "which death-cause events does this patch actually fire" uncertainty that broke the two previous approaches. |
| **1.1.2** | Fixed death tracking still not firing live in-game after v1.1.1: replaced `UNIT_DIED` + `UnitGUID("player")` comparison with the `PLAYER_DEAD` event, which fires exclusively for the player's own death with no payload and no GUID comparison. Avoids a suspected interaction with Patch 12.0.0's "secret value" restrictions on unit identity inside active Mythic+ instances, which can silently break naive GUID equality checks. |
| **1.1.1** | Fixed broken auto death tracking: Patch 12.0.0 removed addon access to `COMBAT_LOG_EVENT_UNFILTERED` entirely, which the old death-detection path relied on. Replaced with the new `UNIT_DIED` frame event (registered directly, no combat log parsing needed) per Blizzard's documented replacement. Removed the now-dead `HandleCombatLog()`/`CombatLogGetCurrentEventInfo()` code path. |
| **1.1.0** | Added optional BigWigs/LittleWigs integration for automatic party-wide boss wipe detection (`BigWigs_OnBossWipe` via `BigWigsLoader.RegisterMessage`), with boss health read independently via stable `bossN` unit tokens. Added Mythic+ keystone level tracking via `C_ChallengeMode.GetActiveKeystoneInfo()`. Tier calculation now weighs boss wipes at 3x a personal death. UI updated to show keystone level, boss wipe count, last-wipe detail, and integration status. |
| **1.0.2** | Fixed `SetBackdrop` failing on modern clients — added `BackdropTemplate` mixin to `CreateFrame` call. Verified against WoW 12.1 (Interface `120100`). |
| **1.0.1** | Bumped Interface to `120100` for WoW 12.1 (Midnight) compatibility. |
| **1.0.0** | Initial release — death tracking, tier calculation, UI window, slash commands. |

## Contributing

Issues and PRs welcome. If you're adding a feature, keep the zero-hard-dependency philosophy — BigWigs/LittleWigs integration is soft/optional by design, and this addon should stay small enough to audit in one sitting. Bug reports should include your WoW build number (`/dump GetBuildInfo()`), whether BigWigs/LittleWigs is installed, and, if it's a Lua error, the full `!BugGrabber`/`BugSack` trace if you have one installed.

## License

MIT — do whatever you want with it, including extending it with keystone-weighted tier scaling or per-pull attempt tracking.

---

**Author:** JamesBuster04
**Repo:** https://github.com/JamesBuster04/WoW-WorkoutTracker
