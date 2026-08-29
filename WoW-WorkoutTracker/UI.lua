local addon = _G["WorkoutTracker"]

function addon:CreateUI()
    local f = CreateFrame("Frame", "WorkoutTrackerFrame", UIParent)
    f:SetSize(400, 500)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    f:SetBackdropBorderColor(0.4, 0.4, 0.4)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    
    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText("|cff00ff00WoW Workout Tracker|r")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    
    -- Dungeon
    local dungeonLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dungeonLabel:SetPoint("TOPLEFT", 10, -35)
    dungeonLabel:SetText("Dungeon: " .. WorkoutTrackerDB.currentDungeon)
    f.dungeonLabel = dungeonLabel
    
    -- Deaths counter
    local deathsLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    deathsLabel:SetPoint("TOPLEFT", 10, -60)
    deathsLabel:SetText("|cffff0000Deaths: |r" .. WorkoutTrackerDB.deaths)
    f.deathsLabel = deathsLabel
    
    -- Tier info
    local tier = addon:CalculateTier()
    local tierData = {
        [1] = "Foundation (Beginner)",
        [2] = "Building (Intermediate)",
        [3] = "Challenge (Upper Intermediate)",
        [4] = "Beast Mode (Advanced)",
    }
    
    local tierLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tierLabel:SetPoint("TOPLEFT", 10, -85)
    tierLabel:SetText("|cff00ff00Current Tier: |r" .. tierData[tier])
    f.tierLabel = tierLabel
    
    -- Exercises header
    local exerciseHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    exerciseHeader:SetPoint("TOPLEFT", 10, -110)
    exerciseHeader:SetText("|cffff9000Next Workout:|r")
    
    -- Exercises list
    local exercises = {
        [1] = {"10 Bodyweight Squats", "5 Wall Push-ups", "20 Second Wall Sit", "10 Glute Bridges"},
        [2] = {"15 Bodyweight Squats", "10 Incline Push-ups", "30 Second Wall Sit", "15 Glute Bridges", "20 Alternating Lunges"},
        [3] = {"20 Bodyweight Squats", "15 Incline Push-ups", "40 Second Wall Sit", "20 Glute Bridges", "30 Alternating Lunges", "10 Dumbbell Rows"},
        [4] = {"30 Bodyweight Squats", "20 Incline Push-ups", "1 Minute Wall Sit", "30 Glute Bridges", "40 Alternating Lunges", "15 Dumbbell Rows", "10 Knee Push-ups"},
    }
    
    local yOffset = -135
    for _, exercise in ipairs(exercises[tier]) do
        local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", 20, yOffset)
        label:SetText("  • " .. exercise)
        yOffset = yOffset - 20
    end
    
    -- Buttons
    local deathBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    deathBtn:SetSize(80, 25)
    deathBtn:SetPoint("BOTTOMLEFT", 10, 10)
    deathBtn:SetText("Log Death")
    deathBtn:SetScript("OnClick", function() addon:AddDeath() end)
    
    local wipeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    wipeBtn:SetSize(80, 25)
    wipeBtn:SetPoint("BOTTOMLEFT", 95, 10)
    wipeBtn:SetText("Log Wipe")
    wipeBtn:SetScript("OnClick", function() addon:AddWipe() end)
    
    local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetBtn:SetSize(80, 25)
    resetBtn:SetPoint("BOTTOMLEFT", 180, 10)
    resetBtn:SetText("Reset")
    resetBtn:SetScript("OnClick", function() addon:ResetSession() end)
    
    function f:Update()
        dungeonLabel:SetText("Dungeon: " .. WorkoutTrackerDB.currentDungeon)
        deathsLabel:SetText("|cffff0000Deaths: |r" .. WorkoutTrackerDB.deaths)
        local tier = addon:CalculateTier()
        tierLabel:SetText("|cff00ff00Current Tier: |r" .. tierData[tier])
    end
    
    self.mainFrame = f
end
