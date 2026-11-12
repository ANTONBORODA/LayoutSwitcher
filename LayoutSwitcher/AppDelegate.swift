import Cocoa
import SwiftUI
import ServiceManagement
import Carbon

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var arrayLangHotKeys: [NSEvent.ModifierFlags] = [.function, .option, .control, .command]

    private var menuBarItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var langEventMonitor: Any?
    private var editEventMonitor: Any?
    
    private var enabledEditKeysValues: [String] = []
    private var editKeysState: EditHotKeys = []
    private var modifiersPressed = false

    private struct Constants {
        // Icon image sixe
        static let imageSize = 18.0
    }

    public func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Init application menu and icon
        initMenu()
        
        // Check security access to init event monitor
        if isApplicationHasSecurityAccess() {
            initLangSwitchEventMonitor()
            initWinEditEventMonitor()
        } else {
            let securityAlert = NSAlert()
            
            securityAlert.messageText = "Need security permissions"
            securityAlert.informativeText = "Please provide security permissions for the application and restart it.\nThis is needed to be able globally monitor shortcuts to switch keyboard layout."
            securityAlert.alertStyle = .critical
            securityAlert.addButton(withTitle: "Settings")
            securityAlert.addButton(withTitle: "Exit")
            
            if securityAlert.runModal() == .alertFirstButtonReturn {
                openPrivacySettings()
            }
            
            // Shutdown the application anyway
            exit(-1)
        }
    }

    public func applicationWillTerminate(_ aNotification: Notification) {
        deinitLangEventMonitor()
        deinitEditEventMonitor()
    }
    
    private func updateEditMenuState(editkeysMenu: NSMenuItem) {
        let submenu = editkeysMenu.submenu
        var hotkeysState: NSControl.StateValue = .off
        submenu?.items.forEach {
            if $0.isSeparatorItem || hotkeysState == .mixed {
                return
            }
                
            switch $0.state {
            case .on:
                hotkeysState = .on
            case .off:
                if hotkeysState == .on {
                    hotkeysState = .mixed
                }
            default:
                return
            }
        }
        
        editkeysMenu.state = hotkeysState
    }
    
    private func newEditMenuItem(_ title: String, key: String, tag: EditHotKeys) -> NSMenuItem {
        let menuItem = NSMenuItem()
        menuItem.title = title
        menuItem.action = #selector(applicationSetWinEditKey)
        menuItem.keyEquivalent = key
        menuItem.tag = tag.rawValue
        menuItem.state = editKeysState.contains(tag) ? .on : .off
        return menuItem
    }
    
    private func initMenu() {
        // Define application's tray icon
        if let menuBarButton = menuBarItem.button {
            menuBarButton.image = #imageLiteral(resourceName: "MenuBarIcon")
            menuBarButton.image?.size = NSSize(width: Constants.imageSize, height: Constants.imageSize)
            menuBarButton.image?.isTemplate = true
            menuBarButton.target = self
        }
        
        // Define hot keys submenu
        let hotkeysSubmenu = NSMenu.init()
        hotkeysSubmenu.addItem(withTitle: "Shift ⇧ + Fn", action: #selector(applicationChangeHotkey), keyEquivalent: "")
        hotkeysSubmenu.addItem(withTitle: "Shift ⇧ + Option ⌥", action: #selector(applicationChangeHotkey), keyEquivalent: "")
        hotkeysSubmenu.addItem(withTitle: "Shift ⇧ + Control ⌃", action: #selector(applicationChangeHotkey), keyEquivalent: "")
        hotkeysSubmenu.addItem(withTitle: "Shift ⇧ + Command ⌘", action: #selector(applicationChangeHotkey), keyEquivalent: "")
        
        // Get saved checked hot key from previous start
        hotkeysSubmenu.item(at: SettingsHelper.shared.checkedHotKeyIndex)?.state = .on
        
        // Define main menu
        let statusBarMenu = NSMenu()
        let hotkeysMenu = statusBarMenu.addItem(withTitle: "Layout shortcuts", action: nil, keyEquivalent: "")
        
        // Assign submenu to main menu
        hotkeysMenu.submenu = hotkeysSubmenu

        // Define submenu with layouts to cycle through, refilled each time it opens
        let cycleSubmenu = NSMenu.init()
        cycleSubmenu.delegate = self
        cycleSubmenu.autoenablesItems = false
        updateCycleMenu(cycleSubmenu)

        let cycleMenu = statusBarMenu.addItem(withTitle: "Cycle through", action: nil, keyEquivalent: "")
        cycleMenu.submenu = cycleSubmenu

        // Define edit hot keys submenu
        let editHotkeysSubmenu = NSMenu.init()
        
        editKeysState = EditHotKeys(rawValue: SettingsHelper.shared.winEditKeys)

        editHotkeysSubmenu.addItem(newEditMenuItem("Undo/Redo: Control ⌃ + Z | Y", key: "z", tag: EditHotKeys.UndRedo))
        editHotkeysSubmenu.addItem(newEditMenuItem("Copy/Paste: Control ⌃ + X | C | V", key: "c", tag: EditHotKeys.CopyPaste))
        editHotkeysSubmenu.addItem(NSMenuItem.separator())
        editHotkeysSubmenu.addItem(newEditMenuItem("Find: Control ^ + F", key: "f", tag: EditHotKeys.Find))
        editHotkeysSubmenu.addItem(newEditMenuItem("Select all: Control ⌃ + A", key: "l", tag: EditHotKeys.All))
        editHotkeysSubmenu.addItem(newEditMenuItem("Open/Save: Control ⌃ + O | S", key: "o", tag: EditHotKeys.OpenSave))
        editHotkeysSubmenu.addItem(NSMenuItem.separator())
        editHotkeysSubmenu.addItem(newEditMenuItem("Print: Control ⌃ + P", key: "p", tag: EditHotKeys.Print))
    
        // editHotkeysSubmenu.addItem(withTitle: "Close: ⌥F4",  action: #selector(applicationSetWinEditKey), keyEquivalent: "q")
        
        // Define main menu
        let editkeysMenu = statusBarMenu.addItem(withTitle: "Edit shortcuts", action: nil, keyEquivalent: "")
        
        // Assign submenu to main menu
        editkeysMenu.submenu = editHotkeysSubmenu
        updateEditMenuState(editkeysMenu: editkeysMenu)
        
        // Define autostart menu and get its state from the system
        let autostartMenuItem = NSMenuItem(title: "Launch at login", action: #selector(applicationAutostart), keyEquivalent: "s")
        autostartMenuItem.state = isLaunchAtLoginEnabled() ? .on : .off
        statusBarMenu.addItem(autostartMenuItem)
        
        // Define other menu items
        statusBarMenu.addItem(NSMenuItem.separator())
        statusBarMenu.addItem(withTitle: "About...", action: #selector(applicationAbout), keyEquivalent: "a")
        statusBarMenu.addItem(withTitle: "Quit", action: #selector(applicationQuit), keyEquivalent: "q")
        
        menuBarItem.menu = statusBarMenu
    }

    public func menuNeedsUpdate(_ menu: NSMenu) {
        // Only the cycle submenu has a delegate, refresh it in case layouts were changed in system settings
        updateCycleMenu(menu)
    }

    private func updateCycleMenu(_ menu: NSMenu) {
        let excludedIds = SettingsHelper.shared.excludedInputSourceIds

        menu.removeAllItems()
        for inputSource in getAllInputSources() {
            let menuItem = NSMenuItem(title: inputSource.name, action: #selector(applicationToggleCycledInputSource), keyEquivalent: "")
            menuItem.representedObject = inputSource.id
            menuItem.state = excludedIds.contains(inputSource.id) ? .off : .on
            menu.addItem(menuItem)
        }

        // Do not allow to uncheck the last layout, so the hot key always has one to switch to
        let checkedItems = menu.items.filter { $0.state == .on }
        if checkedItems.count == 1 {
            checkedItems.first?.isEnabled = false
        }
    }

    private func initLangSwitchEventMonitor() {
        // Get second modifier key, according to menu
        let secondModifierFlag = arrayLangHotKeys[SettingsHelper.shared.checkedHotKeyIndex]
        
        // Enable key event monitor
        langEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
            let areModifiersActive = event.modifierFlags.contains(.shift) &&
                event.modifierFlags.contains(secondModifierFlag)
            if areModifiersActive {
                // set Flag when required modifier keys pressed
                self.modifiersPressed = true
            } else if self.modifiersPressed {
                // if required modifier keys pressed and Flag is set
                // run change layout routine (keys released)
                self.selectNextLayout()
                // reset Flag
                self.modifiersPressed = false
            }
        }
    }
    
    private func initWinEditEventMonitor() {
        for hotkeyType in editKeysState.elements() {
            enabledEditKeysValues.append(contentsOf: editHotkeysValues[hotkeyType.rawValue] ?? [])
        }
        
        // Enable key event monitor
        editEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            // reset Flag when any key is pressed to prevent unwanted layout switch
            // e.g. when user selects a text with [shift + option + arrow keys] combination
            self.modifiersPressed = false

            if event.modifierFlags.contains(.control) {
                let char = event.charactersIgnoringModifiers
                let charCode = event.keyCode
                if self.enabledEditKeysValues.contains(char ?? "/") {
                    self.sendDefaultEditHotkey(char ?? "/", code: charCode)
                }
            }
        }
    }
    
    private func deinitLangEventMonitor() {
        guard langEventMonitor != nil else {return}
        NSEvent.removeMonitor(langEventMonitor!)
    }
    
    private func deinitEditEventMonitor() {
        guard editEventMonitor != nil else {return}
        NSEvent.removeMonitor(editEventMonitor!)
    }
    
    private func updateLangEventMonitor() {
        deinitLangEventMonitor()
        initLangSwitchEventMonitor()
    }
    
    private func updateEditEventMonitor() {
        deinitEditEventMonitor()
        initWinEditEventMonitor()
    }
    
    private func isApplicationHasSecurityAccess() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options)
    }
    
    private func openPrivacySettings() {
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
            .flatMap { _ = NSWorkspace.shared.open($0) }
    }
    
    private func selectNextLayout() {
        guard let currentInputSourceId = getCurrentInputSourceId() else {
            return
        }

        // Re-read layouts on each switch to pick up changes made in system settings
        let allInputSourceIds = getAllInputSources().map { $0.id }
        let excludedIds = SettingsHelper.shared.excludedInputSourceIds
        var cycledInputSourceIds = allInputSourceIds.filter { !excludedIds.contains($0) }

        // Fall back to all layouts if none of the checked ones are installed anymore
        if cycledInputSourceIds.isEmpty {
            cycledInputSourceIds = allInputSourceIds
        }
        guard let firstInputSourceId = cycledInputSourceIds.first else {
            return
        }

        // Start the cycle over if current layout is not part of it
        guard let currentIndex = cycledInputSourceIds.firstIndex(of: currentInputSourceId) else {
            setInputSourceId(firstInputSourceId)
            return
        }
        let nextIndex = (currentIndex + 1) % cycledInputSourceIds.count
        if nextIndex != currentIndex {
            setInputSourceId(cycledInputSourceIds[nextIndex])
        }
    }
    
    private func sendDefaultEditHotkey(_ key: String, code: UInt16) {
        // Send the same key with Command instead of Control
        let src = CGEventSource(stateID: CGEventSourceStateID.hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false)
        
        keyDown?.flags = CGEventFlags.maskAlternate
        keyUp?.flags = CGEventFlags.maskAlternate
        keyDown?.flags = CGEventFlags.maskCommand
        keyUp?.flags = CGEventFlags.maskCommand

        let loc = CGEventTapLocation.cghidEventTap
        keyDown?.post(tap: loc)
        keyUp?.post(tap: loc)
    }
    
    private func getCurrentInputSourceId() -> String? {
        guard let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }
        return getInputSourceStringProperty(inputSource, kTISPropertyInputSourceID)
    }

    private func getAllInputSources() -> [(id: String, name: String)] {
        guard let inputSources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }
        let selectableSources = inputSources.filter(isSelectableInputSource)
        return selectableSources.compactMap { src in
            guard let id = getInputSourceStringProperty(src, kTISPropertyInputSourceID) else {
                return nil
            }
            return (id, getInputSourceStringProperty(src, kTISPropertyLocalizedName) ?? id)
        }
    }

    private func getInputSourceStringProperty(_ inputSource: TISInputSource, _ key: CFString) -> String? {
        return TISGetInputSourceProperty(inputSource, key)
            .map { Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String }
    }
    
    private func isSelectableInputSource(_ inputSource: TISInputSource) -> Bool {
        // Get the category property (e.g., "Keyboard Input Source")
        if let ptr = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceCategory) {
            let category = Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
            if category != kTISCategoryKeyboardInputSource as String {
                return false
            }
        }
        
        // Get the "selectable" flag
        if let ptr = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsSelectCapable) {
            let isSelectable = Unmanaged<CFNumber>.fromOpaque(ptr).takeUnretainedValue() as NSNumber
            if isSelectable.boolValue == false {
                return false
            }
        }
        
        return true
    }

    private func setInputSourceId(_ id: String) {
        let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
        guard let filteredArray = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource],
              let inputSource = filteredArray.first else {
            return
        }
        TISSelectInputSource(inputSource)
    }
    
    @objc private func applicationChangeHotkey(_ sender: NSMenuItem) {
        // Update the checked state of menu item and save it
        sender.state = sender.state == .on ? .off : .on
        SettingsHelper.shared.checkedHotKeyIndex = sender.menu!.index(of: sender)
        
        // Restart eventMonitor with new hot key
        self.updateLangEventMonitor()
        
        // Set previosly checked item to unchecked
        sender.menu?.items.forEach {
            if $0 != sender && $0.state == .on {
                $0.state = sender.state == .on ? .off : .on
            }
        }
    }
    
    @objc private func applicationToggleCycledInputSource(_ sender: NSMenuItem) {
        guard let inputSourceId = sender.representedObject as? String else {
            return
        }

        // Update the checked state of menu item and save it
        sender.state = sender.state == .on ? .off : .on

        var excludedIds = SettingsHelper.shared.excludedInputSourceIds
        excludedIds.removeAll { $0 == inputSourceId }
        if sender.state == .off {
            excludedIds.append(inputSourceId)
        }
        SettingsHelper.shared.excludedInputSourceIds = excludedIds
    }

    @objc private func applicationSetWinEditKey(_ sender: NSMenuItem) {
        // Update the checked state of menu item and save it
        sender.state = sender.state == .on ? .off : .on
        
        var tagsValue = 0
        
        sender.menu?.items.forEach {
            if $0.state == .on {
                tagsValue += $0.tag
            }
        }
        
        SettingsHelper.shared.winEditKeys = tagsValue
        
        editKeysState = EditHotKeys(rawValue: tagsValue)
        
        // Restart eventMonitor with new hot key
        self.updateEditMenuState(editkeysMenu: sender.parent!)
        self.updateEditEventMonitor()

    }
    
    @objc private func applicationDisable(_ sender: NSMenuItem) {
        // Update menu item checkbox
        sender.state = sender.state == .on ? .off : .on
        
        // Get the new state based on the menu item checkbox
        let disabled = sender.state == .on ? true : false
        
        if disabled {
            deinitLangEventMonitor()
            deinitEditEventMonitor()
        } else {
            updateLangEventMonitor()
            updateEditEventMonitor()
        }
    }
    
    private func isLaunchAtLoginEnabled() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }

    private func launchAtLogin(_ newState: Bool) -> Bool {
        do {
            if newState {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            return false
        }
    }

    @objc private func applicationAutostart(_ sender: NSMenuItem) {
        // Get the new state based on the menu item checkbox
        let newState = sender.state != .on

        if !launchAtLogin(newState) {
            let securityAlert = NSAlert()

            securityAlert.messageText = "Can't perform this operation"
            securityAlert.informativeText =
                "Please check that application was copied to /Applications directory and try again.\n" +
                "You can also add it manually in Settings -> General -> Login Items"
            securityAlert.alertStyle = .warning
            securityAlert.addButton(withTitle: "Ok")
            securityAlert.runModal()
        }

        // Show the actual state, as it can also be changed in system settings
        sender.state = isLaunchAtLoginEnabled() ? .on : .off
    }
    
    @objc private func applicationAbout() {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let aboutAlert = NSAlert()
        
        aboutAlert.messageText = "Layout Switcher v." + appVersion!
        aboutAlert.informativeText =
            "LayoutSwitcher is open-source application that allows you to change keyboard layout " +
            "using shortcuts that are not alloved by MacOS: " +
            "Fn + Shift ⇧, Option ⌥ + Shift ⇧, Command ⌘ + Shift ⇧ or Control ⌃ + Shift ⇧. \n" +
            "In some sence it an alternative for the Punto Switcher or Karabiner " +
            "if you are using it for similar purpose, because both are kind of overkill for this."
        aboutAlert.alertStyle = .informational
        aboutAlert.addButton(withTitle: "Ok")
        aboutAlert.runModal()
    }

    @objc private func applicationQuit() {
        exit(0)
    }
}
