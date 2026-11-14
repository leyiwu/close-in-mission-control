import Foundation

/// Looks up a user-visible string. The English text is the default, given here next to the
/// code that uses it; other languages come from `<language>.lproj/Localizable.strings` in
/// the app bundle (see `Support/`), under the same key. Log lines and the Debug menu are
/// for developers and stay in English.
func tr(_ key: String, _ english: String) -> String {
    NSLocalizedString(key, value: english, comment: "")
}
