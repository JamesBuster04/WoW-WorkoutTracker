local addon = _G["WorkoutTracker"]

local MIN_WIDTH, MIN_HEIGHT = 320, 420
local MAX_WIDTH, MAX_HEIGHT = 900, 900

function addon:CreateUI()
    local f = CreateFrame("Frame", "WorkoutTrackerFrame", UIParent, "BackdropTemplate")
    f:SetSize(WorkoutTrackerDB.frameWidth or 420, WorkoutTrackerDB.frameHeight or 560)
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
    f:SetResizable(true)
    f:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    -- Resize grip in the bottom-right corner - drag to resize independently
    -- of the whole-frame drag (which moves it). Standard Blizzard chat-frame
    -- sizing textures so it matches the native look.
    local resizer = CreateFrame("Button", nil, f)
    resizer:SetSize(16, 16)
    resizer:SetPoint("BOTTOMRIGHT", -4, 4)
    resizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizer:SetScript("OnMouseDown", function()
        f:StartSizing("BOTTOMRIGHT")
    end)
    resizer:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
    end)

    -- Fires on any size change (drag-resize in progress, or the final
    -- StopMovingOrSizing) - reflow wrap-width text and persist the size
    -- here rather than only in the grip's OnMouseUp, so a resize is never
    -- lost even if mouse capture is released oddly.
    f:SetScript("OnSizeChanged", function(self, width, height)
        WorkoutTrackerDB.frameWidth = width
        WorkoutTrackerDB.frameHeight = height
        self:ReflowWidths()
    end)

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
    f.dungeonLabel = dungeonLabel

    -- Keystone level
    local keystoneLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    keystoneLabel:SetPoint("TOPLEFT", 10, -55)
    f.keystoneLabel = keystoneLabel

    -- Deaths counter
    local deathsLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    deathsLabel:SetPoint("TOPLEFT", 10, -80)
    f.deathsLabel = deathsLabel

    -- Boss wipes (BigWigs/LittleWigs tracked)
    local bossWipeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bossWipeLabel:SetPoint("TOPLEFT", 10, -100)
    f.bossWipeLabel = bossWipeLabel

    -- Last boss wipe detail (boss name + remaining health %)
    local lastWipeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lastWipeLabel:SetPoint("TOPLEFT", 10, -118)
    lastWipeLabel:SetJustifyH("LEFT")
    f.lastWipeLabel = lastWipeLabel

    -- Tier info
    local tierLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tierLabel:SetPoint("TOPLEFT", 10, -145)
    f.tierLabel = tierLabel

    -- Exercises header
    local exerciseHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    exerciseHeader:SetPoint("TOPLEFT", 10, -170)
    exerciseHeader:SetText("|cffff9000Next Workout:|r")

    -- Exercise line pool - created once, text/visibility updated per tier
    -- (fixed positions rather than rebuilding the whole frame on refresh)
    local exerciseLines = {}
    local MAX_EXERCISE_LINES = 8
    for i = 1, MAX_EXERCISE_LINES do
        local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", 20, -195 - ((i - 1) * 20))
        label:SetText("")
        exerciseLines[i] = label
    end

    -- Boss mod integration status footer
    local statusLabel = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    statusLabel:SetPoint("BOTTOMLEFT", 10, 45)
    statusLabel:SetJustifyH("LEFT")
    f.statusLabel = statusLabel

    -- Buttons
    local deathBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    deathBtn:SetSize(90, 25)
    deathBtn:SetPoint("BOTTOMLEFT", 10, 10)
    deathBtn:SetText("Log Death")
    deathBtn:SetScript("OnClick", function() addon:AddDeath() end)

    local wipeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    wipeBtn:SetSize(90, 25)
    wipeBtn:SetPoint("BOTTOMLEFT", 105, 10)
    wipeBtn:SetText("Log Wipe")
    wipeBtn:SetScript("OnClick", function() addon:AddWipe() end)

    local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetBtn:SetSize(90, 25)
    resetBtn:SetPoint("BOTTOMLEFT", 200, 10)
    resetBtn:SetText("Reset")
    resetBtn:SetScript("OnClick", function() addon:ResetSession() end)

    -- Recompute wrap widths for text elements that need to reflow when the
    -- frame is resized (fixed-width fields would otherwise stay clipped to
    -- their original size or leave dead space after a resize).
    function f:ReflowWidths()
        local contentWidth = self:GetWidth() - 20 -- 10px padding each side
        lastWipeLabel:SetWidth(contentWidth)
        statusLabel:SetWidth(contentWidth)
    end

    function f:Update()
        dungeonLabel:SetText("Dungeon: " .. (WorkoutTrackerDB.currentDungeon or "None"))

        if WorkoutTrackerDB.keystoneLevel then
            keystoneLabel:SetText("|cff0070ddKeystone: |r+" .. WorkoutTrackerDB.keystoneLevel)
        else
            keystoneLabel:SetText("|cff888888Keystone: |rnone active")
        end

        deathsLabel:SetText("|cffff0000Deaths: |r" .. WorkoutTrackerDB.deaths)
        bossWipeLabel:SetText("|cffff4500Boss Wipes: |r" .. (WorkoutTrackerDB.bossWipes or 0)
            .. "  |cff888888(manual: " .. (WorkoutTrackerDB.wipes or 0) .. ")|r")

        if WorkoutTrackerDB.lastBossWipeName then
            local pctText = WorkoutTrackerDB.lastBossWipeHealthPct
                and ("%.1f%%"):format(WorkoutTrackerDB.lastBossWipeHealthPct)
                or "unknown"
            lastWipeLabel:SetText("|cffaaaaaaLast wipe: |r" .. WorkoutTrackerDB.lastBossWipeName
                .. " at " .. pctText .. " health")
        else
            lastWipeLabel:SetText("")
        end

        local tier = addon:CalculateTier()
        local tierData = addon.TIERS[tier]
        tierLabel:SetText("|cff00ff00Current Tier: |r" .. tierData.name)

        for i, label in ipairs(exerciseLines) do
            local exercise = tierData.exercises[i]
            if exercise then
                label:SetText("  " .. exercise)
            else
                label:SetText("")
            end
        end

        if addon.bossModIntegration == false then
            statusLabel:SetText("BigWigs/LittleWigs not detected - use Log Wipe manually.")
        elseif addon.bossModIntegration == true then
            statusLabel:SetText("BigWigs/LittleWigs detected - boss wipes tracked automatically.")
        else
            statusLabel:SetText("")
        end
    end

    self.mainFrame = f
    f:ReflowWidths()
    f:Update()
end
