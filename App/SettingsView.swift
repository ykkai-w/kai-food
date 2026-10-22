import SwiftUI
import KaiiFoodCore

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @AppStorage(ProteinGoalPreference.key) private var proteinGoalGrams = 0.0
    @State private var editProteinGoal = false
    @State private var glmKey = ""
    @State private var deepseekKey = ""
    @State private var kimiKey = ""
    @State private var kimiSaved = false
    @State private var showWelcome = false
    @State private var glmSaved = false
    @State private var deepseekSaved = false
    @State private var checkingKeys = false
    @State private var keysChecked = false
    @State private var keyOperation: String?
    @State private var status: String?
    @State private var testing = false
    @State private var confirmTest = false
    @State private var clearKey: String?
    @State private var testTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(L10n.text("kaii 食记")).font(.system(.largeTitle, design: .serif))
                    Text("v1.0").font(.subheadline).foregroundStyle(.secondary)
                    Button(L10n.text("使用说明与 AI 设置")) { showWelcome = true }
                }
                Section(L10n.text("个人目标")) {
                    Button { editProteinGoal = true } label: {
                        HStack {
                            Text(L10n.text("每日蛋白质")).foregroundStyle(.primary)
                            Spacer()
                            Text(ProteinGoalPreference.isValid(proteinGoalGrams)
                                 ? "\(ProteinGoalPreference.formatted(proteinGoalGrams)) g"
                                 : L10n.text("未设置"))
                                .foregroundStyle(.secondary).monospacedDigit()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                }
                Section { LanguagePicker() }
                Section(L10n.text("AI 模型")) {
                    Picker(L10n.text("AI 服务"), selection: $store.settings.chatProvider) {
                        ForEach(AIProvider.allCases) { Text($0.displayName).tag($0) }
                    }
                    VStack(alignment: .leading) { Text(L10n.text("DeepSeek 对话模型")).font(.caption).foregroundStyle(.secondary); TextField(L10n.text("模型 ID"), text: $store.settings.deepseekModel).apiEntry() }
                    VStack(alignment: .leading) { Text(L10n.text("GLM 对话模型")).font(.caption).foregroundStyle(.secondary); TextField(L10n.text("模型 ID"), text: $store.settings.glmChatModel).apiEntry() }
                    VStack(alignment: .leading) { Text(L10n.text("GLM 视觉模型")).font(.caption).foregroundStyle(.secondary); TextField(L10n.text("模型 ID"), text: $store.settings.visionModel).apiEntry() }
                    VStack(alignment: .leading) { Text(L10n.text("Kimi 模型")).font(.caption).foregroundStyle(.secondary); TextField(L10n.text("模型 ID"), text: $store.settings.kimiModel).apiEntry() }
                    Text(L10n.text("记餐与对话使用所选服务。GLM 会按图文切换模型。")).font(.caption).foregroundStyle(.secondary)
                    Button(L10n.text("保存模型设置")) {
                        do { try store.saveSettings(); status = L10n.text("模型设置已保存。") } catch { status = L10n.error(error) }
                    }
                }
                Section("API Key") {
                    keySection("GLM", key: "glm", binding: $glmKey, saved: glmSaved)
                    keySection("DeepSeek", key: "deepseek", binding: $deepseekKey, saved: deepseekSaved)
                    keySection("Kimi", key: "kimi", binding: $kimiKey, saved: kimiSaved)
                    Text(L10n.text("Key 保存在本机钥匙串，调用费用由服务商收取。")).font(.caption).foregroundStyle(.secondary)
                    Button { confirmTest = true } label: { HStack { Text(L10n.text("测试当前对话模型")); if testing { ProgressView() } } }
                        .disabled(testing || checkingKeys || keyOperation != nil)
                    if let status { Text(status).font(.callout).textSelection(.enabled) }
                }
                Section(L10n.text("数据与隐私")) {
                    Text(L10n.text("食记、照片和对话保存在本机。使用 AI 时，确认后发送所选内容到对应服务商。上传照片会移除拍摄位置等元数据。"))
                    Text(L10n.text("卸载前请导出食记。设备备份按你的系统设置执行。"))
                    Button(L10n.text("重新读取本地记录")) { store.reload(); status = store.storageReady ? L10n.text("读取成功。") : L10n.text("读取失败，请保留原文件。") }
                    #if os(macOS)
                    Text(L10n.text("Mac 预览数据目录\n") + LocalFiles.directory.path).font(.caption).textSelection(.enabled)
                    #endif
                }.font(.subheadline)
                Section(L10n.text("模型文档")) {
                    Link(L10n.text("智谱官方文档"), destination: URL(string: "https://docs.bigmodel.cn/")!)
                    Link(L10n.text("DeepSeek 官方文档"), destination: URL(string: "https://api-docs.deepseek.com/")!)
                    Link(L10n.text("Kimi 官方文档"), destination: URL(string: "https://platform.kimi.com/docs/")!)
                }
            }.paperForm().navigationTitle(L10n.text("设置"))
                .sheet(isPresented: $editProteinGoal) { ProteinGoalEditor() }
                .sheet(isPresented: $showWelcome) { WelcomeView { showWelcome = false }.environmentObject(store) }
                .task { await refreshKeys() }
                .onDisappear { testTask?.cancel() }
                .alert(L10n.text("测试模型连接？"), isPresented: $confirmTest) {
                    Button(L10n.text("取消"), role: .cancel) {}
                    Button(L10n.text("测试")) { test() }
                } message: { Text(L10n.text("向当前模型发送一句连接测试，费用由你的 API 账户支付。")) }
                .confirmationDialog(L10n.text("从系统钥匙串移除这个 Key？"), isPresented: Binding(get: { clearKey != nil }, set: { if !$0 { clearKey = nil } }), titleVisibility: .visible) {
                    Button(L10n.text("移除"), role: .destructive) {
                        if let clearKey { removeKey(clearKey) }
                        clearKey = nil
                    }
                }
        }
    }

    @ViewBuilder private func keySection(_ name: String, key: String, binding: Binding<String>, saved: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name).font(.headline)
                Spacer()
                if checkingKeys || keyOperation == key { ProgressView().controlSize(.small) }
                Text(saved ? L10n.text("已保存") : (keysChecked ? L10n.text("未设置") : L10n.text("未确认")))
                    .font(.caption).foregroundStyle(.secondary)
            }
            SecureField(L10n.text("粘贴 {0} API Key", name), text: binding).apiEntry()
                .disabled(keyOperation != nil || testing)
            HStack {
                Button(L10n.text("保存 {0} Key", name)) {
                    saveKey(name, key: key, binding: binding)
                }.disabled(binding.wrappedValue.isEmpty || checkingKeys || keyOperation != nil || testing)
                Spacer()
                if saved {
                    Button(L10n.text("移除"), role: .destructive) { clearKey = key }
                        .disabled(checkingKeys || keyOperation != nil || testing)
                }
            }.buttonStyle(.borderless)
        }.padding(.vertical, 8)
    }

    @MainActor private func refreshKeys() async {
        guard !checkingKeys, keyOperation == nil else { return }
        checkingKeys = true
        defer { checkingKeys = false }
        do {
            let result = try await Task.detached(priority: .utility) {
                (try KeychainStore.contains("glm"), try KeychainStore.contains("deepseek"), try KeychainStore.contains("kimi"))
            }.value
            try Task.checkCancellation()
            glmSaved = result.0
            deepseekSaved = result.1
            kimiSaved = result.2
            keysChecked = true
        } catch {
            if !Task.isCancelled { status = L10n.error(error) }
        }
    }

    @MainActor private func saveKey(_ name: String, key: String, binding: Binding<String>) {
        guard !checkingKeys, keyOperation == nil, !testing else { return }
        let value = binding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 8, value.count <= 512, !value.contains(where: { $0.isWhitespace }) else {
            status = L10n.text("Key 格式有误，请重新复制。")
            return
        }
        keyOperation = key
        status = L10n.text("正在保存 {0} Key…", name)
        Task { @MainActor in
            defer { keyOperation = nil }
            do {
                try await Task.detached(priority: .userInitiated) { try KeychainStore.save(value, for: key) }.value
                binding.wrappedValue = ""
                setKeyPresence(true, for: key)
                status = L10n.text("{0} Key 已保存，可测试连接。", name)
            } catch { status = L10n.error(error) }
        }
    }

    @MainActor private func removeKey(_ key: String) {
        guard !checkingKeys, keyOperation == nil, !testing else { return }
        keyOperation = key
        status = L10n.text("正在移除 Key…")
        Task { @MainActor in
            defer { keyOperation = nil }
            do {
                try await Task.detached(priority: .userInitiated) { try KeychainStore.delete(key) }.value
                setKeyPresence(false, for: key)
                status = L10n.text("Key 已从本机移除。")
            } catch { status = L10n.error(error) }
        }
    }

    @MainActor private func setKeyPresence(_ exists: Bool, for key: String) {
        if key == "glm" { glmSaved = exists }
        else if key == "deepseek" { deepseekSaved = exists }
        else if key == "kimi" { kimiSaved = exists }
    }

    private func test() {
        guard !testing, !checkingKeys, keyOperation == nil else { return }
        let settings = store.settings
        testing = true
        testTask = Task { @MainActor in
            defer { testing = false }
            do {
                let key = try await store.key(for: settings.chatProvider.rawValue)
                try Task.checkCancellation()
                let result = try await store.client.chat(messages: [ChatMessage(role: "user", content: L10n.text("请只回复：连接成功。"))], context: L10n.text("这是 API 连接测试，没有食记。"), settings: settings, apiKey: key, language: L10n.language)
                try Task.checkCancellation()
                status = L10n.text("模型回复\n{0}", result.prefix(160))
            } catch { if !Task.isCancelled { status = L10n.error(error) } }
        }
    }
}
