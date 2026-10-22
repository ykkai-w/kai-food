import Foundation

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let source = root.appendingPathComponent("App/Resources/English.json")
let output = root.appendingPathComponent("App/Resources/Traditional.json")
let keys = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: source)).keys
let existing = (try? JSONDecoder().decode([String: String].self, from: Data(contentsOf: output))) ?? [:]
var translations: [String: String] = [:]
for key in keys {
    translations[key] = existing[key] ?? (key.applyingTransform(StringTransform("Simplified-Traditional"), reverse: false) ?? key)
        .replacingOccurrences(of: "設置", with: "設定")
        .replacingOccurrences(of: "導出", with: "匯出")
        .replacingOccurrences(of: "記錄", with: "紀錄")
}
var data = try JSONSerialization.data(withJSONObject: translations, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
data.append(10)
try data.write(to: output, options: .atomic)
try data.write(to: root.appendingPathComponent("Android/app/src/main/assets/Traditional.json"), options: .atomic)
print("Updated \(translations.count) Traditional Chinese translations for both apps.")
