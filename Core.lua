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
    profile = {
        enabled = false,
        paused = false,
        template = "Hey {leader}, {level} {class} {role} LFG {dungeon}!",
        whisperDelay = 3,
        targetMode = "groups",
    },
    history = {},
    minimap = { hide = false },
}

--------------------------------------------------------------
-- State
--------------------------------------------------------------

PickMe.paused = false

--------------------------------------------------------------
-- SavedVariables init
--------------------------------------------------------------

local function InitializeDB()
    PickMeDB = PickMeDB or {}
    for section, defaults in pairs(DEFAULTS) do
        if type(defaults) == "table" then
            PickMeDB[section] = PickMeDB[section] or {}
            for k, v in pairs(defaults) do
                if PickMeDB[section][k] == nil then
                    PickMeDB[section][k] = v
                end
            end
        end
    end

    -- Migrate old whispered table to history format
    if PickMeDB.whispered then
        PickMeDB.history = PickMeDB.history or {}
        for name, ts in pairs(PickMeDB.whispered) do
            -- Check if already migrated
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
end

--------------------------------------------------------------
-- Print helpers
--------------------------------------------------------------

function PickMe:Print(msg)
    print(ADDON_PREFIX .. msg)
end

function PickMe:Status()
    local db = PickMeDB.profile
    local status = db.enabled and (PickMe.paused and "|cFFFFFF00PAUSED|r" or "|cFF00FF00ON|r") or "|cFFFF0000OFF|r"
    local whispered = PickMe.GetHistoryCount and PickMe:GetHistoryCount() or 0
    local queued = PickMe.GetQueueCount and PickMe:GetQueueCount() or 0
    self:Print("Status: " .. status)
    self:Print("Whispered: " .. whispered .. " | Queued: " .. queued)
    self:Print("Template: " .. db.template)
    self:Print("Target: " .. db.targetMode .. " | Delay: " .. db.whisperDelay .. "s")
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
            if IsShiftKeyDown() then
                if PickMe.ToggleFrame then PickMe:ToggleFrame() end
            else
                if PickMe.ToggleMessageFrame then PickMe:ToggleMessageFrame() end
            end
        elseif button == "RightButton" then
            if PickMeDB.profile.enabled then
                PickMe:Disable()
            else
                PickMe:Enable()
            end
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("PickMe v" .. VERSION, 0, 0.8, 0.4)
        tooltip:AddLine(" ")
        local db = PickMeDB.profile
        local status = db.enabled and (PickMe.paused and "|cFFFFFF00PAUSED|r" or "|cFF00FF00ON|r") or "|cFFFF0000OFF|r"
        tooltip:AddLine("Status: " .. status, 1, 1, 1)
        local historyCount = PickMe.GetHistoryCount and PickMe:GetHistoryCount() or 0
        local queued = PickMe.GetQueueCount and PickMe:GetQueueCount() or 0
        tooltip:AddLine(queued .. " queued | " .. historyCount .. " whispered", 0.7, 0.7, 0.7)
        tooltip:AddLine(" ")
        tooltip:AddLine("|cFFFFFFFFLeft-click:|r Messages", 0.7, 0.7, 0.7)
        tooltip:AddLine("|cFFFFFFFFShift-click:|r Settings", 0.7, 0.7, 0.7)
        tooltip:AddLine("|cFFFFFFFFRight-click:|r Toggle ON/OFF", 0.7, 0.7, 0.7)
    end,
})

--------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------

SLASH_PICKME1 = "/pickme"
SlashCmdList["PICKME"] = function(msg)
    msg = (msg or ""):trim():lower()
    if msg == "messages" or msg == "msg" or msg == "log" then
        if PickMe.ToggleMessageFrame then PickMe:ToggleMessageFrame() end
    elseif msg == "on" then
        PickMe:Enable()
    elseif msg == "off" then
        PickMe:Disable()
    elseif msg == "pause" then
        PickMe:Pause()
    elseif msg == "resume" then
        PickMe:Resume()
    elseif msg == "clear" then
        PickMe:ClearHistory()
    elseif msg == "status" then
        PickMe:Status()
    else
        if PickMe.ToggleFrame then PickMe:ToggleFrame() end
    end
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
        PickMe:Print("v" .. VERSION .. " loaded. Use minimap button to configure.")
        if PickMe.RegisterScannerEvents then
            PickMe:RegisterScannerEvents()
        end
    end
end)

-- Expose namespace for other files
_G.PickMe_NS = PickMe
