local _, PickMe = ...

--------------------------------------------------------------
-- Scanner state
--------------------------------------------------------------

local scannerFrame = CreateFrame("Frame")
local isRegistered = false
local playerName = nil

local scanResults = {
    groups = {},
    singles = {},
}

--------------------------------------------------------------
-- Activity ID to dungeon name resolution
--------------------------------------------------------------

local function GetDungeonName(activityIDs)
    if not activityIDs or not C_LFGList then return "Unknown" end

    if C_LFGList.GetActivityFullName then
        for _, id in ipairs(activityIDs) do
            local ok, name = pcall(C_LFGList.GetActivityFullName, id)
            if ok and name and name ~= "" then
                return name
            end
        end
    end

    if C_LFGList.GetActivityInfoTable then
        for _, id in ipairs(activityIDs) do
            local ok, info = pcall(C_LFGList.GetActivityInfoTable, id)
            if ok and info then
                if info.fullName and info.fullName ~= "" then
                    return info.fullName
                elseif info.shortName and info.shortName ~= "" then
                    return info.shortName
                end
            end
        end
    end

    return "Unknown"
end

--------------------------------------------------------------
-- Extract role counts from a listing
--------------------------------------------------------------

local function GetRoleCounts(resultID)
    if not C_LFGList.GetSearchResultMemberCounts then
        return nil
    end
    local ok, counts = pcall(C_LFGList.GetSearchResultMemberCounts, resultID)
    if ok and counts then
        return counts
    end
    return nil
end

--------------------------------------------------------------
-- Extract per-member class/role data from a listing
--------------------------------------------------------------

local hasMemberInfo = nil  -- nil = unknown, true/false after first check

local function GetMemberInfo(resultID, numMembers)
    -- Check API availability (cache after first attempt)
    if hasMemberInfo == false then return nil end
    if not C_LFGList.GetSearchResultMemberInfo then
        hasMemberInfo = false
        return nil
    end

    local members = {}
    for i = 1, (numMembers or 1) do
        local ok, role, class = pcall(C_LFGList.GetSearchResultMemberInfo, resultID, i)
        if ok and role and class then
            hasMemberInfo = true
            members[#members + 1] = { role = role, class = class }
        elseif not ok then
            -- API doesn't work on this client
            hasMemberInfo = false
            return nil
        end
    end

    if #members == 0 then return nil end
    return members
end

--------------------------------------------------------------
-- Scan LFG Browse results
--------------------------------------------------------------

local function ScanLFGResults()
    if not C_LFGList or not C_LFGList.GetSearchResults then return end
    if not C_LFGList.GetSearchResultInfo then return end

    local myName = playerName or UnitName("player")
    playerName = myName

    local ok, totalResults, results = pcall(C_LFGList.GetSearchResults)
    if not ok or not results then return end

    scanResults.groups = {}
    scanResults.singles = {}

    local FE = PickMe.FilterEngine

    for _, resultID in ipairs(results) do
        local ok2, info = pcall(C_LFGList.GetSearchResultInfo, resultID)
        if ok2 and info and not info.isDelisted then
            local leader = info.leaderName
            if leader and leader ~= "" and leader ~= myName then
                local dungeon = GetDungeonName(info.activityIDs)
                local numMembers = info.numMembers or 1
                local roleCounts = GetRoleCounts(resultID)

                -- Infer what roles the group is seeking
                local seekingRoles = {}
                if FE and roleCounts then
                    seekingRoles = FE.InferSeekingRoles(roleCounts, numMembers)
                end

                -- Try to get per-member class/role data
                local members = GetMemberInfo(resultID, numMembers)
                local leaderClass = nil
                if members and #members > 0 then
                    -- For singles, the only member is the leader
                    -- For groups, member index 1 is commonly the leader
                    leaderClass = members[1].class
                end

                local listing = {
                    resultID = resultID,
                    leaderName = leader,
                    leaderClass = leaderClass,
                    leaderLevel = 0,     -- not available
                    dungeon = dungeon,
                    numMembers = numMembers,
                    roleCounts = roleCounts,
                    seekingRoles = seekingRoles,
                    members = members,   -- per-member {role, class} if available
                    description = info.name or "",  -- listing title/description
                    comment = info.comment or "",    -- listing comment if available
                }

                if numMembers >= 2 then
                    scanResults.groups[#scanResults.groups + 1] = listing
                else
                    scanResults.singles[#scanResults.singles + 1] = listing
                end

                -- Auto-send: still enqueue if enabled (hidden feature)
                if PickMe:IsActive() then
                    local targetMode = PickMeDB.profile.targetMode or "groups"
                    local shouldEnqueue = true
                    if targetMode == "groups" and numMembers <= 1 then
                        shouldEnqueue = false
                    end
                    if shouldEnqueue then
                        PickMe:Enqueue(leader, dungeon)
                    end
                end
            end
        end
    end

    if PickMe.OnScanResultsUpdated then
        PickMe:OnScanResultsUpdated()
    end
end

--------------------------------------------------------------
-- Event handling
--------------------------------------------------------------

local function OnEvent(self, event, ...)
    ScanLFGResults()
end

--------------------------------------------------------------
-- Public API
--------------------------------------------------------------

function PickMe:RegisterScannerEvents()
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

function PickMe:GetGroupResults()
    return scanResults.groups
end

function PickMe:GetSingleResults()
    return scanResults.singles
end

function PickMe:ManualScan()
    ScanLFGResults()
    local groups = #scanResults.groups
    local singles = #scanResults.singles
    self:Print("Scan: " .. groups .. " groups, " .. singles .. " singles.")
end
