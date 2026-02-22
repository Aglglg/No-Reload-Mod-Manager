### Repository Contribution
Feel free to contribute on this project, especially adding more [languages translation](https://github.com/Aglglg/No-Reload-Mod-Manager/tree/main/assets/translations). Or providing [auto character icon data](https://github.com/Aglglg/No-Reload-Mod-Manager/tree/main/assets/cloud_data/auto_icon). Or anything else.
How? Of course, first of all you must know [How to contribute to open sourced project on Github](https://youtu.be/CML6vfKjQss).

---
### To-do list
- Troubleshoot & Preset features
- Bugfixes 
---

# No Reload Mod Manager / Skin Selection
(for XXMI Launcher supported games, or 3dmigoto mod)

## Overview
**No Reload Mod Manager** is a tool designed to make managing mods easier. With this tool, you can:

- Select skins/mods directly without needing to reload the game (F10).
- Give images/icons to your mods.
- Group your mods for a specific character.
- View and edit mod keybindings.

This tool supports **mouse**, **keyboard**, and **gamepad (XInput only)** inputs for interaction.

---

## Features
- **Mod Selection**: Choose and apply mods on the fly.
- **Keybinding Editor**: Modify mod keybindings conveniently.
- UI Buttons to trigger Keybinds/Toggles without pressing the keyboard.

---

## Guide

### How To Install
1. **Download** the installer setup file.
2. **Double-click** the installer exe file and install as usual.
4. **Open** the installed program.
5. If the program running, you can see its icon on **System Tray** (bottom-right corner).
6. **Click** the icon on system tray, select your target game. It will open the Mod Manager window.
7. Go to **Settings** tab, make sure **Mods Path** is correct for your specified game.
8. **Click Update Mod Data**
9. Done.

...

### How To Open Mod Manager Window Without Going To System Tray
1. Make sure your current window is your target game's window.
2. Press **Alt+W**(default), this will show/hide mod manager window.
3. If it does nothing, make sure it's running & on system tray. And then, check on **Settings** tab, make sure **Target Process** is correct. Make sure **Toggle Window Shortcuts** is correct.

...

### How To Automatically Run When Opening Game With XXMI (Optional)
1. Make sure it's already installed.
2. Search **No Reload Mod Manager** with Windows Search.
3. You should see option to **Open File Location**. Click it.
4. Right-click on it, select **Copy as path**.
5. Open your XXMI, on your target game, go to XXMI Setting, Go to Advanced, Tick Run-Post Launch/Run Pre-Launch (up to you, choose one).
6. Paste the copied path there.

...

### How To Add Group/Mod
1. Make sure your **Mods Path** is valid.
2. While on **Mods** tab right click anywhere and look for **Add group**.
3. Right-click on mods selection area and select **Add mod**.
4. Now you can drag & drop mod folders. 1 folder = 1 mod.
5. Press F10 to reload **if not automatically reloaded**.
6. Max mods per group is **500 mods**. Max group is **500 groups.**
### How To Add Group/Mod directly via File Explorer
1. Go to your **\_MANAGED\_** folder on your **Mods** folder.
2. In there, you can create new folder, it is group folder. The naming format is **group_x** where x is 1-500. Make sure the naming format is exactly correct and in lower-case. **Example: group_1, group_14, group_48.**
3. Go to group folder, you can paste your mods folder here. 1 folder = 1 mod.
4. Open Mod Manager Window. Press **Update Mod Data**. This step is **very important**.
5. Press F10 to reload **if not automatically reloaded**.

...

### How To Remove Group/Mod
1. Make sure your **Mods Path** is valid.
1. While on **Mods** tab right click on group/mod and select remove group/mod.
2. This will move your mod/group folder to **DISABLED_MANAGED_REMOVED** on your **Mods** folder.
3. It will automatically revert any changes to mod's .ini files. Which means **any changes you made while these mods were managed will all be removed/reverted**.
4. Press F10 to reload **if not automatically reloaded**.
### How To Remove Group/Mod directly via File Explorer
1. Go to your **\_MANAGED\_** folder on your **Mods** folder.
2. In there, you can delete/move group or mod folder.
3. In case you moved it and not delete it, open Mod Manager Window and go to **Settings** tab. Drag and drop the folders to the **Reverter**. This step is **very important**.
4. Open Mod Manager Window. Press **Update Mod Data**. This step is **very important**.

---

## Disclaimer & Warnings
Even though this is not main mod loader or mod tool, and only tool to organize mod folders, but:
- **Use at your own risk.**
- **Not responsible for account issues due to mod usage.**
- By downloading and using this tool, you **accept full responsibility**.

## Technical Details
- Built with **Flutter (Dart)**.
- Toggle window shortcuts (Alt+W) works by reading **target game process names** (e.g., `Client-Win64-Shipping.exe`).
- In order to change selected mods, this tool will do VK_KEYS keypress simulation & mouse movement.
- The mods that you added also being modified, you can remove the lines that were added by the mod manager, by dragging it to Reverter area on Settings.
- **XXMI DLL/3dmigoto will receives keypresses in the background**, d3dx.ini modified.

## Mod Ini Files Modification
- In order to switch selected mod in realtime without reload, ini files modification is needed.
- Only mods inside `_MANAGED_` that are modified.
- The changes made to the `.ini` files are minimal, and no new sections are ever added.
- The changes made to the `.ini` files are guaranteed to be valid, as it is already smart enough to determine _bad_ lines from modder.
- The manager only adds `if-endif` lines to the `Command List` sections and the `$managed_slot_id` variable to the existing `Constants` section.
- **It is really recommended to remove the `if-endif` lines added by the manager, by using Reverter in Settings if you’re not using it anymore or if you wanted to post/distribute your mods**.
- The reverter has been programmed to removes only mod manager specific lines/words without reverting everything back to zero (v2.8.3++).
<details>
 <summary><h3>(CLICK TO EXPAND AND READ THE DETAILED PROCESS)</h3></summary>

**When you press the Update Mod Data button, the following process occurs:**  
1. The manager gets the `Mods` path from the field you filled in.
2. It checks for `d3dx.ini` and `d3d11.dll` files in the same directory as your `Mods` path (for example: `GIMI\Mods`, `GIMI\d3dx.ini`, and `GIMI\d3d11.dll`). The `d3dx.ini` file is necessary to identify errored lines in your mod files later. And the `d3d11.dll` is just to make sure that you're in modding environment.
3. If the path is valid, it sets up a `_MANAGED_` folder inside the `Mods` folder. This is where all managed mods are stored. **Only the mods inside this folder will have their .ini files modified.**
4. It creates the files needed for the mod manager to work, such as `nrmm_keypress.txt` (which ensures simulated keypresses reach XXMI or 3DMigoto seamlessly) and `manager_group.ini` (to handle switching mods between groups).
5. The manager looks through all group folders inside the `_MANAGED_` folder and identifies every managed mod within them.
6. It searches for duplicate namespaces between mods. Since modders often use generic namespaces that can clash, the manager will automatically rename them if a conflict is found. This is an "all or nothing" process, meaning it guarantees that no `.ini` file will be left referencing an old namespace once the change is made. But, multiple ini files within the same mod could define `namespace =` line with the same value and it is fine and sometimes intended.
7. It then uses a function to read the modding environment exactly like the internal parser of `XXMI` or `3DMigoto`. This helps identify errored lines accurately, specifically invalid `if-elif-endif` structures that could interfere with the manager's modifications.
8. For every group folder, the manager deletes the old `group_x.ini` config file (where x is the group index) and creates a new one. It then processes each mod inside those groups.
9. It looks for `.ini` files inside the mod folder.
10. It creates a backup of the `.ini` files if one does not already exist.
11. For each `.ini` files, it will add `;-;` to the start of any errored lines found during the parsing phase, marking them as ignored or `comments`.
12. For each `.ini` file, it will look for the `[Constants]` section or create one if not found, and add the variable `global $managed_slot_id = x`, where `x` is the mod's index based on the folder name's sort order.
13. It looks for `command list` sections (which are: `[Present]`, `[ClearRenderTargetView]`, `[ClearDepthStencilView]`, `[ClearUnorderedAccessViewUint]`, `[ClearUnorderedAccessViewFloat]`, `[BuiltInCustomShader...]`, `[CustomShader...]`, `[BuiltInCommandList...]`, `[CommandList...]`, `[ShaderOverride...]`, `[TextureOverride...]`, main `[ShaderRegex...]`). It adds a manager `if` line (`if $managed_slot_id == $\modmanageragl\group_x\active_slot`) at the first line in the section. And an `endif` at the bottom line of the section. **Because errored lines are already handled previously, adding `if-endif` is safe here**.
14. It modifies `[Key...]` sections by adding the same manager expression to the `condition =` line.
15. In sections  `[TextureOverride...]`, `[CustomShader...]`, `[ShaderOverride...]`, and main `[ShaderRegex...]`, certain lines (like `hash`, `match_priority`, `shader_model`, etc) are executed by XXMI or 3dmigoto regardless of the `if-endif` logic. The manager places these lines above the `if` line, **for better readability**.
16. It also adds four spaces of `indentation` for every line inside an `if` block and removes them after an `endif`. **This is also for better readability only**.
17. It then saves the modified `.ini` files by writing a temporary file first. Once the save is successful, it renames the temporary file to the original filename. This prevents empty or corrupted files if the app crashes during the process.
18. Additionally, it also checks for specific lines that are known to crash the game due to flaws in XXMI or 3DMigoto logic. These include a single `[` on a line or a preamble `condition =` line with no value. The manager will remove or mark as `comment` these lines even if the `.ini` file is not part of a managed mod.
19. The manager also provides a report in the `Update Mod Data` popup regarding duplicated or missing common modding `libraries` (OrFix, Slotfix, RabbitFx, etc) referenced by your mods.
20. **Congrats for reading it all!**
</details>

## Keybindings Simulated
- **Clear Key (VK_CLEAR), Space Key (VK_SPACE), Enter Key (VK_RETURN)**
- **Mouse position x, y coordinate** - determine group index & mod index
- **Any keys listed from your mods** - if you enable click to simulate mod keybinds

---

## Security Concerns
- Runs in the **background**, app icon can be seen on Tray.
- **VirusTotal Reports**: Some antivirus programs may flag this tool's files.
- **If unsure, check the GitHub source code before use.** Or build it yourself if you understand flutter(for personal use only). Or just don't use it.

---

## Credits
Special thanks to:
- **All bug reporters, contributors, testers, users, and especially _supporters_!** ❤️
---

## Additions
If you don't like of the mod toggles/customizations are changed even though the game is in background (nrmm_keypress.txt is mandatory)  
Or you want to play multiple supported games at the same time without interferring mod selections  
You can use [Custom XXMI-Lib-Package](https://github.com/Aglglg/XXMI-Libs-Package) (based on Original XXMI-Lib-Package)  
