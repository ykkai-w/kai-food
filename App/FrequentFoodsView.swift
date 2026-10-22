import SwiftUI
import KaiiFoodCore

struct FrequentFoodsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State var date: Date
    var onChoose: ((FoodItem) -> Void)? = nil
    @State private var kind: MealKind = .breakfast
    @State private var adding = false
    @State private var editing: FrequentFood?
    @State private var deleting: FrequentFood?
    @State private var lastAdded: MealEntry?
    @State private var notice: String?
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            List {
                if onChoose == nil {
                    Section {
                        DatePicker(L10n.text("加入哪天"), selection: $date, displayedComponents: .date)
                        Picker(L10n.text("餐次"), selection: $kind) { ForEach(MealKind.allCases) { Text($0.localizedTitle).tag($0) } }
                    }
                }
                Section {
                    if store.frequentFoods.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.text("常吃的，存一份就好。 ")).font(.title3.weight(.medium))
                            Text(L10n.text("比如一勺蛋白粉、两个鸡蛋。填好品牌、份量和营养，下次直接添加。"))
                                .foregroundStyle(.secondary)
                        }.padding(.vertical, 12)
                    }
                    ForEach(store.frequentFoods) { value in
                        HStack(spacing: 14) {
                            Button { editing = value } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(value.food.name).foregroundStyle(.primary).font(.headline)
                                    Text("\(value.portion) · \(value.food.grams.formatted()) \(value.food.unit)")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                    Text(L10n.text("{0} kcal · 蛋白质 {1} g", value.food.nutrients.kcal.formatted(), value.food.nutrients.protein.formatted()))
                                        .font(.caption).foregroundStyle(.secondary)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.plain).accessibilityHint(L10n.text("编辑常用食物"))
                            Button { add(value) } label: {
                                Image(systemName: "plus.circle.fill").font(.title).frame(width: 44, height: 44)
                            }.buttonStyle(.borderless).accessibilityLabel(L10n.text("添加{0} {1}", value.food.name, value.portion))
                        }.padding(.vertical, 6)
                            .contextMenu { Button(L10n.text("编辑")) { editing = value }; Button(L10n.text("删除"), role: .destructive) { deleting = value } }
                    }.onDelete { offsets in if let index = offsets.first { deleting = store.frequentFoods[index] } }
                    Button { adding = true } label: { Label(L10n.text("新建常用食物"), systemImage: "plus") }
                }
                if let notice {
                    Section {
                        HStack {
                            Text(notice)
                            Spacer()
                            if let lastAdded { Button(L10n.text("撤销")) { store.delete(lastAdded); self.lastAdded = nil; self.notice = nil } }
                        }
                    }
                }
                if let failure { Text(failure).foregroundStyle(.red) }
            }.paperForm().navigationTitle(L10n.text("常用食物"))
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.text("完成")) { dismiss() } } }
                .sheet(isPresented: $adding) { FrequentFoodEditor().environmentObject(store) }
                .sheet(item: $editing) { FrequentFoodEditor(existing: $0).environmentObject(store) }
                .confirmationDialog(L10n.text("删除这个常用食物？"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                    Button(L10n.text("删除"), role: .destructive) {
                        do { if let deleting { try store.deleteFrequent(deleting.id) }; deleting = nil }
                        catch { failure = L10n.error(error) }
                    }
                } message: { Text(L10n.text("已保存的食记会保留。")) }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 580)
        #endif
    }

    private func add(_ value: FrequentFood) {
        guard let food = value.item() else { return }
        if let onChoose { onChoose(food); dismiss(); return }
        let meal = MealEntry(date: date, kind: kind, items: [food], note: value.portion)
        do {
            try store.save(meal, photo: nil)
            lastAdded = meal; notice = L10n.text("已加入{0} · {1}", kind.localizedTitle, value.food.name); failure = nil
        } catch { failure = L10n.error(error) }
    }
}

struct FrequentFoodEditor: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let existing: FrequentFood?
    @State private var food: FoodItem?
    @State private var portion: String
    @State private var editFood = false
    @State private var error: String?
    init(existing: FrequentFood? = nil, food: FoodItem? = nil) {
        self.existing = existing
        _food = State(initialValue: existing?.food ?? food)
        _portion = State(initialValue: existing?.portion ?? L10n.text("1 份"))
    }
    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("固定份量")) {
                    TextField(L10n.text("例如 1 勺、2 个、1 瓶"), text: $portion)
                    Text(L10n.text("填写这份食物的重量和营养。包装食品可以按标签换算。"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    if let food {
                        Text(food.name).font(.headline)
                        Text("\(food.grams.formatted()) \(food.unit)")
                        MacroRow(nutrients: food.nutrients)
                    }
                    Button(food == nil ? L10n.text("填写食物与营养") : L10n.text("编辑食物与营养")) { editFood = true }
                }
                if let error { Text(error).foregroundStyle(.red) }
            }.paperForm().navigationTitle(existing == nil ? L10n.text("存为常用食物") : L10n.text("编辑常用食物"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(L10n.text("取消")) { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button(L10n.text("保存")) {
                        guard let food else { return }
                        do {
                            try store.saveFrequent(FrequentFood(id: existing?.id ?? UUID(), food: food, portion: portion.trimmingCharacters(in: .whitespacesAndNewlines)))
                            dismiss()
                        } catch { self.error = L10n.error(error) }
                    }.disabled(food == nil || portion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }
                .sheet(isPresented: $editFood) { FoodEditor(existing: food) { food = $0 } }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 580)
        #endif
    }
}
