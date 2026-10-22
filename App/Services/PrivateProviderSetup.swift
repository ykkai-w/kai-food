import Foundation

/// Imports optional private-build credentials once, without replacing the owner's keys.
enum PrivateProviderSetup {
    private struct SetupError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private struct Configuration: Decodable {
        var glm: String?
        var deepseek: String?
    }

    static func importBundledKeys(bundle: Bundle = .main, defaults: UserDefaults = .standard) throws {
        guard let url = bundle.url(forResource: "PrivateProviders", withExtension: "json") else { return }
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch { throw SetupError(message: "私用 AI 配置读取失败，请重新生成配置后安装。") }
        try importKeys(data: data,
                       wasImported: { defaults.bool(forKey: "privateProviderImport.v1.\($0)") },
                       markImported: { defaults.set(true, forKey: "privateProviderImport.v1.\($0)") },
                       readKey: KeychainStore.read,
                       insertKeyIfAbsent: { try KeychainStore.insertIfAbsent($1, for: $0) })
    }

    static func importKeys(data: Data, wasImported: (String) -> Bool,
                           markImported: (String) -> Void,
                           readKey: (String) throws -> String?,
                           insertKeyIfAbsent: (String, String) throws -> Bool) throws {
        let config: Configuration
        do {
            guard data.count <= 16_384 else { throw SetupError(message: "私用配置文件过大。") }
            config = try JSONDecoder().decode(Configuration.self, from: data)
        } catch {
            // Decoder diagnostics may contain input values; keep them out of UI and logs.
            throw SetupError(message: "私用 AI 配置读取失败，请重新生成配置后安装。")
        }

        var errors: [String] = []
        for (provider, rawKey) in [("glm", config.glm), ("deepseek", config.deepseek)] {
            guard !wasImported(provider), let rawKey else { continue }
            let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = provider == "glm" ? "GLM" : "DeepSeek"
            guard key.count >= 16, key.count <= 1024,
                  key.unicodeScalars.allSatisfy({ $0.value > 32 && $0.value < 127 }) else {
                errors.append("\(name) 私用配置无效，请重新生成。")
                continue
            }
            do {
                if let existing = try readKey(provider), !existing.isEmpty {
                    markImported(provider)
                    continue
                }
                let inserted = try insertKeyIfAbsent(provider, key)
                guard let stored = try readKey(provider), !stored.isEmpty,
                      !inserted || stored == key else {
                    throw SetupError(message: "写入后未能读取。")
                }
                // A duplicate means another writer won the race; keep that key unchanged.
                // Deleting a key in Settings stays deleted on subsequent launches.
                markImported(provider)
            } catch {
                errors.append("\(name) 配置导入失败。\(error.localizedDescription)")
            }
        }
        if !errors.isEmpty { throw SetupError(message: errors.joined(separator: "\n")) }
    }
}
