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

    -- Min level filter (only effective if we have level data)
    if filters.minLevel and filters.minLevel > 0 then
        local level = listing.leaderLevel or 0
        -- If level is 0 (unknown), don't filter it out
        if level > 0 and level < filters.minLevel then
            return false
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

    -- Exclude classes filter (singles mode only - no member class data for groups)
    if mode == "singles" and filters.excludeClasses and #filters.excludeClasses > 0 then
        local leaderClass = listing.leaderClass
        if leaderClass then
            for _, excClass in ipairs(filters.excludeClasses) do
                if leaderClass == excClass then
                    return false
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
