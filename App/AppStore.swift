import Foundation
import SwiftUI
import KaiiFoodCore

/// Only explicit save actions persist. Failed reads never overwrite the archive.
@MainActor final class AppStore: ObservableObject {
    @Published private(set) var meals: [MealEntry] = []
    @Published private(set) var frequentFoods: [FrequentFood] = []
    @Published var settings = AISettings()
    @Published var messages: [ChatMessage] = []
    @Published var error: String?
    @Published var storageReady = false
    @Published var showSettings = false
    let client = AIClient()
    private var keySetupTask: Task<Void, Error>?

    init() {
        #if PUBLIC_UI_TEST
        do { try DemoFixtures.prepare() } catch { self.error = L10n.error(error) }
        #endif
        reload()
        let setup = Task.detached { try PrivateProviderSetup.importBundledKeys() }
        keySetupTask = setup
        Task { @MainActor in
            do { try await setup.value }
            catch {
                self.error = [self.error, L10n.error(error)].compactMap { $0 }.joined(separator: "\n")
            }
        }
    }

    func reload() {
        do {
            let loaded = try LocalFiles.load([MealEntry].self, filename: "meals.json") ?? []
            guard loaded.allSatisfy({ !$0.items.isEmpty && $0.items.allSatisfy(\.isValid) }) else {
                throw LocalAppError.message(L10n.text("食记包含无效的份量或营养值；原文件保持不变。"))
            }
            let config = try LocalFiles.load(AISettings.self, filename: "settings.json") ?? AISettings()
            let chats = try LocalFiles.load([ChatMessage].self, filename: "chat.json") ?? []
            let favorites = try LocalFiles.load([FrequentFood].self, filename: "frequent-foods.json") ?? []
            guard favorites.allSatisfy(\.isValid), config.isValid else {
                throw LocalAppError.message(L10n.text("请检查常用食物和模型设置文件。"))
            }
            meals = loaded
            settings = config
            messages = chats
            frequentFoods = favorites
            storageReady = true
            error = nil
        } catch {
            storageReady = false
            self.error = L10n.text("本地文件读取失败，已暂停写入以保护原记录。{0}", L10n.error(error))
        }
    }

    func entries(on date: Date) -> [MealEntry] {
        meals.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.sorted { $0.date < $1.date }
    }

    func save(_ meal: MealEntry, photo: Data?) throws {
        guard storageReady else { throw LocalAppError.message(L10n.text("请先解决本地文件读取问题。")) }
        guard !meal.items.isEmpty, meal.items.allSatisfy(\.isValid) else { throw LocalAppError.message(L10n.text("请核对食物份量与营养值。")) }
        var saved = meal
        var newPhoto: String?
        if let photo { newPhoto = try LocalFiles.savePhoto(photo); saved.photoFilename = newPhoto }
        var updated = meals
        if let index = updated.firstIndex(where: { $0.id == saved.id }) { updated[index] = saved }
        else { updated.append(saved) }
        do { try LocalFiles.save(updated, filename: "meals.json") }
        catch { if let newPhoto { try? LocalFiles.removePhoto(newPhoto) }; throw error }
        let oldPhoto = meals.first(where: { $0.id == saved.id })?.photoFilename
        meals = updated
        if let oldPhoto, oldPhoto != saved.photoFilename { try? LocalFiles.removePhoto(oldPhoto) }
    }

    func delete(_ meal: MealEntry) {
        guard storageReady else { return }
        do {
            let updated = meals.filter { $0.id != meal.id }
            try LocalFiles.save(updated, filename: "meals.json")
            meals = updated
            if let photo = meal.photoFilename { try? LocalFiles.removePhoto(photo) }
        } catch { self.error = L10n.error(error) }
    }

    func saveSettings() throws {
        guard storageReady else { throw LocalAppError.message(L10n.text("本地存储暂不可写。")) }
        guard settings.isValid else { throw LocalAppError.message(L10n.text("请检查模型名称。")) }
        try LocalFiles.save(settings, filename: "settings.json")
    }

    func saveFrequent(_ value: FrequentFood) throws {
        guard storageReady, value.isValid else { throw LocalAppError.message(L10n.text("请填写完整的份量和营养值。")) }
        var next = frequentFoods
        if let index = next.firstIndex(where: { $0.id == value.id }) { next[index] = value }
        else { next.append(value) }
        try LocalFiles.save(next, filename: "frequent-foods.json")
        frequentFoods = next
    }

    func deleteFrequent(_ id: UUID) throws {
        guard storageReady else { throw LocalAppError.message(L10n.text("请先重新读取食记。")) }
        let next = frequentFoods.filter { $0.id != id }
        try LocalFiles.save(next, filename: "frequent-foods.json")
        frequentFoods = next
    }

    func setMessages(_ updated: [ChatMessage]) throws {
        guard storageReady else { throw LocalAppError.message(L10n.text("本地存储暂不可写。")) }
        try LocalFiles.save(updated, filename: "chat.json")
        messages = updated
    }

    func key(for provider: String) async throws -> String {
        _ = try? await keySetupTask?.value
        try Task.checkCancellation()
        let stored = try await Task.detached { try KeychainStore.read(provider) }.value
        try Task.checkCancellation()
        guard let value = stored, !value.isEmpty else {
            throw LocalAppError.message(L10n.text("请在设置中填写 {0} API Key。", AIProvider(rawValue: provider)?.displayName ?? provider))
        }
        return value
    }

    func export(from: Date, to: Date) -> String { MealExport.markdown(entries: meals, from: from, to: to, localize: { L10n.text($0) }) }
}

enum LocalAppError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(text) = self { return text }; return nil }
}
