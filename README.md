
# About
LayoutSwitcher is open-source application that allows you to change keyboard layout using shortcuts that are not alloved by MacOS: Fn + Shift ⇧, Option ⌥ + Shift ⇧, Command ⌘ + Shift ⇧ or Control ⌃ + Shift ⇧. In some sence it an alternative for the Punto Switcher or Karabiner if you are using it for similar purpose, because both are kind of overkill for this.


![LayoutSwitcher](LayoutSwitcher.png)

# Installation
Requires macOS 15 or newer, works on both Intel and Apple Silicon Macs.

1. Download `LayoutSwitcher.zip` by the link below, unzip it and move LayoutSwitcher application to your Applications folder
2. Run the application. Since it is not notarized by Apple, the first launch is blocked with "Apple could not verify LayoutSwitcher is free of malware". To allow it open "Settings -> Privacy & Security", scroll down and click "Open Anyway". Alternatively run in Terminal `xattr -dr com.apple.quarantine /Applications/LayoutSwitcher.app`
3. At the first run application will ask you to add LayoutSwitcher to "Settings -> Privacy & Security -> Accessibility" in order to work properly. This is needed to be able globally monitor shortcut that you chosen to switch keyboard layout. Restart the application after that.
4. After updating to a new version remove LayoutSwitcher from the Accessibility list and add it again, otherwise macOS keeps the permission for the old version only.

# Usage
* "Layout shortcuts" menu chooses the shortcut to switch keyboard layout
* "Cycle through" menu chooses which layouts the shortcut switches between. Unchecked layouts are skipped, and when you are on one of them the shortcut switches back to the first checked layout
* "Edit shortcuts" menu enables Windows-like Control ⌃ shortcuts for undo, copy/paste and others

# Downloads
* GitHub: https://github.com/3t0n/LayoutSwitcher/releases/

# Stand With Ukraine:
[![Stand With Ukraine](https://raw.githubusercontent.com/vshymanskyy/StandWithUkraine/main/banner-direct-single.svg)](https://stand-with-ukraine.pp.ua)
