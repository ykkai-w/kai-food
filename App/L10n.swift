import Foundation
import SwiftUI
import KaiiFoodCore

enum L10n {
    static let preferenceKey = "kaii.language"
    static var choice: AppLanguage { AppLanguage(rawValue: UserDefaults.standard.string(forKey: preferenceKey) ?? "system") ?? .system }
    static var language: AppLanguage { choice.resolved() }
    static var locale: Locale { Locale(identifier: language.rawValue) }
    static var calendar: Calendar { var value = Calendar.current; value.locale = locale; return value }
    private static let english = catalog("English")
    private static let traditional = catalog("Traditional")
    private static func catalog(_ name: String) -> [String: String] {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: name, withExtension: "json"), let data = try? Data(contentsOf: url), let values = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return values
    }
    static func text(_ key: String, _ arguments: Any...) -> String {
        var value: String
        switch language {
        case .english: value = english[key] ?? key
        case .traditional: value = traditional[key] ?? key
        default: value = key
        }
        let slots = try! NSRegularExpression(pattern: #"\{(\d+)\}"#)
        for match in slots.matches(in: value, range: NSRange(value.startIndex..., in: value)).reversed() {
            guard let range = Range(match.range, in: value), let numberRange = Range(match.range(at: 1), in: value), let index = Int(value[numberRange]), arguments.indices.contains(index) else { continue }
            value.replaceSubrange(range, with: String(describing: arguments[index]))
        }
        return value
    }
    static func error(_ error: Error) -> String {
        if let aiError = error as? AIError, case .http(let code) = aiError {
            switch code {
            case 401, 403: return text("API 授权失败（{0}），请检查 Key 和模型权限。", code)
            case 429: return text("服务暂时繁忙或请求受限（429），请稍后重试。")
            default: return text("模型服务返回 HTTP {0}。请检查模型名称、账户额度或稍后重试。", code)
            }
        }
        return text(error.localizedDescription)
    }
}

extension Date {
    func uiFormatted(_ style: Date.FormatStyle) -> String { formatted(style.locale(L10n.locale)) }
    func uiFormatted(date: Date.FormatStyle.DateStyle, time: Date.FormatStyle.TimeStyle) -> String {
        formatted(Date.FormatStyle(date: date, time: time).locale(L10n.locale))
    }
}

extension MealKind {
    var localizedTitle: String { L10n.text(displayName) }
}

extension MealInputMethod {
    var localizedTitle: String { L10n.text(title) }
}

struct LanguagePicker: View {
    @AppStorage(L10n.preferenceKey) private var language = AppLanguage.system.rawValue
    var body: some View {
        Picker(L10n.text("语言 / Language"), selection: $language) {
            ForEach(AppLanguage.allCases) { item in
                Text(item == .system ? L10n.text("跟随系统") : item.nativeName).tag(item.rawValue)
            }
        }
    }
}
