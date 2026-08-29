-- WoW Workout Tracker Core
--
-- Keystone tracking uses C_ChallengeMode.GetActiveKeystoneInfo(), a stable
-- Blizzard API (added Legion 7.0.3, confirmed present in the 12.1.0 client
-- build listing) returning (activeKeystoneLevel, activeAffixIDs, wasActiveKeystoneCharged).
-- We read it on CHALLENGE_MODE_START (mapID payload, added WoD 6.0.2, also
-- confirmed present on 12.1) and again on PLAYER_ENTERING_WORLD as a fallback
-- in case of reload-mid-key.

local addon = CreateFrame("Frame")
addon.name = "WoW-WorkoutTracker"

-- Default settings
local defaults = {
    enabled = true,
    deaths = 0,
    wipes = 0,
    bossWipes = 0,
    currentDungeon = "None",
    currentTier = 1,
    keystoneLevel = nil,
    lastBossWipeName = nil,
    lastBossWipeHealthPct = nil,
}

-- Workout tiers
local TIERS = {
    [1] = {
        name = "Foundation (Beginner)",
        exercises = {
            "10 Bodyweight Squats",
            "5 Wall Push-ups",
            "20 Second Wall Sit",
            "10 Glute Bridges",
        }
    },
    [2] = {
        name = "Building (Intermediate)",
        exercises = {
            "15 Bodyweight Squats",
            "10 Incline Push-ups",
            "30 Second Wall Sit",
            "15 Glute Bridges",
            "20 Alternating Lunges",
        }
    },
    [3] = {
        name = "Challenge (Upper Intermediate)",
        exercises = {
            "20 Bodyweight Squats",
            "15 Incline Push-ups",
            "40 Second Wall Sit",
            "20 Glute Bridges",
            "30 Alternating Lunges",
            "10 Dumbbell Rows (each side)",
        }
    },
    [4] = {
        name = "Beast Mode (Advanced)",
        exercises = {
            "30 Bodyweight Squats",
            "20 Incline Push-ups",
            "1 Minute Wall Sit",
            "30 Glute Bridges",
            "40 Alternating Lunges",
            "15 Dumbbell Rows (each side)",
            "10 Knee Push-ups",
        }
    },
}
addon.TIERS = TIERS

-- Each party-wide boss wipe (from BigWigs/LittleWigs) is worth this many
-- "effective deaths" toward tier escalation, on top of whatever deaths
-- happened during the pull. Wipes are the bigger signal of a hard pull,
-- so they weigh more than a single individual death.
local WIPE_DEATH_WEIGHT = 3

function addon:OnEvent(event, ...)
    if event == "ADDON_LOADED" and ... == "WoW-WorkoutTracker" then
        WorkoutTrackerDB = WorkoutTrackerDB or defaults
        for k, v in pairs(defaults) do
            if WorkoutTrackerDB[k] == nil then
                WorkoutTrackerDB[k] = v
            end
        end
        print("|cff00ff00WoW Workout Tracker|r loaded! Type |cff00ff00/wt|r for commands.")
        self:InitBossModIntegration()
    elseif event == "PLAYER_ENTERING_WORLD" then
        local dungeonName, _, _, _, _, _, _, dungeonID = GetInstanceInfo()
        if dungeonID and dungeonID > 0 then
            WorkoutTrackerDB.currentDungeon = dungeonName or "Unknown Dungeon"
        end
        self:RefreshKeystoneInfo()
    elseif event == "CHALLENGE_MODE_START" then
        self:RefreshKeystoneInfo()
    elseif event == "PLAYER_DEAD" then
        self:AddDeath()
    end
end

function addon:RefreshKeystoneInfo()
    if not C_ChallengeMode or not C_ChallengeMode.GetActiveKeystoneInfo then
        return -- defensive: guard against a future API removal/rename
    end

    local level = C_ChallengeMode.GetActiveKeystoneInfo()
    if level and level > 0 then
        WorkoutTrackerDB.keystoneLevel = level
        if self.mainFrame then
            self.mainFrame:Update()
        end
    end
end

function addon:AddDeath()
    WorkoutTrackerDB.deaths = WorkoutTrackerDB.deaths + 1

    if WorkoutTrackerDB.deaths % 5 == 0 then
        self:TriggerWorkout()
    end

    if self.mainFrame then
        self.mainFrame:Update()
    end
end

-- Manual wipe logging via /wt wipe (kept for when BigWigs/LittleWigs isn't
-- installed, or the user wants to log a wipe that wasn't boss-related).
function addon:AddWipe()
    WorkoutTrackerDB.wipes = WorkoutTrackerDB.wipes + 1
    if self.mainFrame then
        self.mainFrame:Update()
    end
end

-- Called from Events.lua when BigWigs/LittleWigs fires BigWigs_OnBossWipe.
-- lowestHealthPct is the lowest health% seen across all "bossN" units at
-- the moment of the wipe (nil if no boss units were populated).
function addon:RecordBossWipe(bossName, lowestHealthPct, snapshot)
    WorkoutTrackerDB.bossWipes = WorkoutTrackerDB.bossWipes + 1
    WorkoutTrackerDB.lastBossWipeName = bossName

    if lowestHealthPct then
        WorkoutTrackerDB.lastBossWipeHealthPct = lowestHealthPct
        print(("|cffff0000Wipe on %s|r - lowest boss health: %.1f%%"):format(bossName or "boss", lowestHealthPct))
    else
        WorkoutTrackerDB.lastBossWipeHealthPct = nil
        print(("|cffff0000Wipe on %s|r"):format(bossName or "boss"))
    end

    -- A boss wipe counts as extra weighted "deaths" toward tier escalation,
    -- separate from the per-player death counter used for the every-5-deaths
    -- workout trigger, so a bad pull can escalate difficulty even with few
    -- personal deaths.
    self:TriggerWorkout()

    if self.mainFrame then
        self.mainFrame:Update()
    end
end

function addon:RecordBossEngage(bossName)
    -- Currently informational only (no chat spam on pull) - reserved for
    -- future use (e.g. per-pull attempt counters).
end

function addon:CalculateTier()
    -- Personal deaths plus a weighted contribution from boss wipes.
    local effectiveDeaths = WorkoutTrackerDB.deaths + (WorkoutTrackerDB.bossWipes * WIPE_DEATH_WEIGHT)

    if effectiveDeaths >= 20 then
        return 4
    elseif effectiveDeaths >= 15 then
        return 3
    elseif effectiveDeaths >= 10 then
        return 2
    else
        return 1
    end
end

function addon:TriggerWorkout()
    local tier = self:CalculateTier()
    WorkoutTrackerDB.currentTier = tier

    local tierData = TIERS[tier]
    print("|cffff0000WORKOUT TIME!|r Tier: " .. tierData.name)
    print("Deaths: " .. WorkoutTrackerDB.deaths .. "  |  Boss Wipes: " .. WorkoutTrackerDB.bossWipes)

    for _, exercise in ipairs(tierData.exercises) do
        print("  " .. exercise)
    end
end

function addon:ResetSession()
    WorkoutTrackerDB.deaths = 0
    WorkoutTrackerDB.wipes = 0
    WorkoutTrackerDB.bossWipes = 0
    WorkoutTrackerDB.currentDungeon = "None"
    WorkoutTrackerDB.currentTier = 1
    WorkoutTrackerDB.keystoneLevel = nil
    WorkoutTrackerDB.lastBossWipeName = nil
    WorkoutTrackerDB.lastBossWipeHealthPct = nil
    if self.mainFrame then
        self.mainFrame:Update()
    end
    print("|cff00ff00Session reset!|r")
end

function addon:ShowStats()
    local tier = self:CalculateTier()
    local tierData = TIERS[tier]

    print("|cff00ff00=== Workout Stats ===|r")
    print("Dungeon: " .. WorkoutTrackerDB.currentDungeon)
    if WorkoutTrackerDB.keystoneLevel then
        print("Keystone Level: +" .. WorkoutTrackerDB.keystoneLevel)
    else
        print("Keystone Level: (none active)")
    end
    print("Deaths: " .. WorkoutTrackerDB.deaths)
    print("Manual Wipes: " .. WorkoutTrackerDB.wipes)
    print("Boss Wipes (BigWigs/LittleWigs): " .. WorkoutTrackerDB.bossWipes)
    if WorkoutTrackerDB.lastBossWipeName then
        local pctText = WorkoutTrackerDB.lastBossWipeHealthPct
            and ("%.1f%%"):format(WorkoutTrackerDB.lastBossWipeHealthPct)
            or "unknown"
        print("Last Boss Wipe: " .. WorkoutTrackerDB.lastBossWipeName .. " at " .. pctText .. " health")
    end
    print("Current Tier: " .. tierData.name)

    local effectiveDeaths = WorkoutTrackerDB.deaths + (WorkoutTrackerDB.bossWipes * 3)
    local nextThreshold = 5 - (effectiveDeaths % 5)
    if nextThreshold == 5 then nextThreshold = 0 end
    print("Next Workout: " .. nextThreshold .. " effective deaths away")

    if self.bossModIntegration == false then
        print("|cff888888(BigWigs/LittleWigs not detected - boss wipe auto-tracking disabled, use /wt wipe manually)|r")
    end
end

function addon:ShowHelp()
    print("|cff00ff00WoW Workout Tracker Commands:|r")
    print("  /wt show - Show UI window")
    print("  /wt death - Log a death")
    print("  /wt wipe - Log a manual wipe")
    print("  /wt stats - Show current stats")
    print("  /wt reset - Reset session")
end

function addon:ChatCommand(input)
    if input == "reset" then
        self:ResetSession()
    elseif input == "show" then
        self:ShowUI()
    elseif input == "stats" then
        self:ShowStats()
    elseif input == "death" then
        self:AddDeath()
    elseif input == "wipe" then
        self:AddWipe()
    else
        self:ShowHelp()
    end
end

function addon:ShowUI()
    if not self.mainFrame then
        self:CreateUI()
    else
        self.mainFrame:Show()
        self.mainFrame:Update()
    end
end

addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_ENTERING_WORLD")
addon:RegisterEvent("PLAYER_DEAD")
addon:RegisterEvent("CHALLENGE_MODE_START")
addon:SetScript("OnEvent", function(self, event, ...)
    addon:OnEvent(event, ...)
end)

SLASH_WT1 = "/wt"
SLASH_WORKOUT1 = "/workout"
SlashCmdList["WT"] = function(msg)
    addon:ChatCommand(msg)
end
SlashCmdList["WORKOUT"] = function(msg)
    addon:ChatCommand(msg)
end

_G["WorkoutTracker"] = addon
