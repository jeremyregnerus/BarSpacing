
-- BarSpacing - World of Warcraft: Forever
-- Version 0.5.0
-- QWERTY action bar layout with optional Shaman totem flyouts.

local listener = CreateFrame("Frame")
local pending = false
local scheduled = false

-------------------------------------------
-- SETTINGS
-------------------------------------------

local ENABLE_SHAMAN_TOTEMS = true

-- Main totem button size relative to normal action buttons.
local TOTEM_BUTTON_SCALE = 1.0

-- Scale for the expanded totem selection flyout.
local TOTEM_FLYOUT_SCALE = 1.2

-- Scale for the small button that opens the flyout.
local TOTEM_ARROW_SCALE = 1.2

local _, playerClass = UnitClass("player")
local isShaman = playerClass == "SHAMAN" and ENABLE_SHAMAN_TOTEMS

-------------------------------------------
-- BLIZZARD ACTION BARS
-------------------------------------------

local BAR = {
    [1] = "ActionButton",
    [2] = "MultiBarBottomLeftButton",
    [3] = "MultiBarBottomRightButton",
    [4] = "MultiBarRightButton",
}

local function Button(bar, index)
    return _G[BAR[bar] .. index]
end

local function Print(message)
    print("|cff64c8ffBarSpacing:|r " .. message)
end

local function InEditMode()
    return EditModeManagerFrame
        and EditModeManagerFrame.IsEditModeActive
        and EditModeManagerFrame:IsEditModeActive()
end

-- Control mouse interaction with Blizzard's MainActionBar frame.
local function SetMainActionBarMouse(enabled)
    if InCombatLockdown() or not MainActionBar then
        return
    end

    MainActionBar:SetMouseClickEnabled(enabled)
    MainActionBar:SetMouseMotionEnabled(enabled)
end

-- Move a frame relative to another frame.
-- Blizzard action buttons use parent containers, so move
-- the container and leave the actual button centered inside it.
local function Move(target, point, relative, relativePoint, x, y)
    local frame = target.container or target

    if frame ~= target then
        target:ClearAllPoints()
        target:SetPoint("CENTER", frame, "CENTER", 0, 0)
    end

    frame:ClearAllPoints()
    frame:SetPoint(point, relative, relativePoint, x, y)
end

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

local function ButtonsAvailable()
    for bar = 1, 4 do
        for index = 1, 12 do
            if not Button(bar, index) then
                Print("Missing Bar " .. bar .. " Button " .. index)
                return false
            end
        end
    end

    return true
end

-------------------------------------------
-- SHAMAN TOTEM SUPPORT
-------------------------------------------

-- F1-F4 correspond to Bar 2, Buttons 9-12.
-- F5-F8 remain ordinary action buttons.

local function FButton(position)
    if position <= 4 then
        return Button(2, position + 8)
    end

    return Button(4, position + 4)
end

local bindingOwner = isShaman
    and CreateFrame("Frame", "BarSpacingBindingOwner", UIParent)
    or nil

local replacedButtons = {}

-- Restore an ordinary action button.
local function RestoreFButton(position)
    if not replacedButtons[position] then return end

    local original = FButton(position)

    if original then
        original:SetAlpha(1)
        original:EnableMouse(true)
    end

    replacedButtons[position] = nil
end

local function RestoreShamanButtons()
    for position = 1, 4 do
        RestoreFButton(position)
    end

    if bindingOwner then
        ClearOverrideBindings(bindingOwner)
    end
end

-- Scale a native button to match a regular action button.
local function MatchSize(nativeButton, referenceButton)
    local nativeWidth = nativeButton:GetWidth()
    local referenceWidth = referenceButton:GetWidth()

    if not nativeWidth or nativeWidth <= 0
        or not referenceWidth or referenceWidth <= 0 then
        return
    end

    local currentSize = nativeWidth * nativeButton:GetEffectiveScale()

    local targetSize = referenceWidth
        * referenceButton:GetEffectiveScale()
        * TOTEM_BUTTON_SCALE

    if currentSize > 0 then
        local ratio = targetSize / currentSize

        if math.abs(ratio - 1) > 0.01 then
            nativeButton:SetScale(nativeButton:GetScale() * ratio)
        end
    end
end

-- Identify which totem preset page is active.
local function CurrentTotemPage()
    local bar = _G.MultiCastActionBarFrame
    local page = bar and bar.currentPage

    if page == nil
        or (issecretvalue and issecretvalue(page)) then
        return 1
    end

    if type(page) ~= "number" or page < 1 or page > 3 then
        return 1
    end

    return page
end

-- Restore the original F-key binding on each native totem slot.
local function BindTotemButton(position)
    local bindingAction = "MULTIACTIONBAR1BUTTON" .. (position + 8)

    local page = CurrentTotemPage()
    local nativeButtonName = "MultiCastActionButton"
        .. ((page - 1) * 4 + position)

    if not _G[nativeButtonName] then return end

    local key1, key2 = GetBindingKey(bindingAction)

    if not key1 and not key2 then
        key1 = "F" .. position
    end

    if key1 then
        SetOverrideBindingClick(
            bindingOwner, true, key1,
            nativeButtonName, "LeftButton"
        )
    end

    if key2 and key2 ~= key1 then
        SetOverrideBindingClick(
            bindingOwner, true, key2,
            nativeButtonName, "LeftButton"
        )
    end
end

-- Resize the native flyout menu and its opening button.
local function ResizeTotemFlyouts()
    local flyout = _G.MultiCastFlyoutFrame

    if flyout then
        flyout:SetScale(TOTEM_FLYOUT_SCALE)
    end

    local arrow = _G.MultiCastFlyoutFrameOpenButton

    if arrow then
        arrow:SetScale(TOTEM_ARROW_SCALE)
    end
end

-- Position the native elemental totem controls at F1-F4.
local function ApplyShamanTotems()
    if not isShaman then return end

    local bar = _G.MultiCastActionBarFrame

    if not bar or not bar:IsShown() then
        RestoreShamanButtons()
        return
    end

    ClearOverrideBindings(bindingOwner)

    for position = 1, 4 do
        local reference = FButton(position)
        local slot = _G["MultiCastSlotButton" .. position]

        if slot and slot:IsShown() then

            Move(slot, "CENTER", reference, "CENTER", 0, 0)
            MatchSize(slot, reference)

            -- Align all three totem preset pages.
            for page = 1, 3 do
                local actionIndex = (page - 1) * 4 + position

                local actionButton =
                    _G["MultiCastActionButton" .. actionIndex]

                if actionButton then
                    Move(
                        actionButton,
                        "CENTER",
                        reference,
                        "CENTER",
                        0,
                        0
                    )

                    MatchSize(actionButton, reference)
                end
            end

            -- Hide the ordinary F-key action button.
            -- Keep its position as a reference.
            if not replacedButtons[position] then
                reference:SetAlpha(0)
                reference:EnableMouse(false)
                replacedButtons[position] = true
            end

            BindTotemButton(position)
        else
            RestoreFButton(position)
        end
    end

    ResizeTotemFlyouts()
end

-------------------------------------------
-- MAIN QWERTY LAYOUT
-------------------------------------------

local function Apply()
    if InCombatLockdown() or InEditMode() then
        pending = true
        return
    end

    if not ButtonsAvailable() then return end

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
    local stagger = width / 2 + padding

    -------------------------------------------
    -- ACTION BAR 1
    -------------------------------------------

    -- Number row.
    FollowRange(1, 2, 7, padding)

    -- Q row.
    Move(Button(1, 8), "TOPLEFT", Button(1, 2), "BOTTOMLEFT", stagger, -padding)
    FollowRange(1, 9, 9, padding)

    -- Gap before R.
    Move(Button(1, 10), "LEFT", Button(1, 9), "RIGHT", step, 0)
    FollowRange(1, 11, 12, padding)

    -------------------------------------------
    -- ACTION BAR 2
    -------------------------------------------

    -- A row.
    Move(Button(2, 1), "TOPLEFT", Button(1, 8), "BOTTOMLEFT", stagger, -padding)
    Move(Button(2, 2), "LEFT", Button(2, 1), "RIGHT", step * 3, 0)
    FollowRange(2, 3, 3, padding)

    -- Z row.
    Move(Button(2, 4), "TOPLEFT", Button(2, 1), "BOTTOMLEFT", stagger, -padding)
    FollowRange(2, 5, 8, padding)

    -- F1-F4.
    Move(Button(2, 9), "BOTTOMLEFT", Button(1, 2), "TOPLEFT", stagger, padding)
    FollowRange(2, 10, 12, padding)

    -------------------------------------------
    -- ACTION BAR 3
    -------------------------------------------

    -- Shift number row.
    Move(Button(3, 1), "LEFT", Button(1, 7), "RIGHT", step, 0)
    FollowRange(3, 2, 6, padding)

    -- Shift Q row.
    Move(Button(3, 7), "TOPLEFT", Button(3, 1), "BOTTOMLEFT", stagger, -padding)
    FollowRange(3, 8, 8, padding)

    -- Gap before Shift R.
    Move(Button(3, 9), "LEFT", Button(3, 8), "RIGHT", step, 0)
    FollowRange(3, 10, 12, padding)

    -------------------------------------------
    -- ACTION BAR 4
    -------------------------------------------

    -- Shift A row.
    Move(Button(4, 1), "TOPLEFT", Button(3, 7), "BOTTOMLEFT", stagger, -padding)
    Move(Button(4, 2), "LEFT", Button(4, 1), "RIGHT", step * 3, 0)
    FollowRange(4, 3, 3, padding)

    -- Shift Z row.
    Move(Button(4, 4), "TOPLEFT", Button(4, 1), "BOTTOMLEFT", stagger, -padding)
    FollowRange(4, 5, 8, padding)

    -- F5-F8.
    -- Leave a full button-width gap between F4 and F5.
    Move(
        Button(4, 9),
        "LEFT",
        Button(2, 12),
        "RIGHT",
        step,
        0
    )

    FollowRange(4, 10, 12, padding)

    -------------------------------------------
    -- SHAMAN TOTEMS
    -------------------------------------------

    ApplyShamanTotems()

    -- Prevent MainActionBar from intercepting mouse
    -- interaction with our repositioned buttons.
    SetMainActionBarMouse(false)

    -- Action Bar 5 remains Blizzard-controlled.
    pending = false
end

-------------------------------------------
-- EVENTS AND COMMANDS
-------------------------------------------

local function ScheduleApply()
    if scheduled then return end

    scheduled = true

    C_Timer.After(0.5, function()
        scheduled = false
        Apply()
    end)
end

local hookedTotemUpdates = false

local function HookTotemUpdates()
    if not isShaman or hookedTotemUpdates then return end

    if type(MultiCastActionBarFrame_Update) == "function" then
        hooksecurefunc("MultiCastActionBarFrame_Update", ScheduleApply)
        hookedTotemUpdates = true
    end
end

listener:RegisterEvent("PLAYER_ENTERING_WORLD")
listener:RegisterEvent("PLAYER_REGEN_ENABLED")

if isShaman then
    listener:RegisterEvent("SPELLS_CHANGED")
    listener:RegisterEvent("UPDATE_MULTI_CAST_ACTIONBAR")
end

listener:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        HookTotemUpdates()
        C_Timer.After(2, Apply)

    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending or isShaman then
            ScheduleApply()
        end

    elseif isShaman then
        HookTotemUpdates()
        ScheduleApply()
    end
end)

SLASH_BARSPACING1 = "/barspacing"
SLASH_BARSPACING2 = "/bs"

SlashCmdList.BARSPACING = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    if msg == "" or msg == "apply" or msg == "refresh" then
        Apply()

        if pending then
            Print("Will apply after combat or Edit Mode.")
        else
            Print("Layout applied.")
        end
    else
        Print("Usage: /bs apply")
    end
end

if EventRegistry and EventRegistry.RegisterCallback then

    -- Restore normal mouse interaction when entering Edit Mode.
    EventRegistry:RegisterCallback("EditMode.Enter", function()
        SetMainActionBarMouse(true)
    end, listener)

    -- Reapply our layout and mouse settings after Edit Mode.
    EventRegistry:RegisterCallback("EditMode.Exit", ScheduleApply, listener)

end