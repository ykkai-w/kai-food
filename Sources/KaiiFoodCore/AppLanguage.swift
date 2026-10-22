import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system, simplified = "zh-Hans", english = "en", traditional = "zh-Hant"
    public var id: String { rawValue }
    public var nativeName: String {
        switch self {
        case .system: return "跟随系统"
        case .simplified: return "简体中文"
        case .english: return "English"
        case .traditional: return "繁體中文"
        }
    }
    public func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> Self {
        guard self == .system else { return self }
        let first = preferredLanguages.first?.lowercased() ?? "en"
        guard first.hasPrefix("zh") else { return .english }
        return first.contains("hant") || first.contains("tw") || first.contains("hk") || first.contains("mo") ? .traditional : .simplified
    }
    public var responseLanguage: String {
        switch resolved() {
        case .english: return "English"
        case .traditional: return "繁體中文"
        default: return "简体中文"
        }
    }
}
