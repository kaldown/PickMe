local _, PickMe = ...

--------------------------------------------------------------
-- Constants
--------------------------------------------------------------

local FRAME_WIDTH = 500
local FRAME_HEIGHT = 500
local FOOTER_HEIGHT = 24
local ROW_HEIGHT = 26
local VISIBLE_ROWS = 9
local ACCENT = { r = 0, g = 0.8, b = 0.4 }

-- Role icon texture (64x64 grid: leader/healer top, tank/dps bottom)
local ROLE_ICON_TEXTURE = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
local ROLE_ICON_SIZE = 14
local ROLE_ICON_COORDS = {
    TANK    = { 0,       19/64, 22/64, 41/64 },
    HEALER  = { 20/64,   39/64, 1/64,  20/64 },
    DAMAGER = { 20/64,   39/64, 22/64, 41/64 },
}
local MAX_ROLE_ICONS = 5

local FE = nil
local activeMode = "groups"
local isDirty = false

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

-- Sort controls
local sortY = roleY - 22

local sortLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sortLabel:SetPoint("TOPLEFT", 16, sortY)
sortLabel:SetText("Sort:")
sortLabel:SetTextColor(0.6, 0.6, 0.6)

local sortNoneBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
sortNoneBtn:SetSize(42, 18)
sortNoneBtn:SetPoint("LEFT", sortLabel, "RIGHT", 6, 0)
sortNoneBtn:SetText("None")

local sortNameBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
sortNameBtn:SetSize(48, 18)
sortNameBtn:SetPoint("LEFT", sortNoneBtn, "RIGHT", 2, 0)
sortNameBtn:SetText("Name")

local sortLevelBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
sortLevelBtn:SetSize(46, 18)
sortLevelBtn:SetPoint("LEFT", sortNameBtn, "RIGHT", 2, 0)
sortLevelBtn:SetText("Level")

local sortDirBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
sortDirBtn:SetSize(36, 18)
sortDirBtn:SetPoint("LEFT", sortLevelBtn, "RIGHT", 6, 0)
sortDirBtn:SetText("Asc")

local function UpdateSortButtons()
    local filters = PickMeDB.modes[activeMode].filters
    local sortBy = filters.sortBy or "none"
    local sortDir = filters.sortDir or "asc"

    sortNoneBtn:SetNormalFontObject(sortBy == "none" and "GameFontHighlight" or "GameFontNormalSmall")
    sortNameBtn:SetNormalFontObject(sortBy == "name" and "GameFontHighlight" or "GameFontNormalSmall")
    sortLevelBtn:SetNormalFontObject(sortBy == "level" and "GameFontHighlight" or "GameFontNormalSmall")
    sortDirBtn:SetText(sortDir == "asc" and "Asc" or "Desc")

    if sortBy == "none" then
        sortDirBtn:Hide()
    else
        sortDirBtn:Show()
    end
end

local function SetSort(sortBy)
    local filters = PickMeDB.modes[activeMode].filters
    filters.sortBy = sortBy
    UpdateSortButtons()
    isDirty = true
end

sortNoneBtn:SetScript("OnClick", function() SetSort("none"); PlaySound(808) end)
sortNameBtn:SetScript("OnClick", function() SetSort("name"); PlaySound(808) end)
sortLevelBtn:SetScript("OnClick", function() SetSort("level"); PlaySound(808) end)
sortDirBtn:SetScript("OnClick", function()
    local filters = PickMeDB.modes[activeMode].filters
    filters.sortDir = (filters.sortDir == "asc") and "desc" or "asc"
    UpdateSortButtons()
    isDirty = true
    PlaySound(808)
end)

-- Class filter mode toggle (Off / Exclude / Include)
local classY = sortY - 22

local classOffBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
classOffBtn:SetSize(30, 18)
classOffBtn:SetPoint("TOPLEFT", 16, classY + 2)
classOffBtn:SetText("Off")

local classExclBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
classExclBtn:SetSize(56, 18)
classExclBtn:SetPoint("LEFT", classOffBtn, "RIGHT", 2, 0)
classExclBtn:SetText("Exclude")

local classInclBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
classInclBtn:SetSize(56, 18)
classInclBtn:SetPoint("LEFT", classExclBtn, "RIGHT", 2, 0)
classInclBtn:SetText("Include")

-- Strict checkbox (only visible in include mode)
local strictCb = CreateFrame("CheckButton", "PickMeStrictCb", frame, "UICheckButtonTemplate")
strictCb:SetSize(18, 18)
strictCb:SetPoint("LEFT", classInclBtn, "RIGHT", 4, 0)

local strictLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
strictLabel:SetPoint("LEFT", strictCb, "RIGHT", -2, 0)
strictLabel:SetText("Strict")
strictLabel:SetTextColor(0.6, 0.6, 0.6)
strictCb:Hide()
strictLabel:Hide()

-- Class checkboxes (2 rows: 5+4)
local classCheckboxes = {}
local classCbY = classY - 20
local classCbRow2Y = classCbY - 20

-- Class data from FilterEngine (avoid duplication)
local CLASS_SHORT = {
    WARRIOR = "War", PALADIN = "Pal", HUNTER = "Hun",
    ROGUE = "Rog", PRIEST = "Pri", SHAMAN = "Sha",
    MAGE = "Mag", WARLOCK = "Wlk", DRUID = "Dru",
}

local classXOffset = 16
local classSpacing = 82

local fe = GetFilterEngine()
for i, class in ipairs(fe.CLASS_LIST) do
    local cb = CreateFrame("CheckButton", "PickMeExcl" .. class, frame, "UICheckButtonTemplate")
    cb:SetSize(18, 18)

    -- 2 rows: first 5, then 4
    local row = (i <= 5) and 0 or 1
    local col = (i <= 5) and (i - 1) or (i - 6)
    local y = row == 0 and classCbY or classCbRow2Y
    cb:SetPoint("TOPLEFT", classXOffset + col * classSpacing, y + 2)

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", cb, "RIGHT", -2, 0)
    label:SetText(CLASS_SHORT[class])

    local cc = fe.CLASS_COLORS[class]
    if cc then label:SetTextColor(cc.r, cc.g, cc.b) end

    cb:SetScript("OnClick", function(self)
        local filters = PickMeDB.modes[activeMode].filters
        filters.classes = filters.classes or {}
        if self:GetChecked() then
            local found = false
            for _, c in ipairs(filters.classes) do
                if c == class then found = true; break end
            end
            if not found then
                filters.classes[#filters.classes + 1] = class
            end
        else
            for j = #filters.classes, 1, -1 do
                if filters.classes[j] == class then
                    table.remove(filters.classes, j)
                end
            end
        end
        isDirty = true
    end)

    classCheckboxes[class] = { cb = cb, label = label }
end

local function UpdateClassModeButtons()
    local filters = PickMeDB.modes[activeMode].filters
    local mode = filters.classFilterMode or "off"

    classOffBtn:SetNormalFontObject(mode == "off" and "GameFontHighlight" or "GameFontNormalSmall")
    classExclBtn:SetNormalFontObject(mode == "exclude" and "GameFontHighlight" or "GameFontNormalSmall")
    classInclBtn:SetNormalFontObject(mode == "include" and "GameFontHighlight" or "GameFontNormalSmall")

    if mode == "include" then
        strictCb:Show()
        strictLabel:Show()
        strictCb:SetChecked(filters.classFilterStrict or false)
    else
        strictCb:Hide()
        strictLabel:Hide()
    end

    -- Show/hide class checkboxes based on mode
    local showClasses = (mode ~= "off")
    for _, pair in pairs(classCheckboxes) do
        if showClasses then
            pair.cb:Show()
            pair.label:Show()
        else
            pair.cb:Hide()
            pair.label:Hide()
        end
    end
end

local function SetClassFilterMode(filterMode)
    local filters = PickMeDB.modes[activeMode].filters
    filters.classFilterMode = filterMode
    UpdateClassModeButtons()
    isDirty = true
end

classOffBtn:SetScript("OnClick", function() SetClassFilterMode("off"); PlaySound(808) end)
classExclBtn:SetScript("OnClick", function() SetClassFilterMode("exclude"); PlaySound(808) end)
classInclBtn:SetScript("OnClick", function() SetClassFilterMode("include"); PlaySound(808) end)
strictCb:SetScript("OnClick", function(self)
    local filters = PickMeDB.modes[activeMode].filters
    filters.classFilterStrict = self:GetChecked()
    isDirty = true
end)

--------------------------------------------------------------
-- Divider line between config and listings
--------------------------------------------------------------

local dividerY = classCbRow2Y - 22
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

    -- Role icons (pre-created pool of MAX_ROLE_ICONS textures)
    row.roleIcons = {}
    for ri = 1, MAX_ROLE_ICONS do
        local icon = row:CreateTexture(nil, "OVERLAY")
        icon:SetSize(ROLE_ICON_SIZE, ROLE_ICON_SIZE)
        if ri == 1 then
            icon:SetPoint("LEFT", row.dungeonText, "RIGHT", 4, 0)
        else
            icon:SetPoint("LEFT", row.roleIcons[ri - 1], "RIGHT", 1, 0)
        end
        icon:SetTexture(ROLE_ICON_TEXTURE)
        icon:Hide()
        row.roleIcons[ri] = icon
    end

    -- NOROLE fallback text (shown only if a member has no role)
    row.noroleText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.noroleText:SetText("?")
    row.noroleText:SetTextColor(0.5, 0.5, 0.5)
    row.noroleText:Hide()

    -- Fallback member count text (when no role data available)
    row.memberCountText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.memberCountText:SetPoint("LEFT", row.dungeonText, "RIGHT", 4, 0)
    row.memberCountText:SetWidth(80)
    row.memberCountText:SetJustifyH("LEFT")
    row.memberCountText:SetTextColor(0.7, 0.7, 0.7)
    row.memberCountText:Hide()

    -- Send button (created before note badge so it can be used as anchor)
    row.sendBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.sendBtn:SetSize(50, 20)
    row.sendBtn:SetPoint("RIGHT", -2, 0)
    row.sendBtn:SetText("Send")

    -- Note/message badge (envelope icon next to leader name)
    row.noteBadge = CreateFrame("Frame", nil, row)
    row.noteBadge:SetSize(14, ROW_HEIGHT)
    row.noteBadge:SetPoint("LEFT", row.nameText, "RIGHT", 0, 0)
    row.noteBadge:EnableMouse(true)
    row.noteBadge.icon = row.noteBadge:CreateTexture(nil, "OVERLAY")
    row.noteBadge.icon:SetSize(12, 12)
    row.noteBadge.icon:SetPoint("LEFT", 1, 0)
    row.noteBadge.icon:SetTexture("Interface\\Icons\\INV_Letter_15")
    row.noteBadge:SetScript("OnEnter", function(self)
        if self.description and self.description ~= "" then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:AddLine(self.description, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    row.noteBadge:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    row.noteBadge:Hide()

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
        local fe = GetFilterEngine()

        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")

        -- Header: dungeon name
        GameTooltip:AddLine(d.dungeon or "Unknown", 1, 1, 1)

        -- Member list: role icon + class-colored name + level
        if d.members and fe and #d.members > 0 then
            GameTooltip:AddLine(" ")
            -- Sort: tanks, healers, DPS, norole
            local sorted = {}
            for _, m in ipairs(d.members) do
                sorted[#sorted + 1] = m
            end
            local roleSort = { TANK = 1, HEALER = 2, DAMAGER = 3 }
            table.sort(sorted, function(a, b)
                return (roleSort[a.role] or 4) < (roleSort[b.role] or 4)
            end)

            for _, m in ipairs(sorted) do
                -- Build inline role icon
                local roleIcon = ""
                local coords = ROLE_ICON_COORDS[m.role]
                if coords then
                    roleIcon = string.format(
                        "|T%s:0:0:0:0:64:64:%d:%d:%d:%d|t ",
                        ROLE_ICON_TEXTURE,
                        coords[1] * 64, coords[2] * 64,
                        coords[3] * 64, coords[4] * 64
                    )
                end

                -- Class-colored name
                local name = m.classLocalized or (fe.CLASS_DISPLAY and fe.CLASS_DISPLAY[m.class]) or m.class or "Unknown"
                local cc = fe.CLASS_COLORS and fe.CLASS_COLORS[m.class]
                if cc then
                    local hex = string.format("|cFF%02x%02x%02x", cc.r * 255, cc.g * 255, cc.b * 255)
                    name = hex .. name .. "|r"
                end

                -- Level
                local lvlStr = ""
                if m.level and m.level > 0 then
                    lvlStr = "  Lvl " .. m.level
                end

                GameTooltip:AddLine(roleIcon .. name .. lvlStr, 1, 1, 1)
            end
        end

        -- Description in quotes
        if d.description and d.description ~= "" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("\"" .. d.description .. "\"", 0.8, 0.8, 0.8, true)
        end

        -- Summary line
        GameTooltip:AddLine(" ")
        local t = d.roleCounts and d.roleCounts.TANK or 0
        local h = d.roleCounts and d.roleCounts.HEALER or 0
        local dd = d.roleCounts and d.roleCounts.DAMAGER or 0
        GameTooltip:AddLine(
            "Members: " .. (d.numMembers or 0) .. " (" .. t .. "/" .. h .. "/" .. dd .. ")",
            0.5, 0.5, 0.5
        )

        -- Seeking roles
        if d.seekingRoles and #d.seekingRoles > 0 then
            local seekDisplay = {}
            local roleLabels = { TANK = "Tank", HEALER = "Healer", DPS = "DPS" }
            for _, r in ipairs(d.seekingRoles) do
                seekDisplay[#seekDisplay + 1] = roleLabels[r] or r
            end
            GameTooltip:AddLine("Seeking: " .. table.concat(seekDisplay, ", "), 1, 0.82, 0)
        end

        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Row API: role icon population
    function row:UpdateRoleIcons(listing)
        for ri = 1, MAX_ROLE_ICONS do
            self.roleIcons[ri]:Hide()
        end
        self.noroleText:Hide()
        self.memberCountText:Hide()

        if listing.members and #listing.members > 0 then
            local sorted = {}
            for _, m in ipairs(listing.members) do
                sorted[#sorted + 1] = m
            end
            local roleOrder = { TANK = 1, HEALER = 2, DAMAGER = 3 }
            table.sort(sorted, function(a, b)
                return (roleOrder[a.role] or 4) < (roleOrder[b.role] or 4)
            end)

            local iconIndex = 0
            for _, m in ipairs(sorted) do
                local coords = ROLE_ICON_COORDS[m.role]
                if coords then
                    iconIndex = iconIndex + 1
                    if iconIndex <= MAX_ROLE_ICONS then
                        local icon = self.roleIcons[iconIndex]
                        icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                        icon:Show()
                    end
                else
                    self.noroleText:ClearAllPoints()
                    if iconIndex > 0 then
                        self.noroleText:SetPoint("LEFT", self.roleIcons[iconIndex], "RIGHT", 2, 0)
                    else
                        self.noroleText:SetPoint("LEFT", self.dungeonText, "RIGHT", 4, 0)
                    end
                    self.noroleText:Show()
                end
            end
        elseif listing.roleCounts then
            local iconIndex = 0
            local roleSeq = { "TANK", "HEALER", "DAMAGER" }
            for _, role in ipairs(roleSeq) do
                local count = listing.roleCounts[role] or 0
                local coords = ROLE_ICON_COORDS[role]
                if coords then
                    for _ = 1, count do
                        iconIndex = iconIndex + 1
                        if iconIndex <= MAX_ROLE_ICONS then
                            local icon = self.roleIcons[iconIndex]
                            icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                            icon:Show()
                        end
                    end
                end
            end
            local noroleCount = listing.roleCounts.NOROLE or 0
            if noroleCount > 0 then
                self.noroleText:ClearAllPoints()
                if iconIndex > 0 then
                    self.noroleText:SetPoint("LEFT", self.roleIcons[iconIndex], "RIGHT", 2, 0)
                else
                    self.noroleText:SetPoint("LEFT", self.dungeonText, "RIGHT", 4, 0)
                end
                self.noroleText:Show()
            end
            if iconIndex == 0 and noroleCount == 0 then
                self.memberCountText:SetText(listing.numMembers and (listing.numMembers .. " members") or "")
                self.memberCountText:Show()
            end
        else
            self.memberCountText:SetText(listing.numMembers and (listing.numMembers .. " members") or "")
            self.memberCountText:Show()
        end
    end

    -- Row API: populate all elements from listing data
    function row:Update(listing, state)
        local fe = GetFilterEngine()

        -- Leader name (class-colored)
        self.nameText:SetText(listing.leaderName or "?")
        local cc = fe and listing.leaderClass and fe.CLASS_COLORS[listing.leaderClass]
        if cc then
            self.nameText:SetTextColor(cc.r, cc.g, cc.b)
        else
            self.nameText:SetTextColor(0.6, 0.8, 1.0)
        end

        -- Dungeon (truncated)
        local dungeon = listing.dungeon or ""
        if #dungeon > 20 then
            dungeon = dungeon:sub(1, 17) .. "..."
        end
        self.dungeonText:SetText(dungeon)

        -- Role icons
        self:UpdateRoleIcons(listing)

        -- Note badge + anchor chain
        if listing.description and listing.description ~= "" then
            self.noteBadge.description = listing.description
            self.noteBadge:Show()
            self.dungeonText:ClearAllPoints()
            self.dungeonText:SetPoint("LEFT", self.noteBadge, "RIGHT", 0, 0)
        else
            self.noteBadge.description = nil
            self.noteBadge:Hide()
            self.dungeonText:ClearAllPoints()
            self.dungeonText:SetPoint("LEFT", self.nameText, "RIGHT", 4, 0)
        end

        -- Send button / Sent status
        if state.historyEntry then
            self.sendBtn:Hide()
            self.sentText.label:SetText("|cFF00CC66Sent " .. FormatRelativeTime(state.historyEntry.time) .. "|r")
            self.sentText:Show()
            self.sentText:SetScript("OnClick", function(_, button)
                if button == "RightButton" and state.onClearHistory then
                    state.onClearHistory(listing.leaderName)
                end
            end)
            self.sentText:RegisterForClicks("RightButtonUp")
            self.sentText:SetScript("OnEnter", function(btn)
                GameTooltip:SetOwner(btn, "ANCHOR_CURSOR")
                GameTooltip:AddLine("Right-click to clear and re-enable", 0.7, 0.7, 0.7)
                GameTooltip:Show()
            end)
            self.sentText:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        else
            self.sentText:Hide()
            self.sendBtn:Show()
            if state.throttled then
                self.sendBtn:Disable()
            else
                self.sendBtn:Enable()
            end
            self.sendBtn:SetScript("OnClick", function()
                if state.onSend then
                    local success = state.onSend(listing.leaderName, listing.dungeon)
                    if success then
                        self.flash:Show()
                        C_Timer.After(0.3, function()
                            if self.flash then self.flash:Hide() end
                        end)
                    end
                end
            end)
        end

        -- Tooltip data
        self.tooltipData = listing
    end

    -- Row API: hide all elements for empty/offscreen rows
    function row:Clear()
        self.nameText:SetText("")
        self.nameText:SetTextColor(0.6, 0.8, 1.0)
        self.dungeonText:SetText("")
        self.dungeonText:ClearAllPoints()
        self.dungeonText:SetPoint("LEFT", self.nameText, "RIGHT", 4, 0)
        for ri = 1, MAX_ROLE_ICONS do
            self.roleIcons[ri]:Hide()
        end
        self.noroleText:Hide()
        self.memberCountText:Hide()
        self.noteBadge:Hide()
        self.noteBadge.description = nil
        self.sendBtn:Hide()
        self.sentText:Hide()
        self.tooltipData = nil
    end

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

    -- Sort if requested
    local sortBy = filters and filters.sortBy or "none"
    local sortDir = filters and filters.sortDir or "asc"

    if sortBy == "name" then
        table.sort(filtered, function(a, b)
            local nameA = (a.leaderName or ""):lower()
            local nameB = (b.leaderName or ""):lower()
            if sortDir == "desc" then
                return nameA > nameB
            else
                return nameA < nameB
            end
        end)
    elseif sortBy == "level" then
        table.sort(filtered, function(a, b)
            local lvlA = a.leaderLevel or 0
            local lvlB = b.leaderLevel or 0
            if sortDir == "desc" then
                return lvlA > lvlB
            else
                return lvlA < lvlB
            end
        end)
    end
    -- sortBy == "none": preserve stable insertion order from Scanner

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

-- Shared row action callbacks (defined once, reused by all rows)
local rowCallbacks = {}

UpdateListings = function()
    if not frame:IsShown() then return end

    -- If player has no active listing, force empty state
    if PickMe.HasActiveListing and not PickMe:HasActiveListing() then
        totalCount = 0
        filteredCount = 0
        FauxScrollFrame_Update(scrollFrame, 0, VISIBLE_ROWS, ROW_HEIGHT)
        emptyText:SetText("List yourself in LFG to start scanning")
        emptyText:Show()
        for i = 1, VISIBLE_ROWS do
            rows[i]:Clear()
            rows[i]:Hide()
        end
        return
    end

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
    local rowState = {
        throttled = throttled,
        onSend = rowCallbacks.onSend,
        onClearHistory = rowCallbacks.onClearHistory,
    }

    for i = 1, VISIBLE_ROWS do
        local row = rows[i]
        local listing = listings[offset + i]

        if listing then
            rowState.historyEntry = PickMe:FindInHistory(listing.leaderName)
            row:Update(listing, rowState)
            row:Show()
            -- Grey out stale listings
            if PickMe.IsListingStale and PickMe:IsListingStale(listing.leaderName) then
                row:SetAlpha(0.4)
                row.sendBtn:Disable()
            else
                row:SetAlpha(1.0)
            end
        else
            row:Clear()
            row:Hide()
        end
    end
end

-- Wire up callbacks after UpdateListings is defined
rowCallbacks.onSend = function(leaderName, dungeon)
    local success = PickMe:SendWhisper(leaderName, dungeon, activeMode)
    if success then
        sessionWhispers = sessionWhispers + 1
        UpdateListings()
    end
    return success
end

rowCallbacks.onClearHistory = function(leaderName)
    PickMe:ClearHistoryEntry(leaderName)
    UpdateListings()
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

    -- Class filter checkboxes
    local fe2 = GetFilterEngine()
    local selectedClasses = modeConfig.filters.classes or {}
    for _, class in ipairs(fe2.CLASS_LIST) do
        local isSelected = false
        for _, c in ipairs(selectedClasses) do
            if c == class then isSelected = true; break end
        end
        classCheckboxes[class].cb:SetChecked(isSelected)
    end

    UpdateClassModeButtons()
    UpdateSortButtons()
end

local function SwitchMode(mode)
    activeMode = mode
    UpdateModeBtns()
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
    isDirty = true
end)

frame:SetScript("OnHide", function()
    templateBox:ClearFocus()
    cooldownBox:ClearFocus()
    delayBox:ClearFocus()
    minLevelBox:ClearFocus()
end)

frame:SetScript("OnUpdate", function(self, elapsed)
    if not self:IsShown() then return end
    if isDirty then
        isDirty = false
        UpdateListings()
        UpdateFooter()
    end
end)

--------------------------------------------------------------
-- Callback: Scanner results updated
--------------------------------------------------------------

function PickMe:OnScanResultsUpdated()
    isDirty = true
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
