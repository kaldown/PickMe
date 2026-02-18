local _, PickMe = ...

--------------------------------------------------------------
-- Class data
--------------------------------------------------------------

local CLASS_LIST = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
    "SHAMAN", "MAGE", "WARLOCK", "DRUID",
}

local CLASS_DISPLAY = {
    WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter",
    ROGUE = "Rogue", PRIEST = "Priest", SHAMAN = "Shaman",
    MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid",
}

local CLASS_COLORS = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
    HUNTER = { r = 0.67, g = 0.83, b = 0.45 },
    ROGUE = { r = 1.00, g = 0.96, b = 0.41 },
    PRIEST = { r = 1.00, g = 1.00, b = 1.00 },
    SHAMAN = { r = 0.00, g = 0.44, b = 0.87 },
    MAGE = { r = 0.25, g = 0.78, b = 0.92 },
    WARLOCK = { r = 0.53, g = 0.53, b = 0.93 },
    DRUID = { r = 1.00, g = 0.49, b = 0.04 },
}

--------------------------------------------------------------
-- Role data
--------------------------------------------------------------

local ROLE_LIST = { "TANK", "HEALER", "DPS" }

local ROLE_DISPLAY = {
    TANK = "Tank", HEALER = "Healer", DPS = "DPS",
}

--------------------------------------------------------------
-- Infer what roles a group needs from member counts
--------------------------------------------------------------

--- Given role counts from GetSearchResultMemberCounts,
--- infer which roles the group is likely seeking.
--- Heuristic: for a 5-man dungeon, expect 1T 1H 3D.
--- If a slot is unfilled, the group probably needs that role.
--- @param roleCounts table {TANK=n, HEALER=n, DAMAGER=n, NOROLE=n}
--- @param numMembers number current group size
--- @return table array of role strings the group likely needs
local function InferSeekingRoles(roleCounts, numMembers)
    if not roleCounts then return {} end
    local seeking = {}
    -- Standard 5-man composition: 1T 1H 3D
    if (roleCounts.TANK or 0) < 1 then
        seeking[#seeking + 1] = "TANK"
    end
    if (roleCounts.HEALER or 0) < 1 then
        seeking[#seeking + 1] = "HEALER"
    end
    -- Group needs DPS if they have fewer than 3 and aren't full
    local dpsCount = (roleCounts.DAMAGER or 0) + (roleCounts.NOROLE or 0)
    if dpsCount < 3 and (numMembers or 1) < 5 then
        seeking[#seeking + 1] = "DPS"
    end
    return seeking
end

--------------------------------------------------------------
-- Filter logic
--------------------------------------------------------------

--- Check if a listing passes the given filter config.
--- @param listing table {leaderName, numMembers, roleCounts, leaderClass, ...}
--- @param filters table {minLevel, roles, excludeClasses}
--- @param mode string "groups" or "singles"
--- @return boolean
local function PassesFilter(listing, filters, mode)
    if not filters then return true end

    -- Min level filter: check ALL members, filter if any member is below threshold
    if filters.minLevel and filters.minLevel > 0 and listing.members then
        for _, m in ipairs(listing.members) do
            local lvl = m.level or 0
            -- If level is 0 (unknown), don't filter on this member
            if lvl > 0 and lvl < filters.minLevel then
                return false
            end
        end
    end

    -- Roles seeking filter (OR within: show if listing seeks ANY checked role)
    if filters.roles and #filters.roles > 0 then
        local seekingRoles = listing.seekingRoles
        -- If we have no role data, skip filter (don't hide unknowns)
        if seekingRoles and #seekingRoles > 0 then
            local matchesAny = false
            for _, filterRole in ipairs(filters.roles) do
                for _, seekRole in ipairs(seekingRoles) do
                    if filterRole == seekRole then
                        matchesAny = true
                        break
                    end
                end
                if matchesAny then break end
            end
            if not matchesAny then return false end
        end
        -- If seekingRoles is nil/empty, we have no data - show the listing
    end

    -- Class filter
    if filters.classFilterMode and filters.classFilterMode ~= "off"
       and filters.classes and #filters.classes > 0 then

        local classes = filters.classes
        local filterMode = filters.classFilterMode
        local strict = filters.classFilterStrict or false

        if mode == "singles" then
            -- Singles: check leader class only
            local leaderClass = listing.leaderClass
            if leaderClass then
                if filterMode == "exclude" then
                    for _, c in ipairs(classes) do
                        if leaderClass == c then return false end
                    end
                elseif filterMode == "include" then
                    local found = false
                    for _, c in ipairs(classes) do
                        if leaderClass == c then found = true; break end
                    end
                    if not found then return false end
                end
            end
        elseif mode == "groups" and listing.members and #listing.members > 0 then
            if filterMode == "exclude" then
                -- Exclude: filter if ANY member has an excluded class
                for _, m in ipairs(listing.members) do
                    if m.class then
                        for _, c in ipairs(classes) do
                            if m.class == c then return false end
                        end
                    end
                end
            elseif filterMode == "include" then
                if strict then
                    -- Strict include: ALL members must be one of the checked classes
                    for _, m in ipairs(listing.members) do
                        if m.class then
                            local allowed = false
                            for _, c in ipairs(classes) do
                                if m.class == c then allowed = true; break end
                            end
                            if not allowed then return false end
                        end
                    end
                else
                    -- Normal include: must have at least one of EACH checked class
                    for _, c in ipairs(classes) do
                        local found = false
                        for _, m in ipairs(listing.members) do
                            if m.class == c then found = true; break end
                        end
                        if not found then return false end
                    end
                end
            end
        end
    end

    return true
end

--------------------------------------------------------------
-- Public API
--------------------------------------------------------------

PickMe.FilterEngine = {
    PassesFilter = PassesFilter,
    InferSeekingRoles = InferSeekingRoles,
    CLASS_LIST = CLASS_LIST,
    CLASS_DISPLAY = CLASS_DISPLAY,
    CLASS_COLORS = CLASS_COLORS,
    ROLE_LIST = ROLE_LIST,
    ROLE_DISPLAY = ROLE_DISPLAY,
}
