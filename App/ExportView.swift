import SwiftUI
import UniformTypeIdentifiers
import KaiiFoodCore

struct TextExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents, let text = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadCorruptFile) }
        self.text = text
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(text.utf8)) }
}

struct ExportView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var from = Calendar.current.startOfDay(for: Date())
    @State private var to = Date()
    @State private var share = false
    @State private var saveFile = false
    @State private var showMarkdown = false
    @State private var status: String?
    @State private var dateEndpoint: DateEndpoint?

    private enum DateEndpoint: String, Identifiable {
        case start, end
        var id: String { rawValue }
    }

    private var text: String { store.export(from: from, to: to) }
    private var days: Int {
        let calendar = Calendar.current
        return (calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)).day ?? -1) + 1
    }
    private var validRange: Bool { (1...MealExport.maximumDays).contains(days) }
    private var records: [MealEntry] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: from)
        guard let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: to)) else { return [] }
        return store.meals.filter { $0.date >= start && $0.date < end }.sorted { $0.date < $1.date }
    }
    private var isToday: Bool {
        Calendar.current.isDateInToday(from) && Calendar.current.isDateInToday(to)
    }
    private var isLastWeek: Bool {
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .day, value: -6, to: Date()) else { return false }
        return calendar.isDate(from, inSameDayAs: start) && calendar.isDateInToday(to)
    }
    private var dateRange: String {
        let start = from.uiFormatted(date: .abbreviated, time: .omitted)
        return Calendar.current.isDate(from, inSameDayAs: to)
            ? start : L10n.text("{0} 至 {1}", start, to.uiFormatted(date: .abbreviated, time: .omitted))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    cover
                    rangeSelection
                    preview
                    exportActions
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 36)
                .frame(maxWidth: 680).frame(maxWidth: .infinity)
            }
            .background(Palette.paper(scheme))
            .navigationTitle("")
                .sheet(item: $dateEndpoint) { endpoint in
                    switch endpoint {
                    case .start:
                        DiaryMonthPicker(selection: $from, title: L10n.text("开始日期"), in: Date.distantPast...to)
                    case .end:
                        DiaryMonthPicker(selection: $to, title: L10n.text("结束日期"), in: from...Date.distantFuture)
                    }
                }
                #if os(iOS)
                .sheet(isPresented: $share) { UISystemShare(items: [text]) }
                #endif
                .fileExporter(isPresented: $saveFile, document: TextExportDocument(text: text), contentType: .plainText, defaultFilename: L10n.text("kaii-食记.md")) { result in
                    switch result { case .success: status = L10n.text("文件已保存。"); case .failure(let error): status = L10n.error(error) }
                }
                .onChange(of: from) { _, _ in status = nil }
                .onChange(of: to) { _, _ in status = nil }
        }
    }

    private var cover: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    EditorialImage("ExportScene")
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                    if !typeSize.isAccessibilitySize {
                        Text(L10n.text("导出食记"))
                            .font(.system(.largeTitle, design: .serif, weight: .medium))
                            .foregroundStyle(Color(red: 0.035, green: 0.15, blue: 0.29))
                            .padding(.leading, 24)
                            .accessibilityAddTraits(.isHeader)
                    }
                }
            }
            .frame(height: typeSize.isAccessibilitySize ? 120 : 168)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            if typeSize.isAccessibilitySize {
                Text(L10n.text("导出食记"))
                    .font(.system(.largeTitle, design: .serif, weight: .medium))
                    .accessibilityAddTraits(.isHeader)
            }
            Text(L10n.text("一键导出，交给你常用的 AI 看看饮食搭配。"))
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var rangeSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 24) { rangePresets }
                    .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 0) { rangePresets }
            }
            Group {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        dateButton(L10n.text("开始"), date: from, endpoint: .start)
                        Image(systemName: "arrow.down")
                            .font(.caption).foregroundStyle(.tertiary).accessibilityHidden(true)
                        dateButton(L10n.text("结束"), date: to, endpoint: .end)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: 12) {
                        dateButton(L10n.text("开始"), date: from, endpoint: .start)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "arrow.right")
                            .font(.caption).foregroundStyle(.tertiary).accessibilityHidden(true)
                        dateButton(L10n.text("结束"), date: to, endpoint: .end)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .padding(.vertical, 4)
            Divider().overlay(Palette.accent.opacity(0.08))
            if !validRange {
                Text(L10n.text("请选择 1 至 {0} 天。", MealExport.maximumDays))
                    .font(.callout).foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder private var rangePresets: some View {
        rangeButton(L10n.text("今天"), selected: isToday) {
            from = Calendar.current.startOfDay(for: Date()); to = Date()
        }
        rangeButton(L10n.text("最近 7 天"), selected: isLastWeek) {
            to = Date()
            from = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: to)) ?? to
        }
    }

    private func dateButton(_ title: String, date: Date, endpoint: DateEndpoint) -> some View {
        Button { dateEndpoint = endpoint } label: {
            VStack(alignment: endpoint == .end && !typeSize.isAccessibilitySize ? .trailing : .leading, spacing: 4) {
                Text("\(title) · \(date.uiFormatted(.dateTime.year()))")
                    .font(.caption2).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(date.uiFormatted(.dateTime.month().day()))
                        .font(.subheadline.weight(.medium)).monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(.primary)
            }
            .padding(.vertical, 6).frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.text("{0}日期，{1}", title, date.uiFormatted(date: .complete, time: .omitted)))
        .accessibilityHint(L10n.text("打开月历"))
    }

    private func rangeButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title).font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                Rectangle().fill(selected ? Palette.accent : Color.clear).frame(height: 2)
                    .accessibilityHidden(true)
            }
            .fixedSize(horizontal: true, vertical: false)
            .frame(minHeight: 44)
            .foregroundStyle(selected ? Palette.accent : .secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var exportActions: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                copyText(text)
                status = L10n.text("已复制。")
            } label: {
                Label(L10n.text("复制食记"), systemImage: "doc.on.doc")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(scheme == .dark ? Color.black : Color.white)
                    .background(Palette.accent, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain).disabled(!validRange).opacity(validRange ? 1 : 0.45)
            Group {
                if typeSize.isAccessibilitySize {
                    VStack(spacing: 0) { secondaryActions }
                } else {
                    HStack(spacing: 28) { secondaryActions }
                }
            }.frame(maxWidth: .infinity)
                .buttonStyle(.plain).disabled(!validRange).opacity(validRange ? 1 : 0.45)
            if let status {
                Text(status).font(.caption).foregroundStyle(.secondary)
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    @ViewBuilder private var secondaryActions: some View {
        #if os(iOS)
        Button { share = true } label: { secondaryLabel(L10n.text("分享"), icon: "square.and.arrow.up") }
            .accessibilityHint(L10n.text("可存到备忘录或发送到其他 App"))
        #else
        ShareLink(item: text) { secondaryLabel(L10n.text("分享"), icon: "square.and.arrow.up") }
        #endif
        Button { saveFile = true } label: { secondaryLabel(L10n.text("保存 Markdown"), icon: "doc.text") }
    }

    private func secondaryLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline)
            .padding(.horizontal, 4).frame(minHeight: 44)
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.text("预览")).font(.caption.weight(.medium)).accessibilityAddTraits(.isHeader)
                    Spacer()
                    if validRange {
                        Text(L10n.text("{0} 天 · {1} 条食记", days, records.count)).font(.caption)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text("预览")).font(.caption.weight(.medium)).accessibilityAddTraits(.isHeader)
                    if validRange {
                        Text(L10n.text("{0} 天 · {1} 条食记", days, records.count)).font(.caption)
                    }
                }
            }.foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.text("kaii 食记")).font(.system(.title2, design: .serif, weight: .medium))
                    Text(dateRange).font(.caption).foregroundStyle(.secondary)
                }
                Rectangle().fill(Palette.accent.opacity(0.65)).frame(height: 1).accessibilityHidden(true)
                if records.isEmpty {
                    Text(L10n.text("未记录")).font(.body).foregroundStyle(.secondary).padding(.vertical, 4)
                } else {
                    ForEach(Array(records.prefix(4))) { meal in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(meal.kind.localizedTitle) · \(meal.date.uiFormatted(.dateTime.month().day().hour().minute()))")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(meal.items.map(\.name).joined(separator: "、"))
                                .font(.body).fixedSize(horizontal: false, vertical: true)
                            Text(L10n.text("{0} kcal · 蛋白质 {1} g", meal.total.kcal.formatted(.number.precision(.fractionLength(0...1))), meal.total.protein.formatted(.number.precision(.fractionLength(0...1)))))
                                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        }.accessibilityElement(children: .combine)
                        Divider()
                    }
                }
                if records.count > 4 {
                    Text(L10n.text("预览前 4 条食记")).font(.caption).foregroundStyle(.secondary)
                }
                DisclosureGroup(L10n.text("完整 Markdown"), isExpanded: $showMarkdown) {
                    Text(text).font(.system(.caption, design: .monospaced))
                        .lineSpacing(4).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                }.font(.subheadline).tint(Palette.accent)
            }
            .padding(typeSize.isAccessibilitySize ? 18 : 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface(scheme), in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(.primary.opacity(0.09)))
            .shadow(color: .black.opacity(scheme == .dark ? 0.12 : 0.035), radius: 12, x: 0, y: 6)
        }
    }

}
