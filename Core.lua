local ADDON_NAME, PickMe = ...

local ADDON_PREFIX = "|cFF00CC66[PickMe]|r "
local GetMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local VERSION = GetMetadata and GetMetadata(ADDON_NAME, "Version") or "dev"
if VERSION:find("^@") then VERSION = "dev" end

local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

--------------------------------------------------------------
-- Defaults
--------------------------------------------------------------

local DEFAULTS = {
    modes = {
        groups = {
            template = "Hey {leader}, {level} {class} {role} LFG {dungeon}!",
            filters = {
                minLevel = 0,
                roles = {},           -- empty = show all; {"TANK","HEALER","DPS"}
                excludeClasses = {},  -- singles only; ignored for groups
            },
        },
        singles = {
            template = "Hey {leader}, {level} {class} looking for {dungeon}?",
            filters = {
                minLevel = 0,
                roles = {},
                excludeClasses = {},
            },
        },
    },
    settings = {
        cooldownHours = 4,
        whisperDelay = 3,
    },
    history = {},
    minimap = { hide = false },
    -- Hidden auto-send state (no UI, preserved for dev use)
    profile = {
        enabled = false,
        paused = false,
        targetMode = "groups",  -- preserved for auto-send
    },
}

--------------------------------------------------------------
-- State
--------------------------------------------------------------

PickMe.paused = false

--------------------------------------------------------------
-- SavedVariables init
--------------------------------------------------------------

local function DeepMergeDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then
                target[k] = {}
            end
            DeepMergeDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

local function InitializeDB()
    PickMeDB = PickMeDB or {}

    -- Migration: old profile-based schema -> new modes/settings schema
    if PickMeDB.profile ~= nil and PickMeDB.modes == nil then
        local old = PickMeDB.profile
        PickMeDB.modes = {
            groups = {
                template = old.template or DEFAULTS.modes.groups.template,
                filters = { minLevel = 0, roles = {}, excludeClasses = {} },
            },
            singles = {
                template = old.template or DEFAULTS.modes.singles.template,
                filters = { minLevel = 0, roles = {}, excludeClasses = {} },
            },
        }
        PickMeDB.settings = {
            cooldownHours = 4,
            whisperDelay = old.whisperDelay or 3,
        }
        -- Preserve auto-send state including targetMode
        PickMeDB.profile = {
            enabled = old.enabled or false,
            paused = old.paused or false,
            targetMode = old.targetMode or "groups",
        }
    end

    -- Migration: old whispered table -> history array
    if PickMeDB.whispered then
        PickMeDB.history = PickMeDB.history or {}
        for name, ts in pairs(PickMeDB.whispered) do
            local found = false
            for _, entry in ipairs(PickMeDB.history) do
                if entry.name == name then found = true; break end
            end
            if not found then
                table.insert(PickMeDB.history, { name = name, dungeon = "Unknown", time = ts })
            end
        end
        PickMeDB.whispered = nil
    end

    DeepMergeDefaults(PickMeDB, DEFAULTS)
end

--------------------------------------------------------------
-- Print helpers
--------------------------------------------------------------

function PickMe:Print(msg)
    print(ADDON_PREFIX .. msg)
end

function PickMe:Status()
    local settings = PickMeDB.settings
    local whispered = PickMe.GetHistoryCount and PickMe:GetHistoryCount() or 0
    self:Print("Whispered: " .. whispered)
    self:Print("Cooldown: " .. settings.cooldownHours .. "h | Delay: " .. settings.whisperDelay .. "s")
end

--------------------------------------------------------------
-- Enable / Disable / Pause
--------------------------------------------------------------

function PickMe:Enable()
    PickMeDB.profile.enabled = true
    PickMe.paused = false
    self:Print("Auto-whisper |cFF00FF00enabled|r")
end

function PickMe:Disable()
    PickMeDB.profile.enabled = false
    PickMe.paused = false
    if PickMe.StopQueue then PickMe:StopQueue() end
    self:Print("Auto-whisper |cFFFF0000disabled|r")
end

function PickMe:Pause()
    if not PickMeDB.profile.enabled then
        self:Print("Not enabled. Use /pickme on first.")
        return
    end
    PickMe.paused = true
    if PickMe.StopQueue then PickMe:StopQueue() end
    self:Print("Scanning |cFFFFFF00paused|r")
end

function PickMe:Resume()
    if not PickMeDB.profile.enabled then
        self:Print("Not enabled. Use /pickme on first.")
        return
    end
    PickMe.paused = false
    self:Print("Scanning |cFF00FF00resumed|r")
end

function PickMe:IsActive()
    return PickMeDB.profile.enabled and not PickMe.paused
end

--------------------------------------------------------------
-- Minimap button
--------------------------------------------------------------

local dataObject = LDB:NewDataObject("PickMe", {
    type = "launcher",
    icon = "Interface\\Icons\\INV_Letter_15",
    OnClick = function(_, button)
        if button == "LeftButton" then
            if PickMe.ToggleMainFrame then PickMe:ToggleMainFrame() end
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("PickMe v" .. VERSION, 0, 0.8, 0.4)
        tooltip:AddLine(" ")
        local historyCount = PickMe.GetHistoryCount and PickMe:GetHistoryCount() or 0
        tooltip:AddLine(historyCount .. " whispered", 0.7, 0.7, 0.7)
        tooltip:AddLine(" ")
        tooltip:AddLine("|cFFFFFFFFClick:|r Open PickMe", 0.7, 0.7, 0.7)
    end,
})

--------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------

SLASH_PICKME1 = "/pickme"
SlashCmdList["PICKME"] = function()
    if PickMe.ToggleMainFrame then PickMe:ToggleMainFrame() end
end

--------------------------------------------------------------
-- Event frame
--------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        InitializeDB()
        PickMe.paused = PickMeDB.profile.paused or false
        LDBIcon:Register("PickMe", dataObject, PickMeDB.minimap)
        PickMe:Print("v" .. VERSION .. " loaded. Type /pickme or click minimap button.")
        if PickMe.RegisterScannerEvents then
            PickMe:RegisterScannerEvents()
        end
    end
end)

-- Expose namespace for other files
_G.PickMe_NS = PickMe
