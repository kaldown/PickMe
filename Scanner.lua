local _, PickMe = ...

--------------------------------------------------------------
-- Scanner state
--------------------------------------------------------------

local scannerFrame = CreateFrame("Frame")
local isRegistered = false
local playerName = nil

local scanResults = {
    groups = {},       -- ordered array of listing tables
    singles = {},
    groupIndex = {},   -- leaderName -> index in groups array
    singleIndex = {},  -- leaderName -> index in singles array
    stale = {},        -- leaderName -> timestamp when marked stale
}

-- Forward declaration (defined in Event handling section)
local ClearScanResults

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

    -- Prefer GetSearchResultPlayerInfo (returns level, name, class, role)
    -- Fall back to GetSearchResultMemberInfo (returns role, class only)
    local hasPlayerInfo = C_LFGList.GetSearchResultPlayerInfo
    local hasMemberInfoAPI = C_LFGList.GetSearchResultMemberInfo

    if not hasPlayerInfo and not hasMemberInfoAPI then
        hasMemberInfo = false
        return nil
    end

    local members = {}
    for i = 1, (numMembers or 1) do
        local member = nil

        -- Try GetSearchResultPlayerInfo first (richer data with level)
        if hasPlayerInfo then
            local ok, pInfo = pcall(C_LFGList.GetSearchResultPlayerInfo, resultID, i)
            if ok and pInfo and pInfo.assignedRole and pInfo.classFilename then
                hasMemberInfo = true
                member = {
                    role = pInfo.assignedRole,
                    class = pInfo.classFilename,
                    classLocalized = pInfo.className,
                }
                if type(pInfo.level) == "number" and pInfo.level > 0 then
                    member.level = pInfo.level
                end
            elseif not ok then
                hasPlayerInfo = nil  -- disable for remaining members
            end
        end

        -- Fallback to GetSearchResultMemberInfo if PlayerInfo unavailable
        if not member and hasMemberInfoAPI then
            local ok, role, class, classLocalized = pcall(
                C_LFGList.GetSearchResultMemberInfo, resultID, i
            )
            if ok and role and class then
                hasMemberInfo = true
                member = { role = role, class = class }
                if type(classLocalized) == "string" and classLocalized ~= "" then
                    member.classLocalized = classLocalized
                end
            elseif not ok then
                hasMemberInfoAPI = nil  -- disable for remaining members
            end
        end

        if member then
            members[#members + 1] = member
        end
    end

    if #members == 0 then
        if not hasPlayerInfo and not hasMemberInfoAPI then
            hasMemberInfo = false
        end
        return nil
    end
    return members
end

--------------------------------------------------------------
-- Identity-based merge for stable ordering
--------------------------------------------------------------

local STALE_TIMEOUT = 5  -- seconds before stale entries are removed

local function MergeResults(ordered, index, current, stale, now)
    -- Pass 1: Update existing entries or mark stale
    local i = 1
    while i <= #ordered do
        local entry = ordered[i]
        local name = entry.leaderName
        if current[name] then
            -- Update in-place (preserve position)
            for k, v in pairs(current[name]) do
                entry[k] = v
            end
            entry._stale = nil
            stale[name] = nil
            current[name] = nil  -- consumed
            i = i + 1
        elseif stale[name] and (now - stale[name]) > STALE_TIMEOUT then
            -- Remove expired stale entry
            table.remove(ordered, i)
            stale[name] = nil
        elseif not entry._stale then
            -- Mark as newly stale
            entry._stale = true
            stale[name] = now
            i = i + 1
        else
            i = i + 1
        end
    end

    -- Pass 2: Append new entries
    for name, listing in pairs(current) do
        ordered[#ordered + 1] = listing
    end

    -- Rebuild index
    for k in pairs(index) do index[k] = nil end
    for idx, entry in ipairs(ordered) do
        index[entry.leaderName] = idx
    end
end

--------------------------------------------------------------
-- Scan LFG Browse results
--------------------------------------------------------------

local function ScanLFGResults()
    if not C_LFGList or not C_LFGList.GetSearchResults then return end
    if not C_LFGList.GetSearchResultInfo then return end

    if not PickMe:HasActiveListing() then
        ClearScanResults()
        return
    end

    local myName = playerName or UnitName("player")
    playerName = myName

    local ok, totalResults, results = pcall(C_LFGList.GetSearchResults)
    if not ok or not results then return end

    local FE = PickMe.FilterEngine
    local now = time()

    -- Build set of current listings from API
    local currentGroups = {}  -- leaderName -> listing
    local currentSingles = {}

    for _, resultID in ipairs(results) do
        local ok2, info = pcall(C_LFGList.GetSearchResultInfo, resultID)
        if ok2 and info and not info.isDelisted then
            local leader = info.leaderName
            if leader and leader ~= "" and leader ~= myName then
                local dungeon = GetDungeonName(info.activityIDs)
                local numMembers = info.numMembers or 1
                local roleCounts = GetRoleCounts(resultID)

                local seekingRoles = {}
                if FE and roleCounts then
                    seekingRoles = FE.InferSeekingRoles(roleCounts, numMembers)
                end

                local members = GetMemberInfo(resultID, numMembers)
                local leaderClass = nil
                local leaderLevel = 0
                if members and #members > 0 then
                    leaderClass = members[1].class
                    leaderLevel = members[1].level or 0
                end

                local listing = {
                    resultID = resultID,
                    leaderName = leader,
                    leaderClass = leaderClass,
                    leaderLevel = leaderLevel,
                    dungeon = dungeon,
                    numMembers = numMembers,
                    roleCounts = roleCounts,
                    seekingRoles = seekingRoles,
                    members = members,
                    description = info.comment or "",
                }

                if numMembers >= 2 then
                    currentGroups[leader] = listing
                else
                    currentSingles[leader] = listing
                end
            end
        end
    end

    -- Merge: update existing, mark stale, append new
    MergeResults(scanResults.groups, scanResults.groupIndex, currentGroups, scanResults.stale, now)
    MergeResults(scanResults.singles, scanResults.singleIndex, currentSingles, scanResults.stale, now)

    if PickMe.OnScanResultsUpdated then
        PickMe:OnScanResultsUpdated()
    end
end

--------------------------------------------------------------
-- Event handling
--------------------------------------------------------------

ClearScanResults = function()
    scanResults.groups = {}
    scanResults.singles = {}
    scanResults.groupIndex = {}
    scanResults.singleIndex = {}
    scanResults.stale = {}
    if PickMe.OnScanResultsUpdated then
        PickMe:OnScanResultsUpdated()
    end
end

local function OnEvent(self, event, ...)
    if event == "LFG_LIST_ACTIVE_ENTRY_EXPIRED" then
        -- Only clear if we truly have no active listing
        if not PickMe:HasActiveListing() then
            ClearScanResults()
        end
        return
    end
    ScanLFGResults()
end

--------------------------------------------------------------
-- Public API
--------------------------------------------------------------

function PickMe:RegisterScannerEvents()
    pcall(scannerFrame.RegisterEvent, scannerFrame, "LFG_LIST_SEARCH_RESULTS_RECEIVED")
    pcall(scannerFrame.RegisterEvent, scannerFrame, "LFG_LIST_SEARCH_RESULT_UPDATED")
    pcall(scannerFrame.RegisterEvent, scannerFrame, "LFG_LIST_ACTIVE_ENTRY_EXPIRED")
    scannerFrame:SetScript("OnEvent", OnEvent)
    isRegistered = true
end

function PickMe:UnregisterScannerEvents()
    pcall(scannerFrame.UnregisterEvent, scannerFrame, "LFG_LIST_SEARCH_RESULTS_RECEIVED")
    pcall(scannerFrame.UnregisterEvent, scannerFrame, "LFG_LIST_SEARCH_RESULT_UPDATED")
    pcall(scannerFrame.UnregisterEvent, scannerFrame, "LFG_LIST_ACTIVE_ENTRY_EXPIRED")
    isRegistered = false
end

function PickMe:HasActiveListing()
    if not C_LFGList or not C_LFGList.HasActiveEntryInfo then
        return false
    end
    local ok, hasActive = pcall(C_LFGList.HasActiveEntryInfo)
    return ok and hasActive
end

function PickMe:GetGroupResults()
    return scanResults.groups
end

function PickMe:GetSingleResults()
    return scanResults.singles
end

function PickMe:IsListingStale(leaderName)
    return scanResults.stale[leaderName] ~= nil
end

function PickMe:ManualScan()
    ScanLFGResults()
    local groups = #scanResults.groups
    local singles = #scanResults.singles
    self:Print("Scan: " .. groups .. " groups, " .. singles .. " singles.")
end

function PickMe:DebugMemberInfo()
    if not C_LFGList or not C_LFGList.GetSearchResults then
        self:Print("Debug: C_LFGList.GetSearchResults not available")
        return
    end

    -- Dump all C_LFGList function names
    self:Print("Debug: C_LFGList functions:")
    local funcs = {}
    for k, v in pairs(C_LFGList) do
        if type(v) == "function" then
            funcs[#funcs + 1] = k
        end
    end
    table.sort(funcs)
    self:Print("  " .. table.concat(funcs, ", "))

    local ok, _, results = pcall(C_LFGList.GetSearchResults)
    if not ok or not results or #results == 0 then
        self:Print("Debug: No search results. Open LFG Browse panel first.")
        return
    end

    self:Print("Debug: " .. #results .. " search results found")

    -- Check API existence
    if not C_LFGList.GetSearchResultMemberInfo then
        self:Print("Debug: GetSearchResultMemberInfo does NOT exist on this client")
        return
    end
    self:Print("Debug: GetSearchResultMemberInfo exists")

    -- Try first result
    local resultID = results[1]
    local ok2, info = pcall(C_LFGList.GetSearchResultInfo, resultID)
    if ok2 and info then
        self:Print("Debug: Result " .. resultID .. " -- GetSearchResultInfo fields:")
        local keys = {}
        for k in pairs(info) do keys[#keys + 1] = k end
        table.sort(keys)
        for _, k in ipairs(keys) do
            local v = info[k]
            if type(v) == "table" then
                local parts = {}
                for tk, tv in pairs(v) do
                    parts[#parts + 1] = tostring(tk) .. "=" .. tostring(tv)
                end
                self:Print("  " .. k .. ": (table) {" .. table.concat(parts, ", ") .. "}")
            else
                self:Print("  " .. k .. ": (" .. type(v) .. ") " .. tostring(v))
            end
        end
    end

    -- Helper to dump a table's fields
    local function DumpTable(label, tbl)
        if type(tbl) ~= "table" then
            self:Print(label .. ": (" .. type(tbl) .. ") " .. tostring(tbl))
            return
        end
        self:Print(label .. ":")
        local keys = {}
        for k in pairs(tbl) do keys[#keys + 1] = tostring(k) end
        table.sort(keys)
        for _, k in ipairs(keys) do
            local v = tbl[k] or tbl[tonumber(k)]
            self:Print("  " .. k .. ": (" .. type(v) .. ") " .. tostring(v))
        end
    end

    -- Dump GetSearchResultLeaderInfo (returns a table)
    if C_LFGList.GetSearchResultLeaderInfo then
        local ok3, leaderInfo = pcall(C_LFGList.GetSearchResultLeaderInfo, resultID)
        if ok3 and leaderInfo then
            DumpTable("Debug: GetSearchResultLeaderInfo(" .. resultID .. ")", leaderInfo)
        else
            self:Print("Debug: GetSearchResultLeaderInfo failed: " .. tostring(leaderInfo))
        end
    end

    -- Dump GetSearchResultPlayerInfo (requires resultID, memberIndex)
    if C_LFGList.GetSearchResultPlayerInfo then
        local numMembers = (ok2 and info and info.numMembers) or 1
        local limit = numMembers < 2 and numMembers or 2
        for i = 1, limit do
            local ok4, playerInfo = pcall(C_LFGList.GetSearchResultPlayerInfo, resultID, i)
            if ok4 and playerInfo then
                DumpTable("Debug: GetSearchResultPlayerInfo(" .. resultID .. ", " .. i .. ")", playerInfo)
            elseif ok4 then
                self:Print("Debug: GetSearchResultPlayerInfo(" .. resultID .. ", " .. i .. ") returned nil")
            else
                self:Print("Debug: GetSearchResultPlayerInfo(" .. resultID .. ", " .. i .. ") failed: " .. tostring(playerInfo))
            end
        end
    end
end
