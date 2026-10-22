import Foundation

/// App-private local persistence. Corrupt files throw rather than becoming an empty diary.
@MainActor
enum LocalFiles {
    #if NATIVE_SERVICE_SMOKE_TEST
    // Compiled only by scripts/test-native.sh; smoke tests never touch the real diary.
    static let directory: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent("kaii-native-smoke-" + UUID().uuidString, isDirectory: true)
    #elseif PUBLIC_UI_TEST
    static let directory: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("KaiiFood-PublicUITest", isDirectory: true)
    #else
    static let directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("KaiiFood", isDirectory: true)
    #endif

    enum FileError: LocalizedError {
        case invalidFilename, unsafeLink
        var errorDescription: String? {
            switch self {
            case .invalidFilename: return "无效的本地文件名。"
            case .unsafeLink: return "为保护本地数据，无法访问符号链接文件。"
            }
        }
    }

    private static func safeURL(_ filename: String, in folder: URL? = nil) throws -> URL {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        guard !filename.isEmpty, filename != ".", filename != "..", filename.count <= 160,
              filename.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw FileError.invalidFilename
        }
        let url = (folder ?? directory).appendingPathComponent(filename, isDirectory: false)
        if FileManager.default.fileExists(atPath: url.path),
           try url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true {
            throw FileError.unsafeLink
        }
        return url
    }

    private static func ensureDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        #endif
    }

    private static func write(_ data: Data, to url: URL) throws {
        try ensureDirectory(url.deletingLastPathComponent())
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }

    static func load<T: Decodable>(_ type: T.Type, filename: String) throws -> T? {
        let url = try safeURL(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: Data(contentsOf: url))
    }

    static func save<T: Encodable>(_ value: T, filename: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try write(encoder.encode(value), to: safeURL(filename))
    }

    static func savePhoto(_ data: Data) throws -> String {
        let filename = UUID().uuidString + ".jpg"
        let url = try safeURL(filename, in: directory.appendingPathComponent("Photos", isDirectory: true))
        try write(PhotoNormalizer.jpeg(data: data), to: url)
        return filename
    }

    static func photo(_ filename: String) -> Data? {
        guard let url = try? safeURL(filename, in: directory.appendingPathComponent("Photos", isDirectory: true)) else { return nil }
        return try? Data(contentsOf: url)
    }

    static func removePhoto(_ filename: String) throws {
        let url = try safeURL(filename, in: directory.appendingPathComponent("Photos", isDirectory: true))
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
