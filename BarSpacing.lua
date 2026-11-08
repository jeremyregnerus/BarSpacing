
-- BarSpacing - World of Warcraft: Forever
-- Version 0.3.0
-- Arranges Blizzard action buttons in a QWERTY keyboard layout.

local addonName = ...
local listener = CreateFrame("Frame")
local pending = false
local scheduled = false

-- Blizzard action bar button names.
local BAR = {
    [1] = "ActionButton",
    [2] = "MultiBarBottomLeftButton",
    [3] = "MultiBarBottomRightButton",
    [4] = "MultiBarRightButton",
}

-- Returns a button using its bar and index.
local function Button(bar, index)
    return _G[BAR[bar] .. index]
end

local function InEditMode()
    return EditModeManagerFrame
        and EditModeManagerFrame.IsEditModeActive
        and EditModeManagerFrame:IsEditModeActive()
end

local function Print(message)
    print("|cff64c8ffBarSpacing:|r " .. message)
end

-- Moves a button relative to another button.
local function Move(target, point, relative, relativePoint, x, y)
    target:ClearAllPoints()
    target:SetPoint(point, relative, relativePoint, x, y)
end

-- Positions a series of buttons horizontally.
-- Each button is anchored to the previous button.
local function FollowRange(bar, first, last, padding)
    for index = first, last do
        Move(
            Button(bar, index),
            "LEFT",
            Button(bar, index - 1),
            "RIGHT",
            padding,
            0
        )
    end
end

-- Verify all required buttons exist.
local function ButtonsAvailable()
    for bar = 1, 4 do
        for index = 1, 12 do
            if not Button(bar, index) then
                Print("Missing button: Bar " .. bar .. ", Button " .. index)
                return false
            end
        end
    end
    return true
end

-- Apply the keyboard layout.
local function Apply()
    if InCombatLockdown() or InEditMode() then
        pending = true
        return
    end

    if not ButtonsAvailable() then
        return
    end

    -- Determine button dimensions and normal spacing.
    local a1, a2 = Button(1, 1), Button(1, 2)
    local width = a1:GetWidth()

    if not width or width <= 0 then
        Print("Button sizes are not ready yet.")
        return
    end

    local padding = 0

    if a1:GetLeft() and a2:GetLeft() then
        padding = a2:GetLeft() - a1:GetLeft() - width

        if padding < 0 or padding > width then
            padding = 0
        end
    end

    local step = width + padding
    local stagger = (width / 2) + padding

    -------------------------------------------
    -- ACTION BAR 1
    -------------------------------------------

    -- Number row: Buttons 1-7.
    -- Button 1 retains its original position.
    FollowRange(1, 2, 7, padding)

    -- Q row: Buttons 8-12.
    Move(Button(1, 8), "TOPLEFT", Button(1, 2), "BOTTOMLEFT", stagger, -padding)

    -- W follows Q.
    FollowRange(1, 9, 9, padding)

    -- Add a one-button gap before R.
    Move(Button(1, 10), "LEFT", Button(1, 9), "RIGHT", step, 0)

    -- Remaining buttons follow R.
    FollowRange(1, 11, 12, padding)


    -------------------------------------------
    -- ACTION BAR 2
    -------------------------------------------

    -- A row: Buttons 1-3.
    Move(Button(2, 1), "TOPLEFT", Button(1, 8), "BOTTOMLEFT", stagger, -padding)

    -- Add a three-button gap after A.
    Move(Button(2, 2), "LEFT", Button(2, 1), "RIGHT", step * 3, 0)

    FollowRange(2, 3, 3, padding)

    -- Z row: Buttons 4-8.
    Move(Button(2, 4), "TOPLEFT", Button(2, 1), "BOTTOMLEFT", stagger, -padding)

    FollowRange(2, 5, 8, padding)

    -- F1-F4: Buttons 9-12.
    Move(Button(2, 9), "BOTTOMLEFT", Button(1, 2), "TOPLEFT", stagger, padding)

    FollowRange(2, 10, 12, padding)


    -------------------------------------------
    -- ACTION BAR 3
    -------------------------------------------

    -- Shift number row: Buttons 1-6.
    Move(Button(3, 1), "LEFT", Button(1, 7), "RIGHT", step, 0)

    FollowRange(3, 2, 6, padding)

    -- Shift Q row: Buttons 7-11.
    Move(Button(3, 7), "TOPLEFT", Button(3, 1), "BOTTOMLEFT", stagger, -padding)

    FollowRange(3, 8, 8, padding)

    -- Add a one-button gap before Shift R.
    Move(Button(3, 9), "LEFT", Button(3, 8), "RIGHT", step, 0)

    FollowRange(3, 10, 12, padding)


    -------------------------------------------
    -- ACTION BAR 4
    -------------------------------------------

    -- Shift A row: Buttons 1-3.
    Move(Button(4, 1), "TOPLEFT", Button(3, 7), "BOTTOMLEFT", stagger, -padding)

    -- Add a three-button gap after Shift A.
    Move(Button(4, 2), "LEFT", Button(4, 1), "RIGHT", step * 3, 0)

    FollowRange(4, 3, 3, padding)

    -- Shift Z row: Buttons 4-8.
    Move(Button(4, 4), "TOPLEFT", Button(4, 1), "BOTTOMLEFT", stagger, -padding)

    FollowRange(4, 5, 8, padding)

    -- F5-F8: Buttons 9-12.
    Move(Button(4, 9), "BOTTOMLEFT", Button(1, 7), "TOPLEFT", stagger, padding)

    FollowRange(4, 10, 12, padding)

end

-- Schedule an update after Blizzard finishes arranging the UI.
local function ScheduleApply()
    if scheduled then return end

    scheduled = true

    C_Timer.After(0.5, function()
        scheduled = false
        Apply()
    end)
end

-- Register game events.
listener:RegisterEvent("PLAYER_ENTERING_WORLD")
listener:RegisterEvent("PLAYER_REGEN_ENABLED")

listener:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(2, Apply)

    elseif event == "PLAYER_REGEN_ENABLED" and pending then
        ScheduleApply()
    end
end)

-- Slash commands.
SLASH_BARSPACING1 = "/barspacing"
SLASH_BARSPACING2 = "/bs"

SlashCmdList.BARSPACING = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    if msg == "apply" or msg == "refresh" or msg == "" then
        Apply()

        if pending then
            Print("Will apply when you leave combat or Edit Mode.")
        else
            Print("QWERTY button layout applied.")
        end
    else
        Print("Usage: /barspacing apply (or /bs apply)")
    end
end

-- Reapply after closing Blizzard Edit Mode.
if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.Exit", ScheduleApply, listener)
end