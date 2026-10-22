import SwiftUI
import KaiiFoodCore

struct WelcomeView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var scheme
    let onFinish: () -> Void
    @State private var provider: AIProvider = .glm
    @State private var key = ""
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                LanguagePicker().pickerStyle(.menu)
                Text(L10n.text("kaii 食记")).font(.system(size: 38, weight: .medium, design: .serif)).foregroundStyle(Palette.accent)
                EditorialImage("MealHero").frame(height: 140).clipped().clipShape(RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.text("把每天吃的，随手记下来。 ")).font(.title2.weight(.medium))
                    Text(L10n.text("拍照、写几句话，或者直接添加常吃的食物。记录可以一键导出，交给你自己的 AI 看看。"))
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 16) {
                    Text(L10n.text("选一家 AI 就够了")).font(.headline)
                    Picker(L10n.text("AI 服务"), selection: $provider) {
                        ForEach(AIProvider.allCases) { Text($0.displayName).tag($0) }
                    }.pickerStyle(.segmented).disabled(saving)
                    Text(L10n.text("推荐先用 GLM，已配好日常记餐模型。DeepSeek 和 Kimi 也可用于图文记餐与对话。"))
                        .font(.subheadline).foregroundStyle(.secondary)
                    Link(L10n.text("去 {0} 获取 API Key", provider.displayName), destination: provider.keyURL)
                    SecureField(L10n.text("粘贴你的 API Key"), text: $key).apiEntry().textFieldStyle(.roundedBorder).disabled(saving)
                    Text(L10n.text("Key 保存在本机，调用费用由你的 AI 账户支付。每次发送前会确认分享的内容。"))
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(20).background(Palette.surface(scheme), in: RoundedRectangle(cornerRadius: 16))
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.text("以默认 GLM 模型算一笔小账，这两个例子都不到一分钱。"))
                        Text(L10n.text("文字问答约 0.0025 元\nGLM 4.7 FlashX，假设输入 2,000、输出 500 tokens。"))
                        Text(L10n.text("照片识别约 0.00135 元\nGLM 4.6V FlashX，假设图片与文字合计输入 4,000、输出 500 tokens。"))
                        Text(L10n.text("各调用 100 次，合计约 0.385 元。输入包含问题、照片及附带的食记和对话，实际费用随用量变化，按服务商账单结算。"))
                        Text(L10n.text("按 2026 年 10 月 22 日官方标准价计算，输入均低于 32K，按无缓存命中计算。文字输入/输出每百万 tokens 为 0.5/3 元，视觉为 0.15/1.5 元。"))
                            .font(.caption).foregroundStyle(.secondary)
                        Link(L10n.text("查看 GLM 官方价格"), destination: URL(string: "https://docs.bigmodel.cn/cn/guide/start/pricing")!)
                    }.font(.subheadline).padding(.top, 12)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.text("用 AI 要花多少")).font(.headline)
                        Text(L10n.text("GLM 示例，每次约 0.00135～0.0025 元")).font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(20).background(Palette.surface(scheme), in: RoundedRectangle(cornerRadius: 16))
                if let error { Text(error).foregroundStyle(.red).font(.callout) }
                Button(action: save) {
                    HStack { Spacer(); Text(saving ? L10n.text("正在保存…") : L10n.text("保存并开始")); Spacer() }.padding(.vertical, 10)
                }.buttonStyle(.borderedProminent).disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saving || !store.storageReady)
                Button(L10n.text("先逛逛，稍后设置")) { key = ""; onFinish() }
                    .buttonStyle(.plain).frame(maxWidth: .infinity).foregroundStyle(Palette.accent).disabled(saving)
                Text(L10n.text("跳过后可以手动记餐、使用常用食物和导出记录。AI 设置随时可改。"))
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }.padding(26).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }.background(Palette.paper(scheme))
        #if os(macOS)
        .frame(minWidth: 450, minHeight: 720)
        #endif
    }

    private func save() {
        let value = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 16, value.count <= 1024, value.unicodeScalars.allSatisfy({ $0.value > 32 && $0.value < 127 }) else {
            error = L10n.text("请重新复制完整的 API Key。"); return
        }
        let selected = provider
        saving = true; error = nil
        Task { @MainActor in
            defer { saving = false }
            do {
                try await Task.detached { try KeychainStore.save(value, for: selected.rawValue) }.value
                let previous = store.settings
                store.settings.chatProvider = selected
                do { try store.saveSettings() } catch { store.settings = previous; throw error }
                key = ""; onFinish()
            } catch { self.error = L10n.error(error) }
        }
    }
}
