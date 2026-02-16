local _, PickMe = ...

--------------------------------------------------------------
-- Constants
--------------------------------------------------------------

local FRAME_WIDTH = 420
local FRAME_HEIGHT = 350
local HEADER_HEIGHT = 40
local FOOTER_HEIGHT = 30
local ROW_HEIGHT = 28
local VISIBLE_ROWS = 8
local ACCENT = { r = 0, g = 0.8, b = 0.4 }

local viewMode = "queued" -- "queued" or "history"

--------------------------------------------------------------
-- Time formatting
--------------------------------------------------------------

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

local frame = CreateFrame("Frame", "PickMeMessageFrame", UIParent, "BackdropTemplate")
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
table.insert(UISpecialFrames, "PickMeMessageFrame")

-- Title
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -12)
title:SetText("|cFF00CC66PickMe Messages|r")

-- Close button
local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -4, -4)
closeBtn:SetScript("OnClick", function() frame:Hide() end)

--------------------------------------------------------------
-- Scroll list (FauxScrollFrame)
--------------------------------------------------------------

local scrollFrame = CreateFrame("ScrollFrame", "PickMeMessageScrollFrame", frame, "FauxScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 8, -(HEADER_HEIGHT + 4))
scrollFrame:SetPoint("BOTTOMRIGHT", -28, FOOTER_HEIGHT + 8)

-- Empty state text
local emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
emptyText:SetPoint("CENTER", scrollFrame, "CENTER", 0, 0)
emptyText:SetTextColor(0.5, 0.5, 0.5)
emptyText:Hide()

--------------------------------------------------------------
-- Row creation
--------------------------------------------------------------

local rows = {}

local function CreateRow(index)
    local row = CreateFrame("Frame", nil, frame)
    row:SetSize(FRAME_WIDTH - 50, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))

    -- Player name
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameText:SetPoint("LEFT", 5, 0)
    row.nameText:SetWidth(90)
    row.nameText:SetJustifyH("LEFT")

    -- Dungeon name
    row.dungeonText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.dungeonText:SetPoint("LEFT", row.nameText, "RIGHT", 5, 0)
    row.dungeonText:SetWidth(130)
    row.dungeonText:SetJustifyH("LEFT")
    row.dungeonText:SetTextColor(0.9, 0.9, 0.9)

    -- Time
    row.timeText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.timeText:SetPoint("LEFT", row.dungeonText, "RIGHT", 5, 0)
    row.timeText:SetWidth(50)
    row.timeText:SetJustifyH("RIGHT")
    row.timeText:SetTextColor(0.6, 0.6, 0.6)

    -- Status
    row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.statusText:SetPoint("LEFT", row.timeText, "RIGHT", 8, 0)
    row.statusText:SetWidth(55)
    row.statusText:SetJustifyH("LEFT")

    -- Action button (X)
    row.actionBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.actionBtn:SetSize(22, 20)
    row.actionBtn:SetPoint("RIGHT", -2, 0)
    row.actionBtn:SetText("X")

    -- Hover highlight
    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.08)

    -- Tooltip
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        if self.tooltipName then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:AddLine(self.tooltipName, ACCENT.r, ACCENT.g, ACCENT.b)
            GameTooltip:AddLine(self.tooltipDungeon or "", 0.9, 0.9, 0.9)
            if self.tooltipTime then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(self.tooltipTime, 0.5, 0.5, 0.5)
            end
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return row
end

for i = 1, VISIBLE_ROWS do
    rows[i] = CreateRow(i)
end

--------------------------------------------------------------
-- Update list
--------------------------------------------------------------

local function UpdateList()
    if not frame:IsShown() then return end

    local items
    local isQueued = viewMode == "queued"

    if isQueued then
        items = PickMe:GetQueue()
    else
        items = PickMeDB and PickMeDB.history or {}
    end

    local numItems = #items
    local offset = FauxScrollFrame_GetOffset(scrollFrame)
    FauxScrollFrame_Update(scrollFrame, numItems, VISIBLE_ROWS, ROW_HEIGHT)

    -- Empty state
    if numItems == 0 then
        emptyText:SetText(isQueued and "No messages in queue" or "No whisper history")
        emptyText:Show()
    else
        emptyText:Hide()
    end

    for i = 1, VISIBLE_ROWS do
        local row = rows[i]
        local index = offset + i
        local entry = items[index]

        if entry then
            row.nameText:SetText(entry.name)
            row.nameText:SetTextColor(0.6, 0.8, 1.0)

            -- Truncate dungeon name
            local dungeon = entry.dungeon or ""
            if #dungeon > 20 then
                dungeon = dungeon:sub(1, 17) .. "..."
            end
            row.dungeonText:SetText(dungeon)

            -- Time
            if entry.time then
                row.timeText:SetText(FormatRelativeTime(entry.time))
            else
                row.timeText:SetText("")
            end

            -- Status
            if isQueued then
                row.statusText:SetText("Queued")
                row.statusText:SetTextColor(1, 0.82, 0)
            else
                row.statusText:SetText("Sent")
                row.statusText:SetTextColor(0, 1, 0.4)
            end

            -- Action button
            row.actionBtn:SetScript("OnClick", function()
                if isQueued then
                    PickMe:RemoveFromQueue(index)
                else
                    PickMe:RemoveFromHistory(index)
                end
                UpdateList()
                PickMe:UpdateMessageCounters()
            end)

            -- Tooltip data
            row.tooltipName = entry.name
            row.tooltipDungeon = entry.dungeon
            if entry.time then
                row.tooltipTime = date("%Y-%m-%d %H:%M:%S", entry.time)
            else
                row.tooltipTime = nil
            end

            row:Show()
        else
            row:Hide()
        end
    end
end

scrollFrame:SetScript("OnVerticalScroll", function(sf, offset)
    FauxScrollFrame_OnVerticalScroll(sf, offset, ROW_HEIGHT, UpdateList)
end)

--------------------------------------------------------------
-- Footer: tab counters + clear all
--------------------------------------------------------------

-- Clear All button (left side)
local clearAllBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
clearAllBtn:SetSize(70, 20)
clearAllBtn:SetPoint("BOTTOMLEFT", 12, 8)
clearAllBtn:SetText("Clear All")
clearAllBtn:SetScript("OnClick", function()
    if viewMode == "queued" then
        PickMe:ClearQueue()
    else
        PickMe:ClearHistory()
    end
    UpdateList()
    PickMe:UpdateMessageCounters()
    PlaySound(808)
end)

-- Queued tab (right side)
local queuedTab = CreateFrame("Button", nil, frame)
queuedTab:SetSize(80, 16)
queuedTab:SetPoint("BOTTOMRIGHT", -100, 12)
queuedTab.text = queuedTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
queuedTab.text:SetAllPoints()
queuedTab.text:SetJustifyH("RIGHT")
queuedTab:SetScript("OnClick", function()
    viewMode = "queued"
    UpdateList()
    PickMe:UpdateMessageCounters()
end)
queuedTab:SetScript("OnEnter", function(self)
    self.text:SetTextColor(1, 1, 1)
end)
queuedTab:SetScript("OnLeave", function()
    PickMe:UpdateMessageCounters()
end)

-- Separator
local sep = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sep:SetPoint("LEFT", queuedTab, "RIGHT", 4, 0)
sep:SetText("|")
sep:SetTextColor(0.5, 0.5, 0.5)

-- History tab
local historyTab = CreateFrame("Button", nil, frame)
historyTab:SetSize(80, 16)
historyTab:SetPoint("LEFT", sep, "RIGHT", 4, 0)
historyTab.text = historyTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
historyTab.text:SetAllPoints()
historyTab.text:SetJustifyH("LEFT")
historyTab:SetScript("OnClick", function()
    viewMode = "history"
    UpdateList()
    PickMe:UpdateMessageCounters()
end)
historyTab:SetScript("OnEnter", function(self)
    self.text:SetTextColor(1, 1, 1)
end)
historyTab:SetScript("OnLeave", function()
    PickMe:UpdateMessageCounters()
end)

--------------------------------------------------------------
-- Counter update
--------------------------------------------------------------

function PickMe:UpdateMessageCounters()
    local queueCount = PickMe:GetQueueCount()
    local historyCount = PickMe:GetHistoryCount()

    queuedTab.text:SetText(queueCount .. " Queued")
    historyTab.text:SetText(historyCount .. " History")

    if viewMode == "queued" then
        queuedTab.text:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b)
        historyTab.text:SetTextColor(0.5, 0.5, 0.5)
    else
        queuedTab.text:SetTextColor(0.5, 0.5, 0.5)
        historyTab.text:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b)
    end
end

--------------------------------------------------------------
-- Auto-refresh (1 second interval)
--------------------------------------------------------------

frame:SetScript("OnShow", function()
    UpdateList()
    PickMe:UpdateMessageCounters()
end)

frame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed >= 1 then
        self.elapsed = 0
        if self:IsShown() then
            UpdateList()
            PickMe:UpdateMessageCounters()
        end
    end
end)

--------------------------------------------------------------
-- Public API
--------------------------------------------------------------

function PickMe:ToggleMessageFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

function PickMe:ShowMessageFrame()
    frame:Show()
end
