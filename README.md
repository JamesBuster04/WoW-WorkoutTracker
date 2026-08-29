# WoW Workout Tracker

Auto-track deaths in World of Warcraft Mythic+ dungeons and calculate workout tiers tied to in-game performance.

## Installation

### WoWUp-CF
1. Open WoWUp-CF
2. Click "Install from URL"
3. Paste: `https://github.com/JamesBuster04/WoW-WorkoutTracker`
4. Click Install
5. Enable addon in WoW

### Manual
1. Download or clone repo
2. Copy `WoW-WorkoutTracker/` to `World of Warcraft/_retail_/Interface/AddOns/`
3. Restart WoW
4. Enable in AddOns menu

## Commands

- `/wt show` - Open tracker UI
- `/wt death` - Log a death manually
- `/wt wipe` - Log a party wipe
- `/wt stats` - Show current stats
- `/wt reset` - Reset session for new dungeon

## How It Works

1. **Auto-tracks deaths** - Monitors combat log automatically
2. **Calculates tier** - Every 5 deaths triggers next workout tier
3. **Shows exercises** - Displays workout in UI and chat
4. **Persistent** - Tracks data throughout dungeon session

## Tier System

- **0-4 deaths** → Tier 1: Foundation (Beginner)
- **5-9 deaths** → Tier 2: Building (Intermediate)  
- **10-14 deaths** → Tier 3: Challenge (Upper Intermediate)
- **15+ deaths** → Tier 4: Beast Mode (Advanced)

## Features

✓ Real-time death tracking
✓ Auto-calculate workout tiers
✓ In-game UI window
✓ Slash commands
✓ Session persistence
✓ Works in all M+ difficulties

## Requirements

- WoW Retail (Dragonflight)
- No dependencies

---

Version: 1.0.0
