import Foundation

/// Synthetic keys and an in-memory store; no real Keychain or provider access.
func runPrivateProviderSetupChecks() throws {
    let glm = "synthetic-glm-key-for-local-tests"
    let deepseek = "synthetic-deepseek-key-for-local-tests"
    let data = try JSONEncoder().encode(["glm": glm, "deepseek": deepseek])
    var keys: [String: String] = [:]
    var imported: Set<String> = []
    var writes = 0
    func install(_ payload: Data? = nil) throws {
        try PrivateProviderSetup.importKeys(data: payload ?? data,
            wasImported: { imported.contains($0) },
            markImported: { _ = imported.insert($0) },
            readKey: { keys[$0] },
            insertKeyIfAbsent: {
                guard keys[$0] == nil else { return false }
                keys[$0] = $1
                writes += 1
                return true
            })
    }
    try install()
    precondition(keys == ["glm": glm, "deepseek": deepseek] && writes == 2)
    try install()
    precondition(writes == 2)
    print("PASS private keys import once")

    keys.removeValue(forKey: "glm")
    try install()
    precondition(keys["glm"] == nil && writes == 2)
    print("PASS deleted key stays deleted")

    imported.removeAll()
    keys = ["glm": "existing-owner-key-to-preserve", "deepseek": deepseek]
    try install()
    precondition(keys["glm"] == "existing-owner-key-to-preserve" && writes == 2)
    print("PASS existing owner keys preserved")

    imported.removeAll()
    keys.removeAll()
    enum FixtureError: Error { case saveFailed, readFailed }
    do {
        try PrivateProviderSetup.importKeys(data: data,
            wasImported: { imported.contains($0) },
            markImported: { _ = imported.insert($0) },
            readKey: { keys[$0] },
            insertKeyIfAbsent: {
                if $0 == "glm" { throw FixtureError.saveFailed }
                guard keys[$0] == nil else { return false }
                keys[$0] = $1
                return true
            })
        fatalError("Keychain save failure was hidden")
    } catch {
        precondition(error.localizedDescription.contains("GLM"))
    }
    precondition(!imported.contains("glm") && imported.contains("deepseek"))
    try install()
    precondition(keys["glm"] == glm && imported.contains("glm"))
    print("PASS failed key import can retry")

    imported.removeAll()
    do {
        try PrivateProviderSetup.importKeys(data: data,
            wasImported: { _ in false },
            markImported: { _ = imported.insert($0) },
            readKey: { _ in throw FixtureError.readFailed },
            insertKeyIfAbsent: { _, _ in fatalError("Read failure must not trigger an insert") })
        fatalError("Keychain read failure was hidden")
    } catch {}
    precondition(imported.isEmpty)
    print("PASS failed Keychain reads leave import pending")

    let singleProviderData = try JSONEncoder().encode(["glm": glm])
    var racedKeys: [String: String] = [:]
    var racedImports: Set<String> = []
    var importerWrites = 0
    try PrivateProviderSetup.importKeys(data: singleProviderData,
        wasImported: { racedImports.contains($0) },
        markImported: { _ = racedImports.insert($0) },
        readKey: { racedKeys[$0] },
        insertKeyIfAbsent: { provider, value in
            // A manual save lands after the importer's initial read, before its atomic add.
            racedKeys[provider] = "synthetic-concurrent-owner-key"
            guard racedKeys[provider] == nil else { return false }
            racedKeys[provider] = value
            importerWrites += 1
            return true
        })
    precondition(racedKeys["glm"] == "synthetic-concurrent-owner-key")
    precondition(importerWrites == 0 && racedImports.contains("glm"))
    print("PASS concurrent manual key survives private import")

    var unverifiedImports: Set<String> = []
    do {
        try PrivateProviderSetup.importKeys(data: singleProviderData,
            wasImported: { _ in false },
            markImported: { _ = unverifiedImports.insert($0) },
            readKey: { _ in nil },
            insertKeyIfAbsent: { _, _ in false })
        fatalError("An unreadable duplicate must not complete import")
    } catch {}
    precondition(unverifiedImports.isEmpty)
    print("PASS unreadable duplicate leaves import pending")

    do {
        try PrivateProviderSetup.importKeys(data: singleProviderData,
            wasImported: { _ in false },
            markImported: { _ = unverifiedImports.insert($0) },
            readKey: { _ in nil },
            insertKeyIfAbsent: { _, _ in true })
        fatalError("An unverified insert must not complete import")
    } catch {}
    precondition(unverifiedImports.isEmpty)
    print("PASS unverified insert leaves import pending")

    let malformed = Data("{\"glm\":\"synthetic-secret-error-sentinel\",BROKEN}".utf8)
    do { try install(malformed); fatalError("Malformed private config accepted") }
    catch { precondition(!error.localizedDescription.contains("synthetic-secret-error-sentinel")) }
    let invalid = try JSONEncoder().encode(["glm": "short"])
    do { try install(invalid); fatalError("Invalid private key accepted") }
    catch { precondition(!error.localizedDescription.contains("short")) }
    print("PASS private configuration errors omit input values")
}
