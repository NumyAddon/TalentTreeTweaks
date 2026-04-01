-- Please use the Localization App on CurseForge to update this file
-- https://legacy.curseforge.com/wow/addons/talent-tree-tweaks/localization
local name, _ = ...

local L = LibStub("AceLocale-3.0"):NewLocale(name, "deDE")
if not L then return end

-- TalentTreeTweaks
--[[Translation missing --]]
L[ [=[%d points spent past the gate.
%d extra points above the gate are free to be moved away.]=] ] = [=[%d points spent past the gate.
%d extra points above the gate are free to be moved away.]=]
--[[Translation missing --]]
L["%s Switch to %s"] = "%s Switch to %s"
--[[Translation missing --]]
L["(was %s)"] = "(was %s)"
--[[Translation missing --]]
L["A workaround for one of the ways that Talent Tree taint can block action buttons from working."] = "A workaround for one of the ways that Talent Tree taint can block action buttons from working."
--[[Translation missing --]]
L["Addon development takes a large amount of time and effort. If you enjoy using %s, please consider supporting its development by donating. Your support helps ensure the continued improvement and maintenance of the addon. Thank you for your generosity!"] = "Addon development takes a large amount of time and effort. If you enjoy using %s, please consider supporting its development by donating. Your support helps ensure the continued improvement and maintenance of the addon. Thank you for your generosity!"
L["Adds a button to link the currently shown build in chat."] = "Fügt einen Button hinzu, um die momentane Konfiguration im Chat zu teilen."
L["Adds a few fixes for minor issues."] = "Fügt ein paar Fehlerbehebungen für kleinere Probleme hinzu."
L["Adds a mini tree in various tooltips for Talent Tree Builds"] = "Fügt einen Minibaum in verschiedenen Tooltips für Talentbaumkonfigurationen hinzu."
L["Adds a more obvious highlight when you can relearn talents in bulk by shift-clicking them."] = "Fügt eine deutlichere Hervorhebung hinzu, wenn man Talente in Serie neu erlernen kann."
--[[Translation missing --]]
L["Adds a right-click menu option to directly inspect a player's talents."] = "Adds a right-click menu option to directly inspect a player's talents."
L["Adds a right-click option to the loadout dropdown to export your build."] = "Fügt dem Konfigurations-Dropdown eine Rechtsklick-Option zum Exportieren hinzu."
L["Adds options to adjust the background of the talent tree UI."] = "Fügt Optionen hinzu, um den Hintergrund des Talentbaum UI anzupassen."
L["Adds respec buttons to the talent tree UI."] = "Fügt dem Talentbaum UI Buttons hinzu, um die Spezialisierung zu ändern."
L["Adds spell id and more to the various talent tree tooltips."] = "Fügt den verschiedenen Talentbaum-Tooltips die Spell ID und mehr hinzu."
L["Allows you to import talent loadouts into the currently selected loadout."] = "Erlaubt das Importieren von Konfigurationen in die aktuell ausgewählte Konfiguration."
L["Allows you to press CTRL-C to copy the spellID of a talent, while hovering over it."] = "Erlaubt es mit STRG + C, die spellID zu kopieren, wenn du mit der Maus über dem Talent bist."
--[[Translation missing --]]
L["Allows you to press CTRL-D to open a table inspector of your choice, with the nodeInfo associated with the node."] = "Allows you to press CTRL-D to open a table inspector of your choice, with the nodeInfo associated with the node."
--[[Translation missing --]]
L["Allows you to right-click the Hero Talent button to quickly switch hero specs."] = "Allows you to right-click the Hero Talent button to quickly switch hero specs."
L["Allows you to scale the talent tree with CTRL+Scrolling with the mousewheel."] = "Ermöglicht das Skalieren des Talentbaums mit STRG + Mausrad scrollen."
L["Allows you to search for talents by their spellID, nodeID, entryID, and definitionID."] = "Erlaubt die Suche nach Talenten anhand ihrer spellID, nodeID, entryID oder definitionID."
L["ALT + Click:"] = "ALT + Klick:"
--[[Translation missing --]]
L["Always Replace Share Button"] = "Always Replace Share Button"
L["Always Show Gates"] = "Sperren immer anzeigen"
L["Always show the \"x more points required\" gates. Gates that are passed will be semi-transparent."] = "Zeige immer die Sperren \"Gebt noch X Punkte aus, um diese Reihe freizuschalten\" an. Sperren die erfüllt wurden, werden halbtransparent."
--[[Translation missing --]]
L["Apply DRIVE Upgrades"] = "Apply DRIVE Upgrades"
--[[Translation missing --]]
L["Are you sure you want to reset these settings to their default values? This cannot be undone."] = "Are you sure you want to reset these settings to their default values? This cannot be undone."
--[[Translation missing --]]
L["Auto Ride Along"] = "Auto Ride Along"
--[[Translation missing --]]
L["Auto Surge Choice"] = "Auto Surge Choice"
--[[Translation missing --]]
L["Auto Talent Purchaser"] = "Auto Talent Purchaser"
--[[Translation missing --]]
L["Auto Talent Purchaser:"] = "Auto Talent Purchaser:"
--[[Translation missing --]]
L["Automatically enable/disable Ride Along the first time you log in on a character."] = "Automatically enable/disable Ride Along the first time you log in on a character."
--[[Translation missing --]]
L["Automatically pick Whirling Surge/Lightning Surge the first time you log in on a character."] = "Automatically pick Whirling Surge/Lightning Surge the first time you log in on a character."
--[[Translation missing --]]
L["Automatically purchase %s talents when you have enough currency."] = "Automatically purchase %s talents when you have enough currency."
--[[Translation missing --]]
L["Automatically purchase Horrific Visions talents when you have enough currency."] = "Automatically purchase Horrific Visions talents when you have enough currency."
--[[Translation missing --]]
L["Automatically purchases Skyriding and other generic talents when you have enough currency."] = "Automatically purchases Skyriding and other generic talents when you have enough currency."
--[[Translation missing --]]
L["Automatically selects the DRIVE upgrades you want for all of your alts."] = "Automatically selects the DRIVE upgrades you want for all of your alts."
--[[Translation missing --]]
L["Automatically set"] = "Automatically set"
--[[Translation missing --]]
L["Automatically upgrade the final Limits Unbound talent when you have enough currency."] = "Automatically upgrade the final Limits Unbound talent when you have enough currency."
L["Background Transparency"] = "Hintergrundtransparenz"
--[[Translation missing --]]
L["Basic Modules"] = "Basic Modules"
L["blocked in combat"] = "im Kampf blockiert"
L["Change Background"] = "Hintergrund ändern"
L["Change Scale"] = "Größe ändern"
--[[Translation missing --]]
L["Changes the loadout to be ordered based on when a loadout was created."] = "Changes the loadout to be ordered based on when a loadout was created."
--[[Translation missing --]]
L["Choose how the mini tree is displayed."] = "Choose how the mini tree is displayed."
L["Click to respec to this specialization."] = "Klicke, um zu dieser Spezialisierung zu wechseln."
L["Click:"] = "Klick:"
L["Color of the highlight"] = "Farbe der Hervorhebung"
--[[Translation missing --]]
L["Copy Loadout"] = "Copy Loadout"
L["Copy SpellID on hover"] = "SpellID bei Hover kopieren"
L["CTRL + Click:"] = "STRG + Klick:"
--[[Translation missing --]]
L["CTRL-C to copy"] = "CTRL-C to copy"
L["CTRL-C to copy %s"] = "STRG + C, um %s zu kopieren"
L["CTRL-C to copy spellID"] = "STRG + C, um die spellID zu kopieren"
--[[Translation missing --]]
L["CTRL-D to debug nodeInfo"] = "CTRL-D to debug nodeInfo"
L["Debug Talent.nodeInfo"] = "Debug Talent.nodeInfo"
--[[Translation missing --]]
L["Disable Custom Castbar"] = "Disable Custom Castbar"
--[[Translation missing --]]
L["Disable detection for loadout strings in chat"] = "Disable detection for loadout strings in chat"
--[[Translation missing --]]
L["Disable MultiActionBar_ShowAllGrids on Show"] = "Disable MultiActionBar_ShowAllGrids on Show"
--[[Translation missing --]]
L["Disable Ride Along"] = "Disable Ride Along"
--[[Translation missing --]]
L["Disables the module from scanning your chat for any loadout string that was sent as normal regular text. This can potentially reduce performance issues, especially on bussier realms."] = "Disables the module from scanning your chat for any loadout string that was sent as normal regular text. This can potentially reduce performance issues, especially on bussier realms."
--[[Translation missing --]]
L["Disables the MultiActionBar_ShowAllGrids function, which can cause action buttons to break."] = "Disables the MultiActionBar_ShowAllGrids function, which can cause action buttons to break."
--[[Translation missing --]]
L["Display Style"] = "Display Style"
--[[Translation missing --]]
L["Do Nothing"] = "Do Nothing"
--[[Translation missing --]]
L["Donate"] = "Donate"
--[[Translation missing --]]
L["DRIVE Auto Selector:"] = "DRIVE Auto Selector:"
--[[Translation missing --]]
L["DRIVE Auto Upgrades"] = "DRIVE Auto Upgrades"
L["Dump the nodeInfo table to chat."] = "Geb den nodeInfo table im Chat aus."
--[[Translation missing --]]
L["Enable Ride Along"] = "Enable Ride Along"
L["Enable Talent Tree Viewer Diff"] = "Aktiviere Unterschiede im Talent Tree Viewer"
--[[Translation missing --]]
L["Enable this module"] = "Enable this module"
--[[Translation missing --]]
L["Error opening in TalentTreeViewer. Showing default Blizzard inspect UI instead."] = "Error opening in TalentTreeViewer. Showing default Blizzard inspect UI instead."
--[[Translation missing --]]
L["Example of a loadout link"] = "Example of a loadout link"
--[[Translation missing --]]
L["Example of a regular string"] = "Example of a regular string"
--[[Translation missing --]]
L["Export / Inspect Loadouts"] = "Export / Inspect Loadouts"
L["Export on Right-Click"] = "Mit Rechtsklick exportieren"
--[[Translation missing --]]
L["Fade Inactive Hero Trees"] = "Fade Inactive Hero Trees"
--[[Translation missing --]]
L["Fade Inactive Hero Trees, to more easily see which one is active."] = "Fade Inactive Hero Trees, to more easily see which one is active."
--[[Translation missing --]]
L["Failed to inspect %s"] = "Failed to inspect %s"
--[[Translation missing --]]
L["Fix issue that prevents linking choice talents in chat, when inspecting a build"] = "Fix issue that prevents linking choice talents in chat, when inspecting a build"
--[[Translation missing --]]
L["Fix issue with the loadout dropdown not updating"] = "Fix issue with the loadout dropdown not updating"
--[[Translation missing --]]
L["Fix the loadout dropdown having a random order"] = "Fix the loadout dropdown having a random order"
--[[Translation missing --]]
L["For issues, feedback, or general question you can check my Discord server or GitHub issues page."] = "For issues, feedback, or general question you can check my Discord server or GitHub issues page."
--[[Translation missing --]]
L["Force apply the selected DRIVE upgrades. This automatically happens on login as well."] = "Force apply the selected DRIVE upgrades. This automatically happens on login as well."
--[[Translation missing --]]
L["Grey out inactive spec buttons, rather than the active spec button."] = "Grey out inactive spec buttons, rather than the active spec button."
--[[Translation missing --]]
L["Hero Talents"] = "Hero Talents"
--[[Translation missing --]]
L["Highlight Cascade Repurchable"] = "Highlight Cascade Repurchable"
--[[Translation missing --]]
L["Horrific Visions"] = "Horrific Visions"
L["If checked, the imported build will be imported into the currently selected loadout."] = "Wenn aktiviert, wird die zu importierende Konfiguration in die aktuell ausgewählte Konfiguration importiert."
--[[Translation missing --]]
L["If you enjoy using %s, consider supporting its development with a donation."] = "If you enjoy using %s, consider supporting its development with a donation."
L["Implements various workarounds around taint."] = "Implementiert verschiedene Workarounds, um Taint zu vermeiden."
L["Import into current loadout"] = "In die aktuelle Konfiguration importieren"
L["Import into current loadout (click \"%s\" afterwards)"] = "In die aktuelle Konfiguration importieren (Klicke \"%s\" danach)"
L["Import into current loadout by default"] = "Standardmäßig in die aktuelle Konfiguration importieren"
L["Import Loadout"] = "Konfiguration importieren"
--[[Translation missing --]]
L["Import string is corrupt, node type mismatch at nodeID %d. First option will be selected."] = "Import string is corrupt, node type mismatch at nodeID %d. First option will be selected."
--[[Translation missing --]]
L["Improved Loadout Links"] = "Improved Loadout Links"
L["Inspect Diff"] = "Inspektionsunterschied"
--[[Translation missing --]]
L["Inspect Talents"] = "Inspect Talents"
--[[Translation missing --]]
L["Inspected Build"] = "Inspected Build"
--[[Translation missing --]]
L["Invert highlight"] = "Invert highlight"
--[[Translation missing --]]
L["Legion Remix: Limits Unbound"] = "Legion Remix: Limits Unbound"
L["Link in chat"] = "In Chat verlinken"
--[[Translation missing --]]
L["Loading..."] = "Loading..."
--[[Translation missing --]]
L["Macros and certain addons that change loadouts, cause the dropdown to not update properly in some situations. This fixes that."] = "Macros and certain addons that change loadouts, cause the dropdown to not update properly in some situations. This fixes that."
--[[Translation missing --]]
L["Midnight introduced some changes that cause the custom castbar to throw errors when switching talents."] = "Midnight introduced some changes that cause the custom castbar to throw errors when switching talents."
L["Mini Tree in Tooltips"] = "Minibaum in Tooltips"
L["Misc Fixes"] = "Sonstige Fehlerbehebungen"
--[[Translation missing --]]
L["Mute chat spam while switching loadouts or specs."] = "Mute chat spam while switching loadouts or specs."
--[[Translation missing --]]
L["Open Artifact Traits UI"] = "Open Artifact Traits UI"
--[[Translation missing --]]
L["Open in Talent Tree Viewer"] = "Open in Talent Tree Viewer"
L["Open loadout in default Inspect UI"] = "Konfiguration im Talent UI öffnen"
--[[Translation missing --]]
L["Open the Legion Remix Artifact traits UI to view and adjust talents."] = "Open the Legion Remix Artifact traits UI to view and adjust talents."
--[[Translation missing --]]
L["Open these settings in a separate window."] = "Open these settings in a separate window."
--[[Translation missing --]]
L["Opens Blizzard's table inspect window."] = "Opens Blizzard's table inspect window."
L["Path NodeId"] = "Path NodeId"
L["Perk NodeId"] = "Perk NodeId"
--[[Translation missing --]]
L["Pop out settings"] = "Pop out settings"
L["Post in Chat"] = "In Chat posten"
--[[Translation missing --]]
L["Print in chat whenever a different upgrade is selected."] = "Print in chat whenever a different upgrade is selected."
L["Print in chat whenever a new talent is purchased."] = "Im Chat anzeigen, wenn ein neues Talent erlernt wurde."
L["Professions Tooltip"] = "Berufe Tooltip"
--[[Translation missing --]]
L["Purchased %d new talents."] = "Purchased %d new talents."
--[[Translation missing --]]
L["Questions or Feedback"] = "Questions or Feedback"
L["Reduce spam"] = "Reduziere Spam"
L["Reduce Taint"] = "Reduziere Taint"
--[[Translation missing --]]
L["Refresh the list of upgrades. May be useful if you have recently unlocked new upgrades."] = "Refresh the list of upgrades. May be useful if you have recently unlocked new upgrades."
--[[Translation missing --]]
L["Refresh Upgrades List"] = "Refresh Upgrades List"
--[[Translation missing --]]
L["Replace the Share Loadout button, to open a copy/paste popup instead of automatically copying to clipboard when needed."] = "Replace the Share Loadout button, to open a copy/paste popup instead of automatically copying to clipboard when needed."
--[[Translation missing --]]
L["Replace the Share Loadout button, to open a copy/paste popup instead of automatically copying to clipboard when possible."] = "Replace the Share Loadout button, to open a copy/paste popup instead of automatically copying to clipboard when possible."
--[[Translation missing --]]
L["Report On Selections"] = "Report On Selections"
L["Report Purchases"] = "Erlernen mitteilen"
--[[Translation missing --]]
L["Requires the Talent Tree Viewer addon to be installed and enabled."] = "Requires the Talent Tree Viewer addon to be installed and enabled."
--[[Translation missing --]]
L["Reset Ride Along Cache"] = "Reset Ride Along Cache"
--[[Translation missing --]]
L["Reset Surge Cache"] = "Reset Surge Cache"
L["Reset the color to default"] = "Farbe auf Standard zurücksetzen"
L["Reset the colors to default"] = "Farben auf Standard zurücksetzen"
--[[Translation missing --]]
L["Reset the Ride Along cache, so all characters will match the current setting on login."] = "Reset the Ride Along cache, so all characters will match the current setting on login."
--[[Translation missing --]]
L["Reset the Surge cache, so all characters will match the current setting on login."] = "Reset the Surge cache, so all characters will match the current setting on login."
L["Respec Buttons"] = "Spezialisierungsbuttons"
L["Right-click to share"] = "Rechtklick zum Teilen"
--[[Translation missing --]]
L["Row %d"] = "Row %d"
--[[Translation missing --]]
L["Row/Col"] = "Row/Col"
--[[Translation missing --]]
L["Row/Col Info"] = "Row/Col Info"
--[[Translation missing --]]
L["Scale"] = "Scale"
--[[Translation missing --]]
L["Scale of the mini tree."] = "Scale of the mini tree."
L["Scale Talent Frame"] = "Talentfenster skalieren"
L["Search by ID"] = "Suche nach ID"
L["Shift + Left-Click:"] = "Shift + Linksklick:"
L["Shift + Right-Click:"] = "Shift + Rechtsklick:"
--[[Translation missing --]]
L["Shift Hero Talent Trees"] = "Shift Hero Talent Trees"
--[[Translation missing --]]
L["Shifts the Hero Talent Trees to the left to avoid overlapping with the gate text."] = "Shifts the Hero Talent Trees to the left to avoid overlapping with the gate text."
L["Show %s Button"] = "Zeige \"%s\" Button"
--[[Translation missing --]]
L["Show a slider in Talent Tree Viewer UI"] = "Show a slider in Talent Tree Viewer UI"
--[[Translation missing --]]
L["Show a slider in the spellbook UI"] = "Show a slider in the spellbook UI"
L["Show a slider in the talent UI"] = "Zeige einen Schieberegler im Talent UI"
--[[Translation missing --]]
L["Show an example of the mini tree for your current spec."] = "Show an example of the mini tree for your current spec."
L["Show Diff"] = "Zeige Unterschiede"
--[[Translation missing --]]
L["Show Example"] = "Show Example"
L["Show Example link in chat"] = "Zeige Beispiellink im Chat"
--[[Translation missing --]]
L["Show the difference between your talent choices, and the talent build in Talent Tree Viewer."] = "Show the difference between your talent choices, and the talent build in Talent Tree Viewer."
L["Shows an example of a clickable link in chat."] = "Zeigt einen Beispiellink im Chat an."
--[[Translation missing --]]
L["Shows the difference between your current build and the build in the tooltip"] = "Shows the difference between your current build and the build in the tooltip"
L["Shows the difference between your talent choices, and the inspected player's talent choices."] = "Zeigt den Unterschied zwischen deiner Talentauswahl und der des betrachteten Spielers an."
--[[Translation missing --]]
L["Simple dots"] = "Simple dots"
--[[Translation missing --]]
L["Simple dots with custom diff colors"] = "Simple dots with custom diff colors"
--[[Translation missing --]]
L["Simple dots with default diff colors"] = "Simple dots with default diff colors"
--[[Translation missing --]]
L["Specify the upgrade you want to select on login."] = "Specify the upgrade you want to select on login."
--[[Translation missing --]]
L["Spell Icon"] = "Spell Icon"
L["Spell ID"] = "Spell ID"
--[[Translation missing --]]
L["Spellbook Background Transparency"] = "Spellbook Background Transparency"
L["SpellID"] = "SpellID"
--[[Translation missing --]]
L[ [=[Talent Loadout links are improved, to allow you to use modifiers, to copy the link, import it as a loadout, open it in Talent Tree Viewer (if installed) etc.
Optionally, it can also scan your chat for any loadout string that was sent as normal regular text.]=] ] = [=[Talent Loadout links are improved, to allow you to use modifiers, to copy the link, import it as a loadout, open it in Talent Tree Viewer (if installed) etc.
Optionally, it can also scan your chat for any loadout string that was sent as normal regular text.]=]
L["Talent Loadout String"] = "Konfigurationscode"
L["Talent Tooltip"] = "Talent Tooltip"
--[[Translation missing --]]
L["TalentTreeTweaks Diff Viewer"] = "TalentTreeTweaks Diff Viewer"
--[[Translation missing --]]
L["Temporarily |cffff0000disabled|r until next reload, because you refunded a talent."] = "Temporarily |cffff0000disabled|r until next reload, because you refunded a talent."
L["They have a talent you don't"] = "Ein Talent, das du nicht hast"
--[[Translation missing --]]
L["This loadout includes leveling information."] = "This loadout includes leveling information."
L["This module is incompatible with BlizzMove, and has been disabled."] = "Dieses Modul ist inkompatibel mit BlizzMove und wurde deaktiviert."
--[[Translation missing --]]
L["This module is only available for characters that have unlocked to the DRIVE system."] = "This module is only available for characters that have unlocked to the DRIVE system."
--[[Translation missing --]]
L["Toggle D.R.I.V.E. UI"] = "Toggle D.R.I.V.E. UI"
--[[Translation missing --]]
L["Toggle the %s UI to view and adjust talents."] = "Toggle the %s UI to view and adjust talents."
--[[Translation missing --]]
L["Toggle the DRIVE UI to view and adjust upgrades."] = "Toggle the DRIVE UI to view and adjust upgrades."
--[[Translation missing --]]
L["Toggle UI"] = "Toggle UI"
L["Toggles for the Professions Tooltips."] = "Berufe Tooltips ein- und ausschalten."
L["Toggles for the Talent Tooltips."] = "Talent Tooltips ein- und ausschalten."
L["Tooltip IDs"] = "Tooltip IDs"
L["Transparency"] = "Transparenz"
L["Unlock In Combat Spending"] = "Talente im Kampf neu verteilen freischalten"
L["Unlock Restrictions"] = "Beschränkungen aufheben"
L["Unlock Share Button"] = "Teilenbutton freischalten"
L["Unlocks several restrictions on the talent tree UI, such as being able to spend points while in combat, and being able to share your build without spending all points."] = "Schaltet einige Beschränkungen im Talentbaum-UI frei, wie z.B. die Umverteilung von Punkten im Kampf oder das Teilen der Konfiguration, ohne alle Punkte verteilt zu haben."
L["Unlocks the import button, even if at max loadouts"] = "Schalte das Importieren frei, auch wenn die maximalen Konfigurationen erreicht wurden"
L["Unlocks the share button, so you can share your build without spending all points."] = "Schaltet das \"Teilen\" frei, so dass du deine Konfiguration teilen kannst, ohne alle Punkte auszugeben."
L["Unlocks the talent buttons, so you can reallocate points while in combat."] = "Schaltet die Talente frei, so dass während des Kampfes Punkte neu zugewiesen werden können."
L["Use (Virag-)DevTool to inspect the nodeInfo table."] = "Verwende das ViragDevTool AddOn, um den nodeInfo table zu inspizieren."
L["Use LuaBrowser to inspect the nodeInfo table."] = "Verwende das Lua Browser AddOn, um den nodeInfo table zu inspizieren."
--[[Translation missing --]]
L["Version:"] = "Version:"
--[[Translation missing --]]
L["Warning: Custom colors may look weird, this cannot be fixed."] = "Warning: Custom colors may look weird, this cannot be fixed."
L["When enabled, the \"Import into current loadout\" checkbox will be checked by default."] = "Wenn aktiviert, wird das Häkchen bei \"In die aktuelle Konfiguration importieren\" standardmäßig gesetzt."
L["When enabled, the import button will be unlocked even if you have reached the maximum number of loadouts. Since you can still import into your current loadout"] = "Wenn aktiviert, wird das Importieren auch dann freigeschaltet, wenn die maximale Anzahl von Konfigurationen erreicht wurde. Da weiterhin in die aktuellen Konfiguration importieren werden kann."
L["You can toggle any of the following on/off to enable/disable the integration with that debug tool."] = "Du kannst die folgenden Optionen ein- oder ausschalten, um die Integration mit dem jeweiligen Debug Tool zu aktivieren oder zu deaktivieren."
L["You have a talent they don't"] = "Ein Talent, das du hast aber der andere nicht"
--[[Translation missing --]]
L["You have not unlocked Legion Remix artifact traits yet."] = "You have not unlocked Legion Remix artifact traits yet."
--[[Translation missing --]]
L["You have not unlocked the %s system on this character yet."] = "You have not unlocked the %s system on this character yet."
--[[Translation missing --]]
L["You have not unlocked the Horrific Visions system on this character yet."] = "You have not unlocked the Horrific Visions system on this character yet."
--[[Translation missing --]]
L["You have not unlocked the Skyriding system on this character yet."] = "You have not unlocked the Skyriding system on this character yet."
L["You have selected a different choice, or different number of points in a talent"] = "Du hast eine andere Wahl oder eine andere Anzahl von Punkten für das Talent gewählt"
--[[Translation missing --]]
L["You have the same talents"] = "You have the same talents"
L["You have to reload your UI after disabling this module, for some of the change to take effect."] = "Du musst nach der Deaktivierung dieses Moduls das UI neu laden, damit einige der Änderungen wirksam werden."

