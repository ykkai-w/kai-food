import SwiftUI
import KaiiFoodCore

struct ChatView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var input = ""
    @State private var includeDiary = false
    @State private var consent = false
    @State private var clear = false
    @State private var busy = false
    @State private var error: String?
    @State private var task: Task<Void, Never>?
    @FocusState private var inputFocused: Bool

    private var providerName: String { store.settings.chatProvider.displayName }
    private var modelName: String {
        switch store.settings.chatProvider {
        case .glm: return store.settings.glmChatModel == "glm-4.7-flashx" ? "GLM 4.7 FlashX" : L10n.text("GLM · 自定义")
        case .deepseek: return store.settings.deepseekModel == "deepseek-flash" ? "DeepSeek Flash" : L10n.text("DeepSeek · 自定义")
        case .kimi: return store.settings.kimiModel == "kimi-k2.6" ? "Kimi K2.6" : L10n.text("Kimi · 自定义")
        }
    }
    private var todayCount: Int { store.entries(on: Date()).count }
    private let deepBlue = Color(red: 0.012, green: 0.275, blue: 0.580)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 26) {
                            if store.messages.isEmpty {
                                welcome
                            }
                            ForEach(store.messages) { message in
                                messageRow(message).id(message.id)
                            }
                            if busy { ProgressView(L10n.text("正在想……")).font(.subheadline).padding(.vertical, 8) }
                            if let error {
                                Label(error, systemImage: "exclamationmark.circle")
                                    .font(.callout).foregroundStyle(.red).textSelection(.enabled)
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 20)
                            .frame(maxWidth: 720).frame(maxWidth: .infinity)
                    }.onChange(of: store.messages.count) { _, _ in withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
                        .onChange(of: busy) { _, _ in withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
                        .onAppear { if !store.messages.isEmpty { proxy.scrollTo("bottom", anchor: .bottom) } }
                }
            }.background(Palette.paper(scheme))
                .safeAreaInset(edge: .bottom, spacing: 0) { composer }
                .navigationTitle("")
                .alert(L10n.text("发送给 {0}？", providerName), isPresented: $consent) {
                    Button(L10n.text("取消"), role: .cancel) {}
                    Button(L10n.text("发送")) { send() }
                } message: {
                    Text(L10n.text("将发送当前问题和最近最多 20 条对话{0}。费用由你的 API 账户支付。", includeDiary ? L10n.text("，附上最近 7 天的文字食记（不含照片）") : ""))
                }
                .confirmationDialog(L10n.text("清除这台设备上的对话？"), isPresented: $clear, titleVisibility: .visible) {
                    Button(L10n.text("清除本地对话"), role: .destructive) { do { try store.setMessages([]) } catch { self.error = L10n.error(error) } }
                }
                .onDisappear { task?.cancel() }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(L10n.text("饮食助手")).font(.headline)
            Spacer()
            Menu {
                Section(L10n.text("切换对话模型")) {
                    modelChoice("GLM 4.7 FlashX", provider: .glm, model: "glm-4.7-flashx")
                    modelChoice("DeepSeek Flash", provider: .deepseek, model: "deepseek-flash")
                    modelChoice("Kimi K2.6", provider: .kimi, model: "kimi-k2.6")
                }
                Divider()
                Text(L10n.text("当前 ") + store.settings.model(for: store.settings.chatProvider))
            } label: {
                HStack(spacing: 5) {
                    Text(modelName).font(.caption.weight(.medium))
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                }.foregroundStyle(.secondary).padding(.vertical, 10).padding(.horizontal, 12)
                    .background(Palette.surface(scheme), in: Capsule())
            }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().disabled(busy || !store.storageReady)
                .accessibilityLabel(L10n.text("切换 AI 模型，当前 {0}", modelName))
            if !store.messages.isEmpty {
                Button { clear = true } label: {
                    Image(systemName: "square.and.pencil").frame(width: 44, height: 44)
                }.buttonStyle(.plain).foregroundStyle(.secondary).disabled(busy)
                    .accessibilityLabel(L10n.text("清除对话，重新开始"))
            }
        }.padding(.horizontal, 24).padding(.vertical, 12)
            .frame(maxWidth: 720).frame(maxWidth: .infinity)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.text("今天，\n怎么吃更好？"))
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        .tracking(-0.7).fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(L10n.text("从一餐开始，聊聊你的饮食。"))
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                if !typeSize.isAccessibilitySize {
                    EditorialImage("CloudLine").frame(width: 92, height: 92).clipped()
                }
            }.padding(.top, 8)
            Button {
                prepare(L10n.text("帮我看看今天的饮食搭配，并给我下一餐的建议。"))
            } label: {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Label(L10n.text("今日饮食"), systemImage: "fork.knife").font(.caption.weight(.medium))
                        Spacer()
                        if todayCount > 0 { Text(L10n.text("已记 {0} 餐", todayCount)).font(.caption) }
                    }.foregroundStyle(.white.opacity(0.78))
                    HStack(alignment: .bottom, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.text("看看今天吃得怎么样")).font(.title3.weight(.semibold))
                            Text(L10n.text("搭配、份量，还有下一餐"))
                                .font(.subheadline).foregroundStyle(.white.opacity(0.78))
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "arrow.up.right")
                            .font(.body.weight(.semibold)).frame(width: 38, height: 38)
                            .background(.white.opacity(0.15), in: Circle())
                    }
                }.foregroundStyle(.white).padding(22).frame(maxWidth: .infinity, alignment: .leading)
                    .background(deepBlue, in: RoundedRectangle(cornerRadius: 22))
            }.buttonStyle(.plain)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 18) {
                StickyPrompt(L10n.text("下一餐吃什么"), index: 0) { prepare(L10n.text("帮我想想下一餐吃什么，先问问我的口味和就餐条件。")) }
                StickyPrompt(L10n.text("蛋白质怎么补"), index: 1) { prepare(L10n.text("结合我记录的饮食，帮我看看蛋白质来源怎么搭配。")) }
                StickyPrompt(L10n.text("外卖怎么选"), index: 2) { prepare(L10n.text("我想点外卖，帮我选个好吃又均衡的搭配，先问问我想吃哪一类。")) }
                StickyPrompt(L10n.text("一周饮食复盘"), index: 3) { prepare(L10n.text("帮我回顾最近一周记录的饮食，挑出值得保持的搭配和最有用的改进建议。")) }
            }
            .padding(.top, 6).padding(.trailing, 4).padding(.bottom, 6)
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 14) {
                TextField(L10n.text("问问怎么吃，或说说今天的安排…"), text: $input, axis: .vertical)
                    .font(.body).lineLimit(2...5).textFieldStyle(.plain).focused($inputFocused)
                    .accessibilityLabel(L10n.text("输入饮食问题"))
                HStack(alignment: .center, spacing: 12) {
                    Toggle(isOn: $includeDiary) {
                        Label(L10n.text("近 7 天食记"), systemImage: includeDiary ? "checkmark.circle.fill" : "plus.circle")
                            .font(.caption.weight(.medium))
                    }.toggleStyle(.button).buttonStyle(.plain)
                        .foregroundStyle(includeDiary ? Palette.accent : .secondary)
                        .padding(.vertical, 10).padding(.horizontal, 12)
                        .background(Palette.accent.opacity(includeDiary ? 0.10 : 0.04), in: Capsule())
                        .disabled(busy).accessibilityLabel(L10n.text("附上最近 7 天文字食记"))
                    Spacer(minLength: 0)
                    Button {
                        if busy { task?.cancel() } else { inputFocused = false; consent = true }
                    } label: {
                        Image(systemName: busy ? "stop.fill" : "arrow.up")
                            .font(.headline).foregroundStyle(.white).frame(width: 44, height: 44)
                            .background(deepBlue.opacity(canSend || busy ? 1 : 0.28), in: Circle())
                    }.buttonStyle(.plain).disabled(!busy && !canSend)
                        .accessibilityLabel(busy ? L10n.text("停止生成") : L10n.text("发送问题"))
                }
            }.padding(18)
                .background(Palette.surface(scheme), in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Palette.accent.opacity(inputFocused ? 0.45 : 0.14), lineWidth: 1))
        }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 14)
            .frame(maxWidth: 720).frame(maxWidth: .infinity)
            .background(Palette.paper(scheme))
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && store.storageReady
    }

    @ViewBuilder private func messageRow(_ message: ChatMessage) -> some View {
        if message.role == "user" {
            HStack {
                Spacer(minLength: 32)
                Text(message.content).font(.body).textSelection(.enabled)
                    .padding(.horizontal, 18).padding(.vertical, 14)
                    .background(Palette.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 20))
            }.accessibilityElement(children: .combine).accessibilityLabel(L10n.text("我：{0}", message.content))
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("kaii").font(.system(.subheadline, design: .rounded, weight: .semibold)).foregroundStyle(Palette.accent)
                Text(ChatText.attributed(message.content)).font(.body).lineSpacing(5).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { copyText(message.content) } label: {
                    Label(L10n.text("复制"), systemImage: "doc.on.doc").font(.caption)
                        .padding(.vertical, 8)
                }.buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }
    }

    private func prepare(_ question: String) {
        input = question
        includeDiary = true
        inputFocused = true
    }

    private func modelChoice(_ title: String, provider: AIProvider, model: String) -> some View {
        let selected = store.settings.chatProvider == provider &&
            store.settings.model(for: provider) == model
        return Button { selectModel(provider, model: model) } label: {
            if selected { Label(title, systemImage: "checkmark") }
            else { Text(title) }
        }
    }

    private func selectModel(_ provider: AIProvider, model: String) {
        let previous = store.settings
        store.settings.chatProvider = provider
        if provider == .glm { store.settings.glmChatModel = model }
        else if provider == .deepseek { store.settings.deepseekModel = model }
        else { store.settings.kimiModel = model }
        do { try store.saveSettings() }
        catch { store.settings = previous; self.error = L10n.error(error) }
    }

    private func send() {
        let question = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        let settings = store.settings
        do {
            let isRetry = store.messages.last.map { $0.role == "user" && $0.content == question } ?? false
            let current = isRetry ? store.messages : store.messages + [ChatMessage(role: "user", content: question)]
            try store.setMessages(current)
            input = ""; busy = true; error = nil
            let end = Date()
            let start = Calendar.current.date(byAdding: .day, value: -6, to: end) ?? end
            let context = includeDiary ? store.export(from: start, to: end) : L10n.text("用户未授权附加食记。不要假设其摄入量。")
            task = Task { @MainActor in
                defer { busy = false }
                do {
                    let key = try await store.key(for: settings.chatProvider.rawValue)
                    let answer = try await store.client.chat(messages: Array(current.suffix(20)), context: context, settings: settings, apiKey: key, language: L10n.language)
                    try Task.checkCancellation()
                    try store.setMessages(current + [ChatMessage(role: "assistant", content: answer)])
                } catch {
                    if input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { input = question }
                    self.error = Task.isCancelled ? L10n.text("已停止，本次问题仍保留在记录中。") : L10n.error(error)
                }
            }
        } catch { self.error = L10n.error(error) }
    }
}
