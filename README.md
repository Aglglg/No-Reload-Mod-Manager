### Repository Contribution
Feel free to contribute on this project, especially adding more languages translation. Or providing auto character icon data. Or anything else.
How? Of course, first of all you must know [How to contribute to open sourced project on Github](https://youtu.be/CML6vfKjQss).

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

## 🚀 Features
- **Mod Selection**: Choose and apply mods on the fly.
- **Keybinding Editor**: Modify mod keybindings conveniently.
- **Automatic Game Detection**: Pressing toggle window shortcut key will open window to corresponding target game.

---

## 📌 Guide

### 📥 How To Install
1. **Download** the installer setup file.
2. **Double-click** the installer exe file and install as usual.
4. **Open** the installed program.
5. If the program running, you can see its icon on **System Tray** (bottom-right corner).
6. **Click** the icon on system tray, select your target game. It will open the Mod Manager window.
7. Go to **Settings** tab, make sure **Mods Path** is correct for your specified game.
8. **Click Update Mod Data**
9. 🎉 Done! You can now organize mods, edit keybindings, and so on.

...

### 📜 How To Open Mod Manager Window Without Going To System Tray
1. Make sure your current window is your target game's window.
2. Press **Alt+W**(default), this will show/hide mod manager window.
3. If it does nothing, make sure it's running & on system tray an please check on **Settings** tab, make sure **Target Process** is correct. Make sure **Toggle Window Shortcuts** is correct.

...

### ✨ How To Automatically Run When Opening Game With XXMI (Optional)
1. Make sure it's already installed.
2. Search **No Reload Mod Manager** with Windows Search.
3. You should see option to **Open File Location**. Click it.
4. Right-click on it, select **Copy as path**.
5. Open your XXMI, on your target game, go to XXMI Setting, Go to Advanced, Tick Run-Post Launch/Run Pre-Launch (up to you, choose one).
6. Paste the copied path there.

...

### 🆕 How To Add Group/Mod
1. Make sure your **Mods Path** is valid.
2. While on **Mods** tab right click anywhere and look for **Add group**.
3. Right-click on mods selection area and select **Add mod**.
4. Now you can drag & drop mod folders. 1 folder = 1 mod.
5. Press F10 to reload **if not automatically reloaded**.
6. Max mods per group is **40 mods**. Max group is **48 groups.**
### 🆕 How To Add Group/Mod directly via File Explorer
1. Go to your **\_MANAGED\_** folder on your **Mods** folder.
2. In there, you can create new folder, it is group folder. The naming format is **group_x** where x is 1-48. Make sure the naming format is exactly correct and in lower-case. **Example: group_1, group_14, group_48.**
3. Go to group folder, you can paste your mods folder here. 1 folder = 1 mod.
4. Open Mod Manager Window. Press **Update Mod Data**. This step is **very important**.
5. Press F10 to reload **if not automatically reloaded**.

...

### 🗑️ How To Remove Group/Mod
1. Make sure your **Mods Path** is valid.
1. While on **Mods** tab right click on group/mod and select remove group/mod.
2. This will move your mod/group folder to **DISABLED_MANAGED_REMOVED** on your **Mods** folder.
3. It will automatically revert any changes to mod's .ini files. Which means **any changes you made while these mods were managed will all be removed/reverted**.
4. Press F10 to reload **if not automatically reloaded**.
### 🗑️ How To Remove Group/Mod directly via File Explorer
1. Go to your **\_MANAGED\_** folder on your **Mods** folder.
2. In there, you can delete/move group or mod folder.
3. In case you moved it and not delete it, open Mod Manager Window and go to **Settings** tab. Drag and drop the folders to the **Reverter**. This step is **very important**.
4. Open Mod Manager Window. Press **Update Mod Data**. This step is **very important**.

---

## ⚠️ Disclaimer & Warnings
- This is a **Windows Overlay App**.
- Simulates **key presses** but does **not** interact directly with the game. Only with WWMI/SRMI/ZZMI/GIMI/3dmigoto.
- **Use at your own risk.**
- **Not responsible for account issues due to mod usage.**
- By downloading and using this tool, you **accept full responsibility**.

## 🔧 Technical Details
- Built with **Flutter (Dart)**.
- Toggle window shortcuts (Alt+W) works by reading **target game process names** (e.g., `Client-Win64-Shipping.exe`).
- In order to change selected mods, this tool will do VK_KEYS keypress simulation.
- **WWMI/GIMI/SRMI/ZZMI will receives keypresses in the background** automatically add background_keypress.ini to your Mods folder.

## 🔑 Keybindings Simulated
- **Clear Key (VK_CLEAR)** – Base for keypress simulation.
- **F13 - F24** – Used to change groups.
- **Enter / Backspace** – Used to change groups.
- **Tab / Right Ctrl** – Used to change mods.
- **Numbers 1-5 & Z-B** – Used to change mods.

> 🛑 **Note:** If your PC/system uses these keys for other shortcuts, you'll need to **change your system settings** if you can/if you want.

---

## 🛡️ Security Concerns
- Runs in the **background**, app icon can be seen on Tray.
- **VirusTotal Reports**: Some antivirus programs may flag this tool's **installer** file. If you scan the installed app it's actually fine, but if you scan the installer, it might be flagged. Because I use **Inno Setup Compiler** to create the **Installer**.
- **If unsure, check the GitHub source code before use.** Or build it yourself if you understand flutter(for personal use only). Or just don't use it.

---

## 🙏 Credits
Special thanks to:
- **All bug reporters, testers, users, and supporters!** ❤️

---
