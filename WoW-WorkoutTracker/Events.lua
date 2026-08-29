-- BigWigs / LittleWigs integration
--
-- BigWigs and LittleWigs both register their boss modules against the same
-- global message bus, "BigWigsLoader" (LittleWigs ships boss content only
-- and rides on BigWigs' own loader; there is no separate LittleWigs API).
-- Neither addon is a hard dependency of WoW-WorkoutTracker, so every hook
-- here is guarded and this file is a silent no-op if the user doesn't have
-- BigWigs/LittleWigs installed.
--
-- Verified against BigWigsMods/BigWigs (master branch, source inspected directly):
--
--   Core/BossPrototype.lua:
--     self:SendMessage("BigWigs_OnBossWipe", self, wipeTime, unitInfo)
--     self:SendMessage("BigWigs_OnBossEngage", self)
--
--   Plugins/Wipe.lua (BigWigs' own wipe-tracking plugin) confirms
--   BigWigs_OnBossWipe -- not BigWigs_EncounterEnd -- is the message
--   third-party addons should use for wipe detection. BossPrototype.lua
--   even comments "Do NOT use this for wipe detection, use BigWigs_OnBossWipe"
--   directly above the BigWigs_EncounterEnd dispatch.
--
--   Loader.lua dispatch (public:SendMessage):
--     for k, v in next, callbackMap[event] do
--       if type(v) == "function" then
--         securecallfunction(v, event, ...)   -- <-- function-style callbacks
--       else                                   --     receive (event, ...) --
--         securecallfunction(k[v], k, event, ...) --  the EVENT NAME comes
--       end                                    --     first, then the
--     end                                      --     original SendMessage args.
--
--   So a plain function registered via BigWigsLoader.RegisterMessage(self, event, func)
--   is invoked as: func(event, module, wipeTime, unitInfo)
--                          ^^^^^^ ^^^^^^^^^ ^^^^^^^^
--                          the string       BigWigs' own boss module table,
--                          "BigWigs_..."    passed as the `self` arg from its
--                                           own :SendMessage(event, self, ...) call
--
--   Loader.lua also explicitly errors if you call BigWigsLoader:RegisterMessage(...)
--   (colon syntax on BigWigsLoader itself) -- it must be
--   BigWigsLoader.RegisterMessage(yourAddonTable, "EventName", yourFunction).
--
-- The `unitInfo` table passed alongside BigWigs_OnBossWipe is internal and
-- undocumented with no guaranteed shape across BigWigs versions, so it is
-- NOT relied on here. Instead, the moment a wipe fires, boss health is read
-- independently via Blizzard's own stable "bossN" unit tokens (added Wrath
-- 3.3.0, confirmed present through 12.1) using UnitHealth/UnitHealthMax.

local addon = _G["WorkoutTracker"]

local BOSS_UNIT_COUNT = 8 -- "bossN" tokens go up to boss8

local function GetBossHealthSnapshot()
    -- Returns an array of {name=, pct=} for every currently-populated boss
    -- unit, plus the single lowest health% found (nil if none are valid --
    -- e.g. the wipe happened on trash, or boss frames already cleared).
    local snapshot = {}
    local lowestPct = nil

    for i = 1, BOSS_UNIT_COUNT do
        local unit = "boss" .. i
        if UnitExists(unit) then
            local maxHP = UnitHealthMax(unit)
            if maxHP and maxHP > 0 then
                local hp = UnitHealth(unit)
                local pct = (hp / maxHP) * 100
                local name = UnitName(unit) or ("Boss " .. i)
                snapshot[#snapshot + 1] = { name = name, pct = pct }
                if not lowestPct or pct < lowestPct then
                    lowestPct = pct
                end
            end
        end
    end

    return snapshot, lowestPct
end

-- Registered as a plain function (not a method string), so per Loader.lua's
-- dispatch it receives (event, bossModule, wipeTime, unitInfo).
local function OnBigWigsBossWipe(event, bossModule, wipeTime, unitInfo)
    local snapshot, lowestPct = GetBossHealthSnapshot()

    local bossName = "Unknown boss"
    if bossModule then
        bossName = bossModule.displayName or bossModule.moduleName or bossName
    end

    addon:RecordBossWipe(bossName, lowestPct, snapshot)
end

local function OnBigWigsBossEngage(event, bossModule)
    local bossName = "Unknown boss"
    if bossModule then
        bossName = bossModule.displayName or bossModule.moduleName or bossName
    end
    addon:RecordBossEngage(bossName)
end

function addon:InitBossModIntegration()
    -- Guarded: BigWigsLoader only exists once BigWigs (or LittleWigs, which
    -- rides on BigWigs' loader) is installed and has finished loading.
    if not _G.BigWigsLoader then
        self.bossModIntegration = false
        return
    end

    local ok = pcall(function()
        BigWigsLoader.RegisterMessage(self, "BigWigs_OnBossWipe", OnBigWigsBossWipe)
        BigWigsLoader.RegisterMessage(self, "BigWigs_OnBossEngage", OnBigWigsBossEngage)
    end)

    self.bossModIntegration = ok and true or false

    if ok then
        print("|cff00ff00WoW Workout Tracker|r: BigWigs/LittleWigs detected - boss wipe tracking enabled.")
    end
end
