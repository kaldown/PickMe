local _, PickMe = ...

--------------------------------------------------------------
-- Scanner state
--------------------------------------------------------------

local scannerFrame = CreateFrame("Frame")
local isRegistered = false
local playerName = nil

--------------------------------------------------------------
-- Activity ID to dungeon name resolution
--------------------------------------------------------------

local function GetDungeonName(activityIDs)
    if not activityIDs or not C_LFGList then return "Unknown" end

    -- Try GetActivityFullName first
    if C_LFGList.GetActivityFullName then
        for _, id in ipairs(activityIDs) do
            local ok, name = pcall(C_LFGList.GetActivityFullName, id)
            if ok and name and name ~= "" then
                return name
            end
        end
    end

    -- Fallback: GetActivityInfoTable
    if C_LFGList.GetActivityInfoTable then
        for _, id in ipairs(activityIDs) do
            local ok, info = pcall(C_LFGList.GetActivityInfoTable, id)
            if ok and info and info.fullName and info.fullName ~= "" then
                return info.fullName
            elseif ok and info and info.shortName and info.shortName ~= "" then
                return info.shortName
            end
        end
    end

    return "Unknown"
end

--------------------------------------------------------------
-- Scan LFG Browse results
--------------------------------------------------------------

local function ScanLFGResults()
    if not PickMe:IsActive() then return end
    if not C_LFGList or not C_LFGList.GetSearchResults then return end
    if not C_LFGList.GetSearchResultInfo then return end

    local myName = playerName or UnitName("player")
    playerName = myName

    local ok, totalResults, results = pcall(C_LFGList.GetSearchResults)
    if not ok or not results or #results == 0 then return end

    local targetMode = PickMeDB.profile.targetMode

    for _, resultID in ipairs(results) do
        local ok2, info = pcall(C_LFGList.GetSearchResultInfo, resultID)
        if ok2 and info and not info.isDelisted then
            local leader = info.leaderName
            if leader and leader ~= "" and leader ~= myName then
                -- Target mode filter
                local shouldWhisper = true
                if targetMode == "groups" and info.numMembers and info.numMembers <= 1 then
                    shouldWhisper = false
                end

                if shouldWhisper then
                    local dungeon = GetDungeonName(info.activityIDs)
                    PickMe:Enqueue(leader, dungeon)
                end
            end
        end
    end
end

--------------------------------------------------------------
-- Event handling
--------------------------------------------------------------

local function OnEvent(self, event, ...)
    if not PickMe:IsActive() then return end
    ScanLFGResults()
end

--------------------------------------------------------------
-- Public API
--------------------------------------------------------------

function PickMe:RegisterScannerEvents()
    -- These events fire when LFG Browse results arrive/update
    pcall(scannerFrame.RegisterEvent, scannerFrame, "LFG_LIST_SEARCH_RESULTS_RECEIVED")
    pcall(scannerFrame.RegisterEvent, scannerFrame, "LFG_LIST_SEARCH_RESULT_UPDATED")
    scannerFrame:SetScript("OnEvent", OnEvent)
    isRegistered = true
end

function PickMe:UnregisterScannerEvents()
    pcall(scannerFrame.UnregisterEvent, scannerFrame, "LFG_LIST_SEARCH_RESULTS_RECEIVED")
    pcall(scannerFrame.UnregisterEvent, scannerFrame, "LFG_LIST_SEARCH_RESULT_UPDATED")
    isRegistered = false
end

function PickMe:ManualScan()
    ScanLFGResults()
    local queued = PickMe:GetQueueCount()
    self:Print("Manual scan complete. " .. queued .. " in queue.")
end

