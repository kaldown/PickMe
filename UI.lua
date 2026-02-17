local _, PickMe = ...

-- Old config panel removed. All UI is now in MessageLog.lua (unified window).
-- This file is kept for load order compatibility.

if not PickMe.ToggleFrame then
    function PickMe:ToggleFrame()
        if PickMe.ToggleMainFrame then
            PickMe:ToggleMainFrame()
        end
    end
end
