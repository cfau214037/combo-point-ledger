# Combo Point Ledger

A lightweight rogue combo-point HUD for World of Warcraft: Forever. It starts just below the center of the screen so you can keep your eyes on your character during PvP.

Copy the `ComboPointLedger` folder into `World of Warcraft/_forever_/Interface/AddOns/` and start the client. Open the settings with `/cpl` or left-click the minimap icon.

- Choose **Dots**, **Ticks**, or **Number** under **Display Style**. All styles highlight five combo points in gold.
- Select **Edit HUD** to preview five points, drag the HUD, or adjust the size. Select **Lock HUD** or press Escape to save your placement. The locked HUD lets clicks pass through.
- Toggle **Show HUD** in settings or from the minimap icon's right-click menu. Style, size, and position persist across sessions.

The HUD updates in response to combo-point and target changes. It uses WoW's UI widgets to render restricted combat values directly.

## Publishing a release

Set `## Version` in `ComboPointLedger/ComboPointLedger_Forever.toc`, commit it, then push the matching tag, such as `v0.1.0`. GitHub Actions creates the release and attaches `ComboPointLedger-v0.1.0.zip`. The ZIP contains the `ComboPointLedger` addon folder ready to extract into `Interface/AddOns`.
