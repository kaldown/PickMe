local _, PickMe = ...

--------------------------------------------------------------
-- LFG API references (resolved at load time)
--------------------------------------------------------------

local GetNumLFGResults = GetNumLFGResults
local GetLFGResults = GetLFGResults
local GetLFGTypes = GetLFGTypes
local GetLFGTypeEntries = GetLFGTypeEntries

--------------------------------------------------------------
-- Debug / API discovery
--------------------------------------------------------------

local function DiscoverLFGAPI()
    local apis = {
        "GetNumLFGResults", "GetLFGResults", "GetLFGTypes", "GetLFGTypeEntries",
        "SetLFGType", "ClearLookingForGroup", "SetLookingForGroup",
        "GetLookingForGroup", "LFGBrowse_UpdateResults",
    }
    local found = {}
    for _, name in ipairs(apis) do
        if _G[name] then
            found[#found + 1] = "|cFF00FF00" .. name .. "|r"
        else
            found[#found + 1] = "|cFFFF0000" .. name .. "|r"
        end
    end
    PickMe:Print("LFG API: " .. table.concat(found, ", "))
end

--------------------------------------------------------------
-- Scanner state
--------------------------------------------------------------

local scannerFrame = CreateFrame("Frame")
local isRegistered = false
local playerName = nil

--------------------------------------------------------------
-- Scan LFG results
--------------------------------------------------------------

local function ScanLFGResults()
    if not PickMe:IsActive() then return end
    if not GetNumLFGResults or not GetLFGResults then return end
    if not GetLFGTypes then return end

    local myName = playerName or UnitName("player")
    playerName = myName

    local types = { GetLFGTypes() }
    for typeIdx, typeName in ipairs(types) do
        if typeName then
            local entries = { GetLFGTypeEntries(typeIdx) }
            for lfgIdx, entryName in ipairs(entries) do
                local numResults = GetNumLFGResults(typeIdx, lfgIdx)
                if numResults and numResults > 0 then
                    for i = 1, numResults do
                        local name, level, class, _, _, zone, _ = GetLFGResults(typeIdx, lfgIdx, i)
                        if name and name ~= myName then
                            PickMe:Enqueue(name, entryName or zone or "Unknown")
                        end
                    end
                end
            end
        end
    end
end

--------------------------------------------------------------
-- Event handling
--------------------------------------------------------------

local LFG_EVENTS = {
    "LFG_UPDATE",
    "UPDATE_LFG",
    "LFG_LIST_UPDATE",
    "LFG_SEARCH_RESULTS",
}

local function OnEvent(self, event, ...)
    if not PickMe:IsActive() then return end
    ScanLFGResults()
end

--------------------------------------------------------------
-- Public API
--------------------------------------------------------------

function PickMe:RegisterScannerEvents()
    for _, event in ipairs(LFG_EVENTS) do
        local ok = pcall(scannerFrame.RegisterEvent, scannerFrame, event)
        if ok then
            isRegistered = true
        end
    end
    scannerFrame:SetScript("OnEvent", OnEvent)
end

function PickMe:UnregisterScannerEvents()
    for _, event in ipairs(LFG_EVENTS) do
        pcall(scannerFrame.UnregisterEvent, scannerFrame, event)
    end
    isRegistered = false
end

function PickMe:RunAPIDisco()
    DiscoverLFGAPI()
end

--------------------------------------------------------------
-- Slash command for discovery (development aid)
--------------------------------------------------------------

SLASH_PICKMEDISCO1 = "/pickmedisco"
SlashCmdList["PICKMEDISCO"] = function()
    PickMe:RunAPIDisco()
end
