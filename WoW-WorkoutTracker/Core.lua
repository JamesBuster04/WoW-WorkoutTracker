-- WoW Workout Tracker Core
local addon = CreateFrame("Frame")
addon.name = "WoW-WorkoutTracker"

-- Default settings
local defaults = {
    enabled = true,
    deaths = 0,
    wipes = 0,
    currentDungeon = "None",
    currentTier = 1,
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

function addon:OnEvent(event, ...)
    if event == "ADDON_LOADED" and ... == "WoW-WorkoutTracker" then
        WorkoutTrackerDB = WorkoutTrackerDB or defaults
        print("|cff00ff00WoW Workout Tracker|r loaded! Type |cff00ff00/wt|r for commands.")
    elseif event == "PLAYER_ENTERING_WORLD" then
        local dungeonName, _, _, _, _, _, _, dungeonID = GetInstanceInfo()
        if dungeonID and dungeonID > 0 then
            WorkoutTrackerDB.currentDungeon = dungeonName or "Unknown Dungeon"
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        self:HandleCombatLog()
    end
end

function addon:HandleCombatLog()
    local _, event, _, _, _, _, _, destGUID, destName = CombatLogGetCurrentEventInfo()
    
    if event == "UNIT_DIED" and destGUID == UnitGUID("player") then
        self:AddDeath()
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

function addon:AddWipe()
    WorkoutTrackerDB.wipes = WorkoutTrackerDB.wipes + 1
    if self.mainFrame then
        self.mainFrame:Update()
    end
end

function addon:CalculateTier()
    local deaths = WorkoutTrackerDB.deaths
    
    if deaths >= 20 then
        return 4
    elseif deaths >= 15 then
        return 3
    elseif deaths >= 10 then
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
    print("Deaths: " .. WorkoutTrackerDB.deaths)
    
    for _, exercise in ipairs(tierData.exercises) do
        print("  • " .. exercise)
    end
end

function addon:ResetSession()
    WorkoutTrackerDB.deaths = 0
    WorkoutTrackerDB.wipes = 0
    WorkoutTrackerDB.currentDungeon = "None"
    WorkoutTrackerDB.currentTier = 1
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
    print("Deaths: " .. WorkoutTrackerDB.deaths)
    print("Wipes: " .. WorkoutTrackerDB.wipes)
    print("Current Tier: " .. tierData.name)
    print("Next Workout: " .. (5 - (WorkoutTrackerDB.deaths % 5)) .. " deaths away")
end

function addon:ShowHelp()
    print("|cff00ff00WoW Workout Tracker Commands:|r")
    print("  /wt show - Show UI window")
    print("  /wt death - Log a death")
    print("  /wt wipe - Log a wipe")
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
    end
end

addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_ENTERING_WORLD")
addon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
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
