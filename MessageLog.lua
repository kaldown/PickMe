local _, PickMe = ...

--------------------------------------------------------------
-- Constants
--------------------------------------------------------------

local FRAME_WIDTH = 500
local FRAME_HEIGHT = 460
local FOOTER_HEIGHT = 24
local ROW_HEIGHT = 26
local VISIBLE_ROWS = 9
local ACCENT = { r = 0, g = 0.8, b = 0.4 }

local FE = nil
local activeMode = "groups"

--------------------------------------------------------------
-- Helpers
--------------------------------------------------------------

local function GetFilterEngine()
    if not FE then FE = PickMe.FilterEngine end
    return FE
end

local function FormatRelativeTime(timestamp)
    local diff = time() - timestamp
    if diff < 60 then
        return diff .. "s"
    elseif diff < 3600 then
        return math.floor(diff / 60) .. "m"
    elseif diff < 86400 then
        return math.floor(diff / 3600) .. "h"
    else
        return math.floor(diff / 86400) .. "d"
    end
end

--- Build a compact role count string from GetSearchResultMemberCounts data
--- e.g. "1T 1H 2D"
local function FormatRoleCounts(roleCounts, numMembers)
    if not roleCounts then
        return numMembers and (numMembers .. " members") or ""
    end
    local parts = {}
    local t = roleCounts.TANK or 0
    local h = roleCounts.HEALER or 0
    local d = roleCounts.DAMAGER or 0
    local n = roleCounts.NOROLE or 0
    if t > 0 then parts[#parts + 1] = t .. "T" end
    if h > 0 then parts[#parts + 1] = h .. "H" end
    if d > 0 then parts[#parts + 1] = d .. "D" end
    if n > 0 then parts[#parts + 1] = n .. "?" end
    if #parts == 0 then
        return numMembers and (numMembers .. " members") or ""
    end
    return table.concat(parts, " ")
end

--------------------------------------------------------------
-- Main frame
--------------------------------------------------------------

local frame = CreateFrame("Frame", "PickMeWindow", UIParent, "BackdropTemplate")
frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
frame:SetPoint("CENTER")
frame:SetFrameStrata("DIALOG")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetClampedToScreen(true)
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
})
frame:Hide()
table.insert(UISpecialFrames, "PickMeWindow")

-- Title
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -12)
title:SetText("|cFF00CC66PickMe|r")

-- Close button
local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -4, -4)
closeBtn:SetScript("OnClick", function() frame:Hide() end)

--------------------------------------------------------------
-- Mode toggle (Groups / Singles)
--------------------------------------------------------------

local modeY = -36

local groupsBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
groupsBtn:SetSize(80, 22)
groupsBtn:SetPoint("TOPLEFT", 16, modeY)
groupsBtn:SetText("Groups")

local singlesBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
singlesBtn:SetSize(80, 22)
singlesBtn:SetPoint("LEFT", groupsBtn, "RIGHT", 4, 0)
singlesBtn:SetText("Singles")

local function UpdateModeBtns()
    if activeMode == "groups" then
        groupsBtn:SetNormalFontObject("GameFontHighlight")
        singlesBtn:SetNormalFontObject("GameFontNormalSmall")
    else
        groupsBtn:SetNormalFontObject("GameFontNormalSmall")
        singlesBtn:SetNormalFontObject("GameFontHighlight")
    end
end

--------------------------------------------------------------
-- Global settings (right side of mode row)
--------------------------------------------------------------

local cooldownLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
cooldownLabel:SetPoint("TOPRIGHT", -110, modeY - 4)
cooldownLabel:SetText("Cooldown:")
cooldownLabel:SetTextColor(0.7, 0.7, 0.7)

local cooldownBox = CreateFrame("EditBox", "PickMeCooldownBox", frame, "InputBoxTemplate")
cooldownBox:SetSize(24, 18)
cooldownBox:SetPoint("LEFT", cooldownLabel, "RIGHT", 4, 0)
cooldownBox:SetAutoFocus(false)
cooldownBox:SetNumeric(true)
cooldownBox:SetMaxLetters(2)

local cooldownUnit = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
cooldownUnit:SetPoint("LEFT", cooldownBox, "RIGHT", 2, 0)
cooldownUnit:SetText("h")
cooldownUnit:SetTextColor(0.7, 0.7, 0.7)

local delayLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
delayLabel:SetPoint("LEFT", cooldownUnit, "RIGHT", 10, 0)
delayLabel:SetText("Delay:")
delayLabel:SetTextColor(0.7, 0.7, 0.7)

local delayBox = CreateFrame("EditBox", "PickMeDelayBox", frame, "InputBoxTemplate")
delayBox:SetSize(24, 18)
delayBox:SetPoint("LEFT", delayLabel, "RIGHT", 4, 0)
delayBox:SetAutoFocus(false)
delayBox:SetNumeric(true)
delayBox:SetMaxLetters(2)

local delayUnit = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
delayUnit:SetPoint("LEFT", delayBox, "RIGHT", 2, 0)
delayUnit:SetText("s")
delayUnit:SetTextColor(0.7, 0.7, 0.7)

local function SaveCooldown(self)
    local val = tonumber(self:GetText()) or 4
    if val < 1 then val = 1 end
    if val > 24 then val = 24 end
    PickMeDB.settings.cooldownHours = val
    self:SetText(tostring(val))
end

local function SaveDelay(self)
    local val = tonumber(self:GetText()) or 3
    if val < 1 then val = 1 end
    if val > 30 then val = 30 end
    PickMeDB.settings.whisperDelay = val
    self:SetText(tostring(val))
end

cooldownBox:SetScript("OnEnterPressed", function(self) SaveCooldown(self); self:ClearFocus() end)
cooldownBox:SetScript("OnEditFocusLost", SaveCooldown)
cooldownBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

delayBox:SetScript("OnEnterPressed", function(self) SaveDelay(self); self:ClearFocus() end)
delayBox:SetScript("OnEditFocusLost", SaveDelay)
delayBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

--------------------------------------------------------------
-- Template editbox (per-mode)
--------------------------------------------------------------

local templateY = modeY - 28

local templateLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
templateLabel:SetPoint("TOPLEFT", 16, templateY)
templateLabel:SetText("Template:")
templateLabel:SetTextColor(0.7, 0.7, 0.7)

local templateBox = CreateFrame("EditBox", "PickMeTemplateBox", frame, "InputBoxTemplate")
templateBox:SetPoint("TOPLEFT", 16, templateY - 16)
templateBox:SetSize(FRAME_WIDTH - 48, 20)
templateBox:SetAutoFocus(false)

local function SaveTemplate(self)
    local modeConfig = PickMeDB.modes[activeMode]
    if modeConfig then
        modeConfig.template = self:GetText()
    end
end

templateBox:SetScript("OnEnterPressed", function(self) SaveTemplate(self); self:ClearFocus() end)
templateBox:SetScript("OnEditFocusLost", SaveTemplate)
templateBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

local legendLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
legendLabel:SetPoint("TOPLEFT", 16, templateY - 38)
legendLabel:SetTextColor(0.4, 0.4, 0.4)
legendLabel:SetText("Variables: {leader} {dungeon} {role} {class} {level}")

--------------------------------------------------------------
-- Filter sections
--------------------------------------------------------------

local filterY = templateY - 56

local filterHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
filterHeader:SetPoint("TOPLEFT", 16, filterY)
filterHeader:SetText("Filters:")
filterHeader:SetTextColor(0.7, 0.7, 0.7)

-- Min Level
local minLevelLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
minLevelLabel:SetPoint("LEFT", filterHeader, "RIGHT", 8, 0)
minLevelLabel:SetText("Min level:")
minLevelLabel:SetTextColor(0.6, 0.6, 0.6)

local minLevelBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
minLevelBox:SetSize(30, 18)
minLevelBox:SetPoint("LEFT", minLevelLabel, "RIGHT", 4, 0)
minLevelBox:SetAutoFocus(false)
minLevelBox:SetNumeric(true)
minLevelBox:SetMaxLetters(2)

local function SaveMinLevel(self)
    local val = tonumber(self:GetText()) or 0
    if val < 0 then val = 0 end
    if val > 70 then val = 70 end
    local modeConfig = PickMeDB.modes[activeMode]
    if modeConfig then
        modeConfig.filters.minLevel = val
    end
end

minLevelBox:SetScript("OnEnterPressed", function(self) SaveMinLevel(self); self:ClearFocus() end)
minLevelBox:SetScript("OnEditFocusLost", SaveMinLevel)
minLevelBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

-- Role checkboxes
local roleY = filterY - 20
local roleCheckboxes = {}

local roleLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
roleLabel:SetPoint("TOPLEFT", 16, roleY)
roleLabel:SetText("Seeking:")
roleLabel:SetTextColor(0.6, 0.6, 0.6)

local roleNames = { "TANK", "HEALER", "DPS" }
local roleDisplay = { TANK = "Tank", HEALER = "Healer", DPS = "DPS" }

for i, role in ipairs(roleNames) do
    local cb = CreateFrame("CheckButton", "PickMeRole" .. role, frame, "UICheckButtonTemplate")
    cb:SetSize(20, 20)
    cb:SetPoint("TOPLEFT", 70 + (i - 1) * 80, roleY + 2)

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", cb, "RIGHT", 0, 0)
    label:SetText(roleDisplay[role])
    label:SetTextColor(0.8, 0.8, 0.8)

    cb:SetScript("OnClick", function(self)
        local filters = PickMeDB.modes[activeMode].filters
        filters.roles = filters.roles or {}
        if self:GetChecked() then
            local found = false
            for _, r in ipairs(filters.roles) do
                if r == role then found = true; break end
            end
            if not found then
                filters.roles[#filters.roles + 1] = role
            end
        else
            for j = #filters.roles, 1, -1 do
                if filters.roles[j] == role then
                    table.remove(filters.roles, j)
                end
            end
        end
    end)

    roleCheckboxes[role] = cb
end

-- Class exclude checkboxes (Singles mode only - 2 rows: 5+4)
local classY = roleY - 22
local classCheckboxes = {}
local classRow2Y = classY - 20

local classLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
classLabel:SetPoint("TOPLEFT", 16, classY)
classLabel:SetText("Exclude:")
classLabel:SetTextColor(0.6, 0.6, 0.6)

local CLASS_LIST = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
    "SHAMAN", "MAGE", "WARLOCK", "DRUID",
}
local CLASS_SHORT = {
    WARRIOR = "War", PALADIN = "Pal", HUNTER = "Hun",
    ROGUE = "Rog", PRIEST = "Pri", SHAMAN = "Sha",
    MAGE = "Mag", WARLOCK = "Wlk", DRUID = "Dru",
}

local classXOffset = 70
local classSpacing = 82

for i, class in ipairs(CLASS_LIST) do
    local cb = CreateFrame("CheckButton", "PickMeExcl" .. class, frame, "UICheckButtonTemplate")
    cb:SetSize(18, 18)

    -- 2 rows: first 5, then 4
    local row = (i <= 5) and 0 or 1
    local col = (i <= 5) and (i - 1) or (i - 6)
    local y = row == 0 and classY or classRow2Y
    cb:SetPoint("TOPLEFT", classXOffset + col * classSpacing, y + 2)

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", cb, "RIGHT", -2, 0)
    label:SetText(CLASS_SHORT[class])

    -- Color by class
    local CLASS_COLORS_INLINE = {
        WARRIOR = {0.78, 0.61, 0.43}, PALADIN = {0.96, 0.55, 0.73},
        HUNTER = {0.67, 0.83, 0.45}, ROGUE = {1.00, 0.96, 0.41},
        PRIEST = {1.00, 1.00, 1.00}, SHAMAN = {0.00, 0.44, 0.87},
        MAGE = {0.25, 0.78, 0.92}, WARLOCK = {0.53, 0.53, 0.93},
        DRUID = {1.00, 0.49, 0.04},
    }
    local cc = CLASS_COLORS_INLINE[class]
    if cc then label:SetTextColor(cc[1], cc[2], cc[3]) end

    cb:SetScript("OnClick", function(self)
        local filters = PickMeDB.modes[activeMode].filters
        filters.excludeClasses = filters.excludeClasses or {}
        if self:GetChecked() then
            local found = false
            for _, c in ipairs(filters.excludeClasses) do
                if c == class then found = true; break end
            end
            if not found then
                filters.excludeClasses[#filters.excludeClasses + 1] = class
            end
        else
            for j = #filters.excludeClasses, 1, -1 do
                if filters.excludeClasses[j] == class then
                    table.remove(filters.excludeClasses, j)
                end
            end
        end
    end)

    classCheckboxes[class] = cb
end

-- Track class filter UI elements for show/hide based on mode
local classFilterElements = { classLabel }
for _, cb in pairs(classCheckboxes) do
    classFilterElements[#classFilterElements + 1] = cb
end

local function UpdateClassFilterVisibility()
    -- Class exclude only applies to Singles mode
    for _, el in ipairs(classFilterElements) do
        if activeMode == "singles" then
            el:Show()
        else
            el:Hide()
        end
    end
end

--------------------------------------------------------------
-- Divider line between config and listings
--------------------------------------------------------------

local dividerY = classRow2Y - 22
local divider = frame:CreateTexture(nil, "OVERLAY")
divider:SetPoint("TOPLEFT", 12, dividerY)
divider:SetPoint("TOPRIGHT", -12, dividerY)
divider:SetHeight(1)
divider:SetColorTexture(0.3, 0.3, 0.3, 0.8)

--------------------------------------------------------------
-- Listing zone (FauxScrollFrame)
--------------------------------------------------------------

local listingTop = dividerY - 4

local scrollFrame = CreateFrame("ScrollFrame", "PickMeListingScrollFrame", frame, "FauxScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 8, listingTop)
scrollFrame:SetPoint("BOTTOMRIGHT", -28, FOOTER_HEIGHT + 8)

local emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
emptyText:SetPoint("CENTER", scrollFrame, "CENTER", 0, 0)
emptyText:SetTextColor(0.5, 0.5, 0.5)
emptyText:Hide()

--------------------------------------------------------------
-- Row creation for listings
--------------------------------------------------------------

local rows = {}

local function CreateListingRow(index)
    local row = CreateFrame("Frame", nil, frame)
    row:SetSize(FRAME_WIDTH - 50, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))

    -- Leader name
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.nameText:SetPoint("LEFT", 5, 0)
    row.nameText:SetWidth(100)
    row.nameText:SetJustifyH("LEFT")

    -- Dungeon
    row.dungeonText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.dungeonText:SetPoint("LEFT", row.nameText, "RIGHT", 4, 0)
    row.dungeonText:SetWidth(130)
    row.dungeonText:SetJustifyH("LEFT")
    row.dungeonText:SetTextColor(0.9, 0.9, 0.9)

    -- Role counts
    row.compText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.compText:SetPoint("LEFT", row.dungeonText, "RIGHT", 4, 0)
    row.compText:SetWidth(80)
    row.compText:SetJustifyH("LEFT")
    row.compText:SetTextColor(0.7, 0.7, 0.7)

    -- Send button
    row.sendBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.sendBtn:SetSize(50, 20)
    row.sendBtn:SetPoint("RIGHT", -2, 0)
    row.sendBtn:SetText("Send")

    -- Sent status text (right-clickable to clear)
    row.sentText = CreateFrame("Button", nil, row)
    row.sentText:SetSize(65, 20)
    row.sentText:SetPoint("RIGHT", -2, 0)
    row.sentText.label = row.sentText:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.sentText.label:SetAllPoints()
    row.sentText.label:SetJustifyH("RIGHT")
    row.sentText:Hide()

    -- Flash overlay
    row.flash = row:CreateTexture(nil, "OVERLAY")
    row.flash:SetAllPoints()
    row.flash:SetColorTexture(0, 0.8, 0.4, 0.3)
    row.flash:Hide()

    -- Hover highlight
    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.06)

    -- Tooltip
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        if not self.tooltipData then return end
        local d = self.tooltipData
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:AddLine(d.leaderName or "", ACCENT.r, ACCENT.g, ACCENT.b)
        GameTooltip:AddLine(d.dungeon or "", 0.9, 0.9, 0.9)
        if d.description and d.description ~= "" then
            GameTooltip:AddLine(d.description, 1, 1, 1, true)
        end
        if d.roleCounts then
            GameTooltip:AddLine(" ")
            local t = d.roleCounts.TANK or 0
            local h = d.roleCounts.HEALER or 0
            local dd = d.roleCounts.DAMAGER or 0
            GameTooltip:AddLine("Composition: " .. t .. " Tank, " .. h .. " Healer, " .. dd .. " DPS", 0.7, 0.7, 0.7)
        end
        if d.seekingRoles and #d.seekingRoles > 0 then
            local seekStr = table.concat(d.seekingRoles, ", ")
            GameTooltip:AddLine("Seeking: " .. seekStr, 1, 0.82, 0)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(d.numMembers .. " members", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return row
end

for i = 1, VISIBLE_ROWS do
    rows[i] = CreateListingRow(i)
end

--------------------------------------------------------------
-- Get filtered listings for current mode
--------------------------------------------------------------

local function GetFilteredListings()
    local rawListings
    if activeMode == "groups" then
        rawListings = PickMe:GetGroupResults()
    else
        rawListings = PickMe:GetSingleResults()
    end
    if not rawListings then return {}, 0 end

    local fe = GetFilterEngine()
    local filters = PickMeDB.modes[activeMode] and PickMeDB.modes[activeMode].filters
    local filtered = {}

    for _, listing in ipairs(rawListings) do
        if not fe or fe.PassesFilter(listing, filters, activeMode) then
            filtered[#filtered + 1] = listing
        end
    end

    return filtered, #rawListings
end

--------------------------------------------------------------
-- Update listing display
--------------------------------------------------------------

local filteredCount = 0
local totalCount = 0
local sessionWhispers = 0

-- Forward declaration for mutual reference
local UpdateListings

UpdateListings = function()
    if not frame:IsShown() then return end

    local listings, rawTotal = GetFilteredListings()
    totalCount = rawTotal
    filteredCount = rawTotal - #listings
    local numItems = #listings

    local offset = FauxScrollFrame_GetOffset(scrollFrame)
    FauxScrollFrame_Update(scrollFrame, numItems, VISIBLE_ROWS, ROW_HEIGHT)

    if numItems == 0 then
        if rawTotal > 0 then
            emptyText:SetText("All listings filtered out (" .. rawTotal .. " hidden)")
        else
            emptyText:SetText("No LFG listings found\nOpen the LFG Browse panel to scan")
        end
        emptyText:Show()
    else
        emptyText:Hide()
    end

    local throttled = PickMe:IsThrottled()

    for i = 1, VISIBLE_ROWS do
        local row = rows[i]
        local index = offset + i
        local listing = listings[index]

        if listing then
            -- Leader name (no class color available without member info)
            row.nameText:SetText(listing.leaderName or "?")
            row.nameText:SetTextColor(0.6, 0.8, 1.0)

            -- Dungeon (truncated)
            local dungeon = listing.dungeon or ""
            if #dungeon > 20 then
                dungeon = dungeon:sub(1, 17) .. "..."
            end
            row.dungeonText:SetText(dungeon)

            -- Role counts
            row.compText:SetText(FormatRoleCounts(listing.roleCounts, listing.numMembers))

            -- Send button or Sent status
            local historyEntry = PickMe:FindInHistory(listing.leaderName)
            if historyEntry then
                row.sendBtn:Hide()
                row.sentText.label:SetText("|cFF00CC66Sent " .. FormatRelativeTime(historyEntry.time) .. "|r")
                row.sentText:Show()
                -- Right-click to clear history entry and re-enable
                row.sentText:SetScript("OnClick", function(_, button)
                    if button == "RightButton" then
                        PickMe:ClearHistoryEntry(listing.leaderName)
                        UpdateListings()
                    end
                end)
                row.sentText:RegisterForClicks("RightButtonUp")
                -- Tooltip hint on sent text
                row.sentText:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
                    GameTooltip:AddLine("Right-click to clear and re-enable", 0.7, 0.7, 0.7)
                    GameTooltip:Show()
                end)
                row.sentText:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
            else
                row.sentText:Hide()
                row.sendBtn:Show()
                if throttled then
                    row.sendBtn:Disable()
                else
                    row.sendBtn:Enable()
                end
                row.sendBtn:SetScript("OnClick", function()
                    local success = PickMe:SendWhisper(
                        listing.leaderName, listing.dungeon, activeMode
                    )
                    if success then
                        row.flash:Show()
                        C_Timer.After(0.3, function()
                            if row.flash then row.flash:Hide() end
                        end)
                        sessionWhispers = sessionWhispers + 1
                        UpdateListings()
                    end
                end)
            end

            row.tooltipData = listing
            row:Show()
        else
            row:Hide()
        end
    end
end

scrollFrame:SetScript("OnVerticalScroll", function(sf, offset)
    FauxScrollFrame_OnVerticalScroll(sf, offset, ROW_HEIGHT, UpdateListings)
end)

--------------------------------------------------------------
-- Footer
--------------------------------------------------------------

local footerLeft = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
footerLeft:SetPoint("BOTTOMLEFT", 14, 8)
footerLeft:SetTextColor(0.5, 0.5, 0.5)

local footerRight = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
footerRight:SetPoint("BOTTOMRIGHT", -14, 8)
footerRight:SetJustifyH("RIGHT")
footerRight:SetTextColor(0.5, 0.5, 0.5)

local function UpdateFooter()
    local showing = totalCount - filteredCount
    if filteredCount > 0 then
        footerLeft:SetText(showing .. " listings (" .. filteredCount .. " filtered)")
    else
        footerLeft:SetText(showing .. " listings")
    end
    footerRight:SetText(sessionWhispers .. " whispered this session")
end

--------------------------------------------------------------
-- Mode switching
--------------------------------------------------------------

local function LoadModeConfig()
    local modeConfig = PickMeDB.modes[activeMode]
    if not modeConfig then return end

    templateBox:SetText(modeConfig.template or "")

    local minLvl = modeConfig.filters.minLevel or 0
    minLevelBox:SetText(minLvl > 0 and tostring(minLvl) or "")

    local activeRoles = modeConfig.filters.roles or {}
    for _, role in ipairs(roleNames) do
        local isActive = false
        for _, r in ipairs(activeRoles) do
            if r == role then isActive = true; break end
        end
        roleCheckboxes[role]:SetChecked(isActive)
    end

    local exclClasses = modeConfig.filters.excludeClasses or {}
    for _, class in ipairs(CLASS_LIST) do
        local isExcl = false
        for _, c in ipairs(exclClasses) do
            if c == class then isExcl = true; break end
        end
        classCheckboxes[class]:SetChecked(isExcl)
    end
end

local function SwitchMode(mode)
    activeMode = mode
    UpdateModeBtns()
    UpdateClassFilterVisibility()
    LoadModeConfig()
    UpdateListings()
    UpdateFooter()
end

groupsBtn:SetScript("OnClick", function() SwitchMode("groups"); PlaySound(808) end)
singlesBtn:SetScript("OnClick", function() SwitchMode("singles"); PlaySound(808) end)

--------------------------------------------------------------
-- OnShow / OnUpdate
--------------------------------------------------------------

frame:SetScript("OnShow", function()
    cooldownBox:SetText(tostring(PickMeDB.settings.cooldownHours or 4))
    delayBox:SetText(tostring(PickMeDB.settings.whisperDelay or 3))
    LoadModeConfig()
    UpdateModeBtns()
    UpdateClassFilterVisibility()
    UpdateListings()
    UpdateFooter()
end)

frame:SetScript("OnHide", function()
    templateBox:ClearFocus()
    cooldownBox:ClearFocus()
    delayBox:ClearFocus()
    minLevelBox:ClearFocus()
end)

frame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed >= 1 then
        self.elapsed = 0
        if self:IsShown() then
            UpdateListings()
            UpdateFooter()
        end
    end
end)

--------------------------------------------------------------
-- Callback: Scanner results updated
--------------------------------------------------------------

function PickMe:OnScanResultsUpdated()
    if frame:IsShown() then
        UpdateListings()
        UpdateFooter()
    end
end

--------------------------------------------------------------
-- Public API
--------------------------------------------------------------

function PickMe:ToggleMainFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

PickMe.ToggleMessageFrame = PickMe.ToggleMainFrame
PickMe.ShowMessageFrame = function(self) frame:Show() end
PickMe.ToggleFrame = PickMe.ToggleMainFrame
