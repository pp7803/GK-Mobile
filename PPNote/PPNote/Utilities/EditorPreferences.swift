import SwiftUI

final class EditorPreferences {
    static let shared = EditorPreferences()
    
    private let defaults = UserDefaults.standard
    private let fontSizeKey = "ppnote.editor.lastFontSize"
    private let defaultFontSize: CGFloat = 16
    
    private init() {}
    
    var lastFontSize: CGFloat {
        get {
            let storedValue = defaults.double(forKey: fontSizeKey)
            if storedValue <= 0 {
                return defaultFontSize
            }
            return CGFloat(storedValue)
        }
        set {
            defaults.set(Double(newValue), forKey: fontSizeKey)
        }
    }
}
