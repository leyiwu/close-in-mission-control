import Foundation

/// The language picked from the menu. Nothing saved means "follow the Mac". This is the
/// only thing the app remembers, kept in its preferences file.
enum LanguageChoice {
    /// Each language is named in itself, as a language menu usually is.
    static let available: [(code: String, name: String)] = [("en", "English"), ("zh-Hans", "简体中文")]

    private static let key = "language"

    static var current: String? {
        get {
            guard let code = UserDefaults.standard.string(forKey: key),
                  available.contains(where: { $0.code == code }) else { return nil }
            return code
        }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

/// Looks up a user-visible string. The English text is the default, given here next to the
/// code that uses it; other languages come from `<language>.lproj/Localizable.strings` in
/// the app bundle (see `Support/`), under the same key. A language picked from the menu wins;
/// otherwise macOS chooses from the Mac's language list. Log lines and the Debug menu are
/// for developers and stay in English.
func tr(_ key: String, _ english: String) -> String {
    switch LanguageChoice.current {
    case "en"?:
        return english
    case let code?:
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return english }
        return bundle.localizedString(forKey: key, value: english, table: nil)
    case nil:
        return NSLocalizedString(key, value: english, comment: "")
    }
}
