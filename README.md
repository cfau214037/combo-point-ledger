# Combo Point Ledger

A lightweight rogue combo-point HUD for World of Warcraft: Forever. It starts just below the center of the screen so you can keep your eyes on your character during PvP.

Copy the `ComboPointLedger` folder into `World of Warcraft/_forever_/Interface/AddOns/` and start the client. Open the settings with `/cpl` or left-click the minimap icon.

- Choose **Dots**, **Ticks**, or **Number** under **Display Style**. Filled dots and ticks use marbled amber centers with dark bronze rims. All three styles brighten at five combo points.
- Under **Placement**, choose **Screen HUD** or **Target Nameplate**. Target Nameplate shows your selected style along the inside lower edge of your current enemy's floating health bar. Enable enemy nameplates in WoW to use it.
- Select **Edit HUD** to preview five points and adjust the size. In Screen HUD mode, you can also drag the display. Select **Lock HUD** or press Escape to finish editing. The locked HUD lets clicks pass through.
- Toggle **Show HUD** in settings or from the minimap icon's right-click menu. The HUD appears in combat or anytime your current target has combo points, including points from Premeditation. **Edit HUD** is available out of combat. Style, size, and position persist across sessions.

The HUD updates in response to combo-point and target changes. It uses WoW's UI widgets to render restricted combat values directly.

## Publishing a release

Set `## Version` in `ComboPointLedger/ComboPointLedger_Forever.toc` and push the commit. Push the matching tag, such as `v0.1.1`, or use **Actions → Build addon release → Run workflow** and enter the tag to create it from the selected branch. Creating a branch named `release/v0.1.1` also triggers the workflow. GitHub Actions publishes the release and attaches `ComboPointLedger-v0.1.1.zip`. The ZIP contains the `ComboPointLedger` addon folder ready to extract into `Interface/AddOns`.
