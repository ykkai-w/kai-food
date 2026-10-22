import SwiftUI
import KaiiFoodCore

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @AppStorage("kaii.selectedTab") private var selectedTab = 0
    var body: some View {
        TabView(selection: $selectedTab) {
            DiaryView().tabItem { Label(L10n.text("食记"), systemImage: "book.closed") }.tag(0)
            ChatView().tabItem { Label(L10n.text("问 AI"), systemImage: "bubble.left.and.bubble.right") }.tag(1)
            ExportView().tabItem { Label(L10n.text("导出"), systemImage: "square.and.arrow.up") }.tag(2)
            SettingsView().tabItem { Label(L10n.text("设置"), systemImage: "slider.horizontal.3") }.tag(3)
        }
        .alert(L10n.text("操作未完成"), isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button(L10n.text("好")) { store.error = nil }
            if !store.storageReady { Button(L10n.text("重新读取")) { store.reload() } }
        } message: { Text(store.error ?? "") }
    }
}

struct DiaryView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var date = Date()
    @State private var draft: MealEntry?
    @ScaledMetric(relativeTo: .largeTitle) private var energySize = 56
    @State private var editing: MealEntry?
    @State private var deleting: MealEntry?
    @State private var showFrequent = false
    private let kinds: [MealKind] = [.breakfast, .lunch, .dinner, .snack]
    private var entries: [MealEntry] { store.entries(on: date) }
    private var total: Nutrients { entries.reduce(Nutrients()) { $0 + $1.total } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    cover
                    DiaryDatePicker(selection: $date)
                    Button { showFrequent = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bookmark").font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.text("常用食物")).font(.headline)
                                Text(store.frequentFoods.isEmpty ? L10n.text("存下固定搭配，下次点一下就好") : L10n.text("{0} 个固定份量，随手记一餐", store.frequentFoods.count))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption)
                        }.padding(.vertical, 8).contentShape(Rectangle())
                    }.buttonStyle(.plain).foregroundStyle(Palette.accent).disabled(!store.storageReady)
                    if entries.isEmpty {
                        emptyPage
                        proteinSummary
                    } else {
                        dailySummary
                        proteinSummary
                        mealList
                        VStack(alignment: .leading, spacing: 14) {
                            Text(L10n.text("记下一餐")).font(.title3.weight(.medium))
                            MealQuickEntryView(compact: true, isEnabled: store.storageReady, onSelect: startMeal)
                        }
                    }
                    if !store.storageReady {
                        Text(L10n.text("食记读取失败，请到设置重新读取。")).foregroundStyle(.red).font(.callout)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 32)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.paper(scheme))
            .navigationTitle("")
            .sheet(item: $draft) { meal in MealEditor(existing: meal).environmentObject(store) }
            .sheet(item: $editing) { meal in MealEditor(existing: meal).environmentObject(store) }
            .sheet(isPresented: $showFrequent) { FrequentFoodsView(date: date).environmentObject(store) }
            .confirmationDialog(L10n.text("删除这条食记及本地照片？"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button(L10n.text("删除"), role: .destructive) { if let deleting { store.delete(deleting) }; deleting = nil }
            }
        }
    }

    private var cover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("kaii").font(.system(.largeTitle, design: .serif, weight: .medium))
                Text(L10n.text("食记")).font(.title3.weight(.medium))
                Spacer()
                if !typeSize.isAccessibilitySize {
                    Text(date.uiFormatted(.dateTime.weekday(.wide)))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }.foregroundStyle(Palette.accent)
            if typeSize.isAccessibilitySize {
                Text(date.uiFormatted(.dateTime.weekday(.wide)))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            GeometryReader { geometry in
                EditorialImage("MealHero")
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var emptyPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text(Calendar.current.isDateInToday(date) ? L10n.text("今天吃了什么？") : L10n.text("这天吃了什么？"))
                    .font(.system(.title2, design: .serif, weight: .medium))
                Text(L10n.text("选一餐，写下吃了什么，或拍张照片。"))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            MealQuickEntryView(isEnabled: store.storageReady, onSelect: startMeal)
        }.padding(.vertical, 4)
    }

    private var proteinSummary: some View {
        ProteinGoalView(protein: total.protein, hasEntries: !entries.isEmpty)
            .padding(20)
            .background(Palette.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }

    private var dailySummary: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(L10n.text("已记录合计")).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text(L10n.text("{0} 餐", entries.count)).font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(total.kcal.formatted(.number.precision(.fractionLength(0))))
                    .font(.system(size: energySize, weight: .regular, design: .serif))
                    .monospacedDigit().contentTransition(.numericText())
                Text("kcal").font(.body).foregroundStyle(.secondary)
            }.accessibilityElement(children: .combine)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 28) { macroDetails }
                VStack(alignment: .leading, spacing: 12) { macroDetails }
            }
            Divider()
        }
    }

    @ViewBuilder private var macroDetails: some View {
        summaryMetric(L10n.text("蛋白质"), total.protein)
        summaryMetric(L10n.text("碳水"), total.carbs)
        summaryMetric(L10n.text("脂肪"), total.fat)
    }

    private func summaryMetric(_ title: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text("\(value.formatted(.number.precision(.fractionLength(0...1)))) g")
                .font(.body.weight(.medium)).monospacedDigit()
        }.fixedSize(horizontal: true, vertical: false).accessibilityElement(children: .combine)
    }

    private var mealList: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(kinds.filter { kind in entries.contains { $0.kind == kind } }, id: \.self) { kind in
                let meals = entries.filter { $0.kind == kind }
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(kind.localizedTitle).font(.title3.weight(.medium))
                        Spacer()
                        Button { startMeal(kind) } label: {
                            Image(systemName: "plus").frame(width: 44, height: 44)
                        }.buttonStyle(.plain).foregroundStyle(Palette.accent)
                            .disabled(!store.storageReady)
                            .accessibilityLabel(L10n.text("添加{0}", kind.localizedTitle))
                    }
                    ForEach(meals) { meal in
                        Button { editing = meal } label: { mealRow(meal) }.buttonStyle(.plain)
                            .contextMenu {
                                Button(L10n.text("编辑")) { editing = meal }
                                Button(L10n.text("删除"), role: .destructive) { deleting = meal }
                            }
                    }
                    Divider()
                }
            }
        }
    }

    private func mealRow(_ meal: MealEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let file = meal.photoFilename, let data = LocalFiles.photo(file) {
                PhotoView(data: data).frame(height: 190).frame(maxWidth: .infinity)
                    .clipped().clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityHidden(true)
            }
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(meal.items.map(\.name).joined(separator: " · "))
                        .font(.body.weight(.medium)).multilineTextAlignment(.leading)
                    Text(L10n.text("{0} · 蛋白质 {1} g", meal.date.uiFormatted(date: .omitted, time: .shortened), meal.total.protein.formatted(.number.precision(.fractionLength(0...1)))))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 5) {
                    Text(meal.total.kcal.formatted(.number.precision(.fractionLength(0))))
                        .font(.title3).monospacedDigit()
                    Text("kcal").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }.accessibilityElement(children: .combine).accessibilityHint(L10n.text("编辑这一餐"))
    }

    private func startMeal(_ kind: MealKind) {
        draft = MealEntry(date: date, kind: kind, items: [], note: "")
    }

}
