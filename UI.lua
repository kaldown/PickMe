local _, PickMe = ...

--------------------------------------------------------------
-- Constants
--------------------------------------------------------------

local PANEL_WIDTH = 340
local PANEL_HEIGHT = 310
local ACCENT = { r = 0, g = 0.8, b = 0.4 }

--------------------------------------------------------------
-- Main frame
--------------------------------------------------------------

local mainFrame = CreateFrame("Frame", "PickMeMainFrame", UIParent, "BackdropTemplate")
mainFrame:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
mainFrame:SetPoint("CENTER")
mainFrame:SetFrameStrata("DIALOG")
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
mainFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
})
mainFrame:Hide()
table.insert(UISpecialFrames, "PickMeMainFrame")

-- Title
local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("|cFF00CC66PickMe|r")

-- Close button
local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -4, -4)
closeBtn:SetScript("OnClick", function() mainFrame:Hide() end)

--------------------------------------------------------------
-- Toggle button (ON/OFF)
--------------------------------------------------------------

local yOffset = -44

local toggleBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
toggleBtn:SetSize(60, 22)
toggleBtn:SetPoint("TOPLEFT", 16, yOffset)

local function UpdateToggleBtn()
    if PickMeDB and PickMeDB.profile.enabled then
        toggleBtn:SetText("|cFF00FF00ON|r")
    else
        toggleBtn:SetText("|cFFFF0000OFF|r")
    end
end

toggleBtn:SetScript("OnClick", function()
    if PickMeDB.profile.enabled then
        PickMe:Disable()
    else
        PickMe:Enable()
    end
    UpdateToggleBtn()
    PlaySound(808)
end)

-- Pause button
local pauseBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
pauseBtn:SetSize(80, 22)
pauseBtn:SetPoint("LEFT", toggleBtn, "RIGHT", 8, 0)

local function UpdatePauseBtn()
    if PickMe.paused then
        pauseBtn:SetText("Resume")
    else
        pauseBtn:SetText("Pause")
    end
end

pauseBtn:SetScript("OnClick", function()
    if PickMe.paused then
        PickMe:Resume()
    else
        PickMe:Pause()
    end
    UpdatePauseBtn()
    PlaySound(808)
end)

--------------------------------------------------------------
-- Template editbox
--------------------------------------------------------------

yOffset = yOffset - 36

local templateLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
templateLabel:SetPoint("TOPLEFT", 16, yOffset)
templateLabel:SetText("Message template:")

yOffset = yOffset - 20

local templateBox = CreateFrame("EditBox", "PickMeTemplateBox", mainFrame, "InputBoxTemplate")
templateBox:SetPoint("TOPLEFT", 20, yOffset)
templateBox:SetSize(PANEL_WIDTH - 48, 20)
templateBox:SetAutoFocus(false)
templateBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
templateBox:SetScript("OnEnterPressed", function(self)
    PickMeDB.profile.template = self:GetText()
    self:ClearFocus()
    PickMe:Print("Template saved.")
    PlaySound(808)
end)
templateBox:SetScript("OnEditFocusLost", function(self)
    PickMeDB.profile.template = self:GetText()
end)

-- Legend
yOffset = yOffset - 22

local legendLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
legendLabel:SetPoint("TOPLEFT", 16, yOffset)
legendLabel:SetTextColor(0.5, 0.5, 0.5)
legendLabel:SetText("Variables: {leader} {dungeon} {role} {class} {level}")

--------------------------------------------------------------
-- Target mode (radio buttons)
--------------------------------------------------------------

yOffset = yOffset - 28

local targetLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
targetLabel:SetPoint("TOPLEFT", 16, yOffset)
targetLabel:SetText("Target:")

local groupsRadio = CreateFrame("CheckButton", "PickMeRadioGroups", mainFrame, "UIRadioButtonTemplate")
groupsRadio:SetPoint("LEFT", targetLabel, "RIGHT", 8, 0)

local groupsText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
groupsText:SetPoint("LEFT", groupsRadio, "RIGHT", 2, 0)
groupsText:SetText("Group leaders only")

local allRadio = CreateFrame("CheckButton", "PickMeRadioAll", mainFrame, "UIRadioButtonTemplate")
allRadio:SetPoint("LEFT", groupsText, "RIGHT", 12, 0)

local allText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
allText:SetPoint("LEFT", allRadio, "RIGHT", 2, 0)
allText:SetText("Everyone")

local function UpdateRadios()
    if PickMeDB and PickMeDB.profile.targetMode == "groups" then
        groupsRadio:SetChecked(true)
        allRadio:SetChecked(false)
    else
        groupsRadio:SetChecked(false)
        allRadio:SetChecked(true)
    end
end

groupsRadio:SetScript("OnClick", function()
    PickMeDB.profile.targetMode = "groups"
    UpdateRadios()
    PlaySound(808)
end)

allRadio:SetScript("OnClick", function()
    PickMeDB.profile.targetMode = "all"
    UpdateRadios()
    PlaySound(808)
end)

--------------------------------------------------------------
-- Whisper delay
--------------------------------------------------------------

yOffset = yOffset - 30

local delayLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
delayLabel:SetPoint("TOPLEFT", 16, yOffset)
delayLabel:SetText("Whisper delay:")

local delayBox = CreateFrame("EditBox", "PickMeDelayBox", mainFrame, "InputBoxTemplate")
delayBox:SetPoint("LEFT", delayLabel, "RIGHT", 8, 0)
delayBox:SetSize(30, 20)
delayBox:SetAutoFocus(false)
delayBox:SetNumeric(true)
delayBox:SetMaxLetters(2)
delayBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
delayBox:SetScript("OnEnterPressed", function(self)
    local val = tonumber(self:GetText()) or 3
    if val < 1 then val = 1 end
    if val > 30 then val = 30 end
    PickMeDB.profile.whisperDelay = val
    self:SetText(tostring(val))
    self:ClearFocus()
    PlaySound(808)
end)
delayBox:SetScript("OnEditFocusLost", function(self)
    local val = tonumber(self:GetText()) or 3
    if val < 1 then val = 1 end
    if val > 30 then val = 30 end
    PickMeDB.profile.whisperDelay = val
    self:SetText(tostring(val))
end)

local secLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
secLabel:SetPoint("LEFT", delayBox, "RIGHT", 4, 0)
secLabel:SetText("seconds")

--------------------------------------------------------------
-- Stats display
--------------------------------------------------------------

yOffset = yOffset - 36

local statsLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statsLabel:SetPoint("TOPLEFT", 16, yOffset)
statsLabel:SetText("Stats:")

local statsValue = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
statsValue:SetPoint("LEFT", statsLabel, "RIGHT", 8, 0)

local function UpdateStats()
    local whispered = 0
    if PickMeDB and PickMeDB.whispered then
        for _ in pairs(PickMeDB.whispered) do whispered = whispered + 1 end
    end
    local queued = PickMe.GetQueueCount and PickMe:GetQueueCount() or 0
    statsValue:SetText(whispered .. " whispered | " .. queued .. " queued")
end

--------------------------------------------------------------
-- Clear history button
--------------------------------------------------------------

yOffset = yOffset - 30

local clearBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
clearBtn:SetSize(110, 22)
clearBtn:SetPoint("TOPLEFT", 16, yOffset)
clearBtn:SetText("Clear History")
clearBtn:SetScript("OnClick", function()
    PickMe:ClearHistory()
    UpdateStats()
    PlaySound(808)
end)

--------------------------------------------------------------
-- OnShow: populate from SavedVariables
--------------------------------------------------------------

mainFrame:SetScript("OnShow", function()
    if PickMeDB and PickMeDB.profile then
        templateBox:SetText(PickMeDB.profile.template or "")
        delayBox:SetText(tostring(PickMeDB.profile.whisperDelay or 3))
        UpdateToggleBtn()
        UpdatePauseBtn()
        UpdateRadios()
        UpdateStats()
    end
end)

mainFrame:SetScript("OnHide", function()
    templateBox:ClearFocus()
    delayBox:ClearFocus()
end)

-- Periodic stats refresh while visible
mainFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed >= 1 then
        self.elapsed = 0
        if self:IsShown() then
            UpdateStats()
            UpdateToggleBtn()
            UpdatePauseBtn()
        end
    end
end)

--------------------------------------------------------------
-- Public API
--------------------------------------------------------------

function PickMe:ToggleFrame()
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
    end
end
