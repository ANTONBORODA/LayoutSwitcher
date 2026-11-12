import Foundation

class SettingsHelper {
    private let indexHotKey = "INDEX_HOT_KEY"
    private let enableAutostart = "ENABLE_AUTOSTART"
    private let enable = "ENABLE"
    private let winEditHotKeys = "WIN_EDIT_HOTKEYS"
    private let excludedInputSources = "EXCLUDED_INPUT_SOURCES"

    static let shared = SettingsHelper()

    private let store = UserDefaults.standard

    var isAutostartEnable: Bool {
        get { store.object(forKey: enableAutostart) as? Bool ?? false }
        set { store.set(newValue, forKey: enableAutostart) }
    }
    
    var isEnable: Bool {
        get { store.object(forKey: enable) as? Bool ?? false }
        set { store.set(newValue, forKey: enable) }
    }
    
    var winEditKeys: Int {
        get { store.object(forKey: winEditHotKeys) as? Int ?? 0 }
        set { store.set(newValue, forKey: winEditHotKeys) }
    }
    
    var checkedHotKeyIndex: Int {
        get { store.object(forKey: indexHotKey) as? Int ?? 2 }
        set { store.set(newValue, forKey: indexHotKey) }
    }

    // Layouts unchecked in the menu, so newly added layouts join the cycle by default
    var excludedInputSourceIds: [String] {
        get { store.object(forKey: excludedInputSources) as? [String] ?? [] }
        set { store.set(newValue, forKey: excludedInputSources) }
    }

}
