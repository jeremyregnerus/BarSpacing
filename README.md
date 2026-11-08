# BarSpacing

A small World of Warcraft: Forever addon that rearranges **Blizzard's original action bar buttons** into the QWERTY-inspired layout used by the older ElvUI_Spacing addon. No ElvUI required.

## Installation
1. Place the `BarSpacing` folder in `World of Warcraft/_forever_/Interface/AddOns/`.
2. Restart the WoW client (or reload if the addon was already installed).
3. Enable Action Bars 1–5 in Blizzard Options.
4. In Edit Mode, set those five action bars to **12 buttons, horizontal, one row**. Keep them visible. Their original on-screen locations serve as starting anchors.
5. Leave Edit Mode, then type `/barspacing apply` (or `/bs apply`). The addon also attempts to apply at login and on exiting Edit Mode.

## Notes
- Intended for the Forever 1.60.1 beta / Interface 16001.
- This is an **initial, untested port**; it uses the normal Blizzard button frame names. If the Forever client changes Edit Mode's frame handling, adjustments may be needed.
- Your old layout used Action Bars 1–5. Here the mapping is 1: ActionButton, 2: MultiBarBottomLeft, 3: MultiBarBottomRight, 4: MultiBarRight, 5: MultiBarLeft.
- BarSpacing does not change action slots, spells, or keybinds.
- Unlike the original, this initial port deliberately does **not** create the dark backdrop panels, to preserve the Blizzard appearance.
- Moving protected action buttons is prohibited during combat. Changes are deferred until combat ends.
- Blizzard Edit Mode can rearrange its buttons, so apply spacing again if a Blizzard layout update overwrites it.
- To diagnose issues, use `/console scriptErrors 1` followed by `/reload`.

## Version
0.1.0: Native Blizzard action-bar port of ElvUI_Spacing.
