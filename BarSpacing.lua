
-- BarSpacing - World of Warcraft: Forever
-- Version 0.11.0
-- QWERTY action bar layout with optional Shaman totem flyouts.

local listener = CreateFrame("Frame")
local pending = false
local scheduled = false

-------------------------------------------
-- SETTINGS
-------------------------------------------

local ENABLE_SHAMAN_TOTEMS = true

-- Display inherited F-key bindings on the native totem buttons.
local SHOW_TOTEM_KEYBINDS = true

-- Hide macro names while preserving keybinding labels.
local HIDE_MACRO_NAMES = true

-- Hide Blizzard's native Stance Bar.
local HIDE_STANCE_BAR = true

-- Main totem button size relative to normal action buttons.
local TOTEM_BUTTON_SCALE = 1.0

-- Scale for the expanded totem selection flyout.
local TOTEM_FLYOUT_SCALE = 1.2

-- Scale for the small button that opens the flyout.
local TOTEM_ARROW_SCALE = 1.2

local TOTEM_HOTKEY_OFFSET_X = 0
local TOTEM_HOTKEY_OFFSET_Y = 2

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
    [5] = "MultiBarLeftButton",
}

-- Number of buttons used from each managed action bar.
local BUTTON_COUNT = {
    [1] = 12,
    [2] = 12,
    [3] = 12,
    [4] = 7,
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

-------------------------------------------
-- STANCE BAR VISIBILITY
-------------------------------------------

local stanceBarDriverInstalled = false

local function ApplyStanceBarVisibility()
    if not HIDE_STANCE_BAR
        or stanceBarDriverInstalled
        or InCombatLockdown() then
        return
    end

    -- Modern Blizzard clients use StanceBar.
    -- The fallback supports older frame naming.
    local bar = _G.StanceBar or _G.StanceBarFrame

    if bar and RegisterStateDriver then
        RegisterStateDriver(bar, "visibility", "hide")
        stanceBarDriverInstalled = true
    end
end

-- Prevent MainActionBar from intercepting mouse events.
local function SetMainActionBarMouse(enabled)
    if InCombatLockdown() or not MainActionBar then
        return
    end

    MainActionBar:SetMouseClickEnabled(enabled)
    MainActionBar:SetMouseMotionEnabled(enabled)
end

-- Move the button container when one exists.
local function Move(target, point, relative, relativePoint, x, y)
    local frame = target.container or target

    if frame ~= target then
        target:ClearAllPoints()
        target:SetPoint("CENTER", frame, "CENTER", 0, 0)
    end

    frame:ClearAllPoints()
    frame:SetPoint(point, relative, relativePoint, x, y)
end

-- Anchor consecutive buttons to their predecessors.
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
        for index = 1, BUTTON_COUNT[bar] do
            if not Button(bar, index) then
                Print("Missing Bar " .. bar .. " Button " .. index)
                return false
            end
        end
    end

    return true
end

-------------------------------------------
-- MACRO NAME VISIBILITY
-------------------------------------------

-- Hide macro labels without affecting keybinding text.
-- Includes Action Bar 5, but does not modify its layout.
local function UpdateMacroNames()
    for bar = 1, 5 do
        for index = 1, 12 do
            local button = Button(bar, index)

            if button then
                local name = button.Name
                    or _G[button:GetName() .. "Name"]

                if name then
                    name:SetAlpha(HIDE_MACRO_NAMES and 0 or 1)
                end
            end
        end
    end
end

-------------------------------------------
-- SHAMAN TOTEM SUPPORT
-------------------------------------------

-- F1-F4 correspond to Bar 2, Buttons 9-12.
-- F5-F8 are regular action buttons on Bar 3.

local function FButton(position)
    return Button(2, position + 8)
end

local bindingOwner = isShaman
    and CreateFrame("Frame", "BarSpacingBindingOwner", UIParent)
    or nil

local replacedButtons = {}

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

-- Match the native totem button size to a standard action button.
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

-- Update the visible keybinding label on a native totem button.
-- The label matches the original action button's binding.
local function UpdateTotemHotkey(button)
    if not isShaman or not SHOW_TOTEM_KEYBINDS
        or InCombatLockdown() or not button then
        return
    end

    local buttonName = button:GetName()
    if not buttonName then return end

    -- Identify the totem action button (1-12).
    local actionIndex = tonumber(
        buttonName:match("^MultiCastActionButton(%d+)$")
    )

    if not actionIndex or actionIndex < 1 or actionIndex > 12 then
        return
    end

    -- Each Call page contains the same four elemental positions.
    local position = ((actionIndex - 1) % 4) + 1

    local bindingAction =
        "MULTIACTIONBAR1BUTTON" .. (position + 8)

    -- Use the actual binding, with F1-F4 as a fallback.
    local key = GetBindingKey(bindingAction) or ("F" .. position)

    local text = GetBindingText(key, 1)
    if not text or text == "" then
        text = key
    end

    local hotkey = button.HotKey
        or _G[buttonName .. "HotKey"]

    
	if hotkey then
		-- Get the original action button's keybinding text.
		local reference = FButton(position)

		local referenceHotkey = reference.HotKey
			or _G[reference:GetName() .. "HotKey"]

		if referenceHotkey then
			-- Copy the font, size, and outline.
			local font, size, flags = referenceHotkey:GetFont()

			-- Compensate for the different frame scales.
			local referenceScale = referenceHotkey:GetEffectiveScale()
			local totemScale = hotkey:GetEffectiveScale()

			if font and size and totemScale > 0 then
				local adjustedSize = size * referenceScale / totemScale

				hotkey:SetFont(font, adjustedSize, flags)
			end

			-- Match the original keybinding text color.
			hotkey:SetTextColor(referenceHotkey:GetTextColor())
			
			-- Match the original keybinding label's position.
			hotkey:ClearAllPoints()
			hotkey:SetPoint("TOPRIGHT", referenceHotkey, "TOPRIGHT", TOTEM_HOTKEY_OFFSET_X, TOTEM_HOTKEY_OFFSET_Y)

			-- Match the original text alignment.
			hotkey:SetJustifyH(referenceHotkey:GetJustifyH())
		end

		-- Display the inherited keybinding.
		hotkey:SetText(text)
		hotkey:Show()
	end
end

-- Update the labels for all three possible totem pages.
local function UpdateAllTotemHotkeys()
    if not SHOW_TOTEM_KEYBINDS then return end

    for index = 1, 12 do
        UpdateTotemHotkey(
            _G["MultiCastActionButton" .. index]
        )
    end
end

-- Redirect F1-F4 bindings to the native Shaman totem buttons.
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

            -- Position the action buttons for all three totem pages.
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

            -- Hide the original F-key button but retain its anchor.
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

    -- Display F-key labels after installing the bindings.
    UpdateAllTotemHotkeys()
end

-------------------------------------------
-- MAIN QWERTY LAYOUT
-------------------------------------------

local function Apply()
    if InCombatLockdown() or InEditMode() then
        pending = true
        return
    end

    -- Hide Blizzard's Stance Bar if enabled.
    ApplyStanceBarVisibility()

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
    -- Primary number and Q row
    -------------------------------------------

    -- Number row: Buttons 1-7.
    FollowRange(1, 2, 7, padding)

    -- Q row: Buttons 8-12.
    Move(Button(1, 8), "TOPLEFT", Button(1, 2), "BOTTOMLEFT", stagger, -padding)
    FollowRange(1, 9, 9, padding)

    -- Gap before R.
    Move(Button(1, 10), "LEFT", Button(1, 9), "RIGHT", step, 0)
    FollowRange(1, 11, 12, padding)

    -------------------------------------------
    -- ACTION BAR 2
    -- Primary A and Z rows, plus F1-F4
    -------------------------------------------

    -- A row: Buttons 1-3.
    Move(Button(2, 1), "TOPLEFT", Button(1, 8), "BOTTOMLEFT", stagger, -padding)
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
    -- F5-F8, Shift number row, Shift Q row
    -------------------------------------------

    -- F5-F8: Buttons 1-4.
    Move(
        Button(3, 1),
        "LEFT",
        Button(2, 12),
        "RIGHT",
        step,
        0
    )

    FollowRange(3, 2, 4, padding)

    -- Shift number row: Buttons 5-9.
    Move(
        Button(3, 5),
        "LEFT",
        Button(1, 7),
        "RIGHT",
        step,
        0
    )

    FollowRange(3, 6, 9, padding)

    -- Shift Q row: Buttons 10-12.
    -- Shift+Q, Shift+W, Shift+R.
    Move(
        Button(3, 10),
        "TOPLEFT",
        Button(3, 5),
        "BOTTOMLEFT",
        stagger,
        -padding
    )

    FollowRange(3, 11, 11, padding)

    -- Gap before Shift+R.
    Move(
        Button(3, 12),
        "LEFT",
        Button(3, 11),
        "RIGHT",
        step,
        0
    )

    -------------------------------------------
    -- ACTION BAR 4
    -- Shift T, A, G, Z, X, C, V
    -------------------------------------------

    -- Shift+T: Button 1.
    Move(
        Button(4, 1),
        "LEFT",
        Button(3, 12),
        "RIGHT",
        padding,
        0
    )

    -- Shift+A and Shift+G: Buttons 2-3.
    Move(
        Button(4, 2),
        "TOPLEFT",
        Button(3, 10),
        "BOTTOMLEFT",
        stagger,
        -padding
    )

    Move(
        Button(4, 3),
        "LEFT",
        Button(4, 2),
        "RIGHT",
        step * 3,
        0
    )

    -- Shift+Z through Shift+V: Buttons 4-7.
    Move(
        Button(4, 4),
        "TOPLEFT",
        Button(4, 2),
        "BOTTOMLEFT",
        stagger,
        -padding
    )

    FollowRange(4, 5, 7, padding)

    -- Buttons 8-12 are reserved for future use.

    -------------------------------------------
    -- SHAMAN TOTEMS
    -------------------------------------------

    ApplyShamanTotems()

    -------------------------------------------
    -- MACRO LABELS
    -------------------------------------------

    UpdateMacroNames()

    -- Prevent MainActionBar from intercepting mouse events.
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
local hookedHotkeyUpdates = false

local function HookTotemUpdates()
    if not isShaman then return end

    if not hookedTotemUpdates
        and type(MultiCastActionBarFrame_Update) == "function" then

        hooksecurefunc("MultiCastActionBarFrame_Update", ScheduleApply)
        hookedTotemUpdates = true
    end

    -- Blizzard may refresh the native hotkey labels.
    -- Reapply our inherited labels after those updates.
    if SHOW_TOTEM_KEYBINDS
        and not hookedHotkeyUpdates
        and type(ActionButton_UpdateHotkeys) == "function" then

        hooksecurefunc("ActionButton_UpdateHotkeys", function(button)
            UpdateTotemHotkey(button)
        end)

        hookedHotkeyUpdates = true
    end
end

listener:RegisterEvent("PLAYER_ENTERING_WORLD")
listener:RegisterEvent("PLAYER_REGEN_ENABLED")

if isShaman then
    listener:RegisterEvent("SPELLS_CHANGED")
    listener:RegisterEvent("UPDATE_MULTI_CAST_ACTIONBAR")
    listener:RegisterEvent("UPDATE_BINDINGS")
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

-- Restore MainActionBar mouse behavior in Edit Mode.
if EventRegistry and EventRegistry.RegisterCallback then

    EventRegistry:RegisterCallback("EditMode.Enter", function()
        SetMainActionBarMouse(true)
    end, listener)

    EventRegistry:RegisterCallback("EditMode.Exit", ScheduleApply, listener)

end
