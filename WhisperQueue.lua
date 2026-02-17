local _, PickMe = ...

--------------------------------------------------------------
-- Template substitution
--------------------------------------------------------------

local TEMPLATE_VARS = {
    leader  = true,
    dungeon = true,
    role    = true,
    class   = true,
    level   = true,
}

function PickMe:GetTemplateVarList()
    local vars = {}
    for k in pairs(TEMPLATE_VARS) do
        vars[#vars + 1] = k
    end
    table.sort(vars)
    return vars
end

local function GetPlayerRole()
    -- GetTalentGroupRole exists but throws "API unsupported" on Classic Anniversary
    local ok, role = pcall(function()
        if GetTalentGroupRole then return GetTalentGroupRole() end
    end)
    if ok and role and role ~= "NONE" then
        if role == "DAMAGER" then return "DPS" end
        return role:sub(1, 1) .. role:sub(2):lower() -- Tank, Healer
    end
    -- Fallback: check role from LFG if available
    if GetLFGRoles then
        local ok2, leader, tank, healer, dps = pcall(GetLFGRoles)
        if ok2 then
            if tank then return "Tank" end
            if healer then return "Healer" end
        end
    end
    return "DPS"
end

local function SubstituteTemplate(template, target)
    local _, englishClass = UnitClass("player")
    local displayClass = englishClass and (englishClass:sub(1, 1) .. englishClass:sub(2):lower()) or "Unknown"

    local vars = {
        leader  = target.name or "",
        dungeon = target.dungeon or "",
        role    = GetPlayerRole(),
        class   = displayClass,
        level   = tostring(UnitLevel("player")),
    }
    return (template:gsub("{(%w+)}", function(key)
        return vars[key] or ("{" .. key .. "}")
    end))
end

--------------------------------------------------------------
-- Queue state
--------------------------------------------------------------

local whisperQueue = {}
local queueTicker = nil
local HISTORY_CAP = 100

local function IsInHistory(name)
    if not PickMeDB or not PickMeDB.history then return false end
    for _, entry in ipairs(PickMeDB.history) do
        if entry.name == name then return true end
    end
    return false
end

function PickMe:FindInHistory(name)
    if not PickMeDB or not PickMeDB.history then return nil end
    for _, entry in ipairs(PickMeDB.history) do
        if entry.name == name then return entry end
    end
    return nil
end

function PickMe:ClearHistoryEntry(name)
    if not PickMeDB or not PickMeDB.history then return end
    for i = #PickMeDB.history, 1, -1 do
        if PickMeDB.history[i].name == name then
            table.remove(PickMeDB.history, i)
            return true
        end
    end
    return false
end

local function AddToHistory(name, dungeon)
    if not PickMeDB then return end
    PickMeDB.history = PickMeDB.history or {}
    table.insert(PickMeDB.history, { name = name, dungeon = dungeon, time = time() })
    -- Trim oldest if over cap
    while #PickMeDB.history > HISTORY_CAP do
        table.remove(PickMeDB.history, 1)
    end
end

--------------------------------------------------------------
-- Cooldown auto-clean
--------------------------------------------------------------

local function SweepExpiredHistory()
    if not PickMeDB or not PickMeDB.history then return end
    local cooldownSec = (PickMeDB.settings and PickMeDB.settings.cooldownHours or 4) * 3600
    local now = time()
    local i = 1
    while i <= #PickMeDB.history do
        if now - (PickMeDB.history[i].time or 0) > cooldownSec then
            table.remove(PickMeDB.history, i)
        else
            i = i + 1
        end
    end
end

--------------------------------------------------------------
-- Manual send (per-recipient button click)
--------------------------------------------------------------

local lastManualSendTime = 0  -- GetTime() float

function PickMe:SendWhisper(name, dungeon, mode)
    if IsInHistory(name) then
        self:Print(name .. " already whispered (cooldown active).")
        return false
    end

    local template = PickMeDB.modes[mode] and PickMeDB.modes[mode].template
        or PickMeDB.modes.groups.template
    local msg = SubstituteTemplate(template, { name = name, dungeon = dungeon })
    SendChatMessage(msg, "WHISPER", nil, name)
    AddToHistory(name, dungeon)
    lastManualSendTime = GetTime()

    self:Print("Whispered " .. name .. " (" .. dungeon .. ")")
    return true
end

function PickMe:GetLastSendTime()
    return lastManualSendTime
end

function PickMe:IsThrottled()
    local delay = PickMeDB.settings and PickMeDB.settings.whisperDelay or 3
    return (GetTime() - lastManualSendTime) < delay
end

function PickMe:GetThrottleRemaining()
    local delay = PickMeDB.settings and PickMeDB.settings.whisperDelay or 3
    local elapsed = GetTime() - lastManualSendTime
    if elapsed >= delay then return 0 end
    return delay - elapsed
end

function PickMe:GetQueueCount()
    return #whisperQueue
end

--------------------------------------------------------------
-- Queue processing
--------------------------------------------------------------

local function ProcessQueue()
    if #whisperQueue == 0 then
        if queueTicker then
            queueTicker:Cancel()
            queueTicker = nil
        end
        return
    end

    local target = table.remove(whisperQueue, 1)

    -- Final dedup check (might have been whispered while in queue)
    if IsInHistory(target.name) then return end

    local msg = SubstituteTemplate(PickMeDB.modes.groups.template, target)
    SendChatMessage(msg, "WHISPER", nil, target.name)
    AddToHistory(target.name, target.dungeon)

    PickMe:Print("Whispered " .. target.name .. " (" .. target.dungeon .. ")")

    -- Stop ticker if queue drained
    if #whisperQueue == 0 and queueTicker then
        queueTicker:Cancel()
        queueTicker = nil
    end
end

--------------------------------------------------------------
-- Public API
--------------------------------------------------------------

function PickMe:Enqueue(name, dungeon)
    -- Dedup: already whispered or already in queue
    if IsInHistory(name) then return false end
    for _, entry in ipairs(whisperQueue) do
        if entry.name == name then return false end
    end

    whisperQueue[#whisperQueue + 1] = { name = name, dungeon = dungeon }

    -- Start ticker if not running
    if not queueTicker then
        local delay = (PickMeDB and PickMeDB.settings and PickMeDB.settings.whisperDelay) or 3
        queueTicker = C_Timer.NewTicker(delay, ProcessQueue)
    end

    return true
end

function PickMe:StopQueue()
    if queueTicker then
        queueTicker:Cancel()
        queueTicker = nil
    end
    -- Keep queue contents - they'll be processed on resume
end

function PickMe:ClearQueue()
    whisperQueue = {}
    if queueTicker then
        queueTicker:Cancel()
        queueTicker = nil
    end
end

function PickMe:GetQueue()
    return whisperQueue
end

function PickMe:RemoveFromQueue(index)
    if index >= 1 and index <= #whisperQueue then
        table.remove(whisperQueue, index)
    end
    -- Stop ticker if queue drained
    if #whisperQueue == 0 and queueTicker then
        queueTicker:Cancel()
        queueTicker = nil
    end
end

function PickMe:GetHistoryCount()
    if not PickMeDB or not PickMeDB.history then return 0 end
    return #PickMeDB.history
end

function PickMe:RemoveFromHistory(index)
    if PickMeDB and PickMeDB.history and index >= 1 and index <= #PickMeDB.history then
        table.remove(PickMeDB.history, index)
    end
end

function PickMe:ClearHistory()
    if PickMeDB then
        PickMeDB.history = {}
    end
    self:Print("Whisper history cleared.")
end

function PickMe:SweepExpiredHistory()
    SweepExpiredHistory()
end
