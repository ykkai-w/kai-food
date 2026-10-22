import SwiftUI
import PhotosUI
import KaiiFoodCore
#if os(iOS)
import UIKit
#endif

struct MealEditor: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var meal: MealEntry
    @State private var photo: Data?
    @State private var selection: PhotosPickerItem?
    @State private var camera = false
    @State private var newFood = false
    @State private var showFrequent = false
    @State private var favoriteFood: FoodItem?
    @State private var editingFood: FoodItem?
    @State private var mode: MealInputMethod = .description
    @State private var description = ""
    @State private var ocrText = ""
    @State private var busy = false
    @State private var photoBusy = false
    @State private var failure: String?
    @State private var confirmUpload = false
    @State private var confirmDiscard = false
    @State private var requestTask: Task<Void, Never>?

    init(date: Date = Date(), kind: MealKind = .lunch, existing: MealEntry? = nil) {
        _meal = State(initialValue: existing ?? MealEntry(date: date, kind: kind, items: [], note: ""))
        _description = State(initialValue: existing?.mealDescription ?? "")
        _mode = State(initialValue: existing?.photoFilename == nil ? .description : .photo)
    }

    private var displayedPhoto: Data? {
        photo ?? meal.photoFilename.flatMap { LocalFiles.photo($0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(L10n.text("时间"), selection: $meal.date)
                    Picker(L10n.text("餐次"), selection: $meal.kind) {
                        ForEach([MealKind.breakfast, .lunch, .dinner, .snack], id: \.self) { Text($0.localizedTitle).tag($0) }
                    }
                }
                Section {
                    Picker(L10n.text("记录方式"), selection: $mode) {
                        ForEach(MealInputMethod.allCases, id: \.self) { Text($0.localizedTitle).tag($0) }
                    }.pickerStyle(.segmented).disabled(busy || photoBusy)
                }
                Section {
                    if mode == .description {
                        Text(L10n.text("回想一下，这餐吃了什么？")).font(.headline)
                        TextField(L10n.text("餐食描述"), text: $description, prompt: Text(L10n.text("比如：中午吃了一碗米饭、一个卤鸡腿、半盘炒青菜。")), axis: .vertical)
                            .lineLimit(4...10).accessibilityLabel(L10n.text("餐食描述"))
                            .labelsHidden().multilineTextAlignment(.leading)
                            .disabled(busy)
                        Text(L10n.text("一碗、半份、几个都可以，记得多少就写多少。"))
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                    if let data = displayedPhoto {
                        PhotoView(data: data).frame(maxWidth: .infinity).frame(height: 210).clipped().clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    HStack(spacing: 20) {
                        PhotosPicker(selection: $selection, matching: .images) { Label(L10n.text("选照片"), systemImage: "photo") }.buttonStyle(.borderless)
                        #if os(iOS)
                        Button {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) { camera = true }
                            else { failure = L10n.text("相机不可用，请从相册选照片。") }
                        } label: { Label(L10n.text("拍照"), systemImage: "camera") }.buttonStyle(.borderless)
                        #endif
                        if photoBusy { ProgressView() }
                    }.disabled(busy || photoBusy)
                    if mode == .label {
                        Button { runOCR() } label: { Label(L10n.text("扫描标签文字"), systemImage: "text.viewfinder") }
                            .disabled(displayedPhoto == nil || busy || photoBusy)
                        TextEditor(text: $ocrText).frame(minHeight: 100).accessibilityLabel(L10n.text("标签文字")).disabled(busy)
                        Text(L10n.text("本机识别，可直接修改文字。")).font(.caption).foregroundStyle(.secondary)
                    }
                    TextField(mode == .photo ? L10n.text("补充份量、做法或酱汁（选填）") : L10n.text("食用量，如 200 mL 牛奶"), text: $description, axis: .vertical).lineLimit(2...5).disabled(busy)
                    }
                    Button { confirmUpload = true } label: {
                        HStack { Label(analysisTitle, systemImage: "sparkles"); Spacer(); if busy { ProgressView() } }
                            .padding(.vertical, 6)
                    }.buttonStyle(.borderedProminent).tint(Palette.accent)
                        .disabled(busy || photoBusy || !mode.canAnalyze(hasPhoto: displayedPhoto != nil, description: description, labelText: ocrText))
                    if busy { Button(L10n.text("取消识别")) { requestTask?.cancel() }.foregroundStyle(.secondary) }
                }
                Section {
                    Button { showFrequent = true } label: { Label(L10n.text("从常用食物添加"), systemImage: "bookmark") }
                    ForEach(meal.items) { item in
                        Button { editingFood = item } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { Text(item.name).foregroundStyle(.primary); Spacer(); Text("\(item.grams.formatted()) \(item.unit)").foregroundStyle(.secondary) }
                                Text(L10n.text("约 {0} kcal · 蛋白质 {1} g", item.nutrients.kcal.formatted(.number.precision(.fractionLength(0))), item.nutrients.protein.formatted())).font(.caption).foregroundStyle(.secondary)
                                Text(L10n.text(item.source) + (item.uncertainty.isEmpty ? "" : " · " + item.uncertainty)).font(.caption2).foregroundStyle(.secondary)
                            }
                        }.contextMenu { Button(L10n.text("存为常用食物")) { favoriteFood = item } }
                    }.onDelete { meal.items.remove(atOffsets: $0) }
                    Button { newFood = true } label: { Label(L10n.text("手动添加食物"), systemImage: "plus") }
                    if !meal.items.isEmpty { MacroRow(nutrients: meal.total).padding(.vertical, 10) }
                } header: { Text(meal.items.isEmpty ? L10n.text("这一餐") : L10n.text("确认这餐的食物")) } footer: { Text(L10n.text("点击食物可修改份量和营养，左滑删除。")) }
                .disabled(busy || photoBusy)
                Section(L10n.text("备注")) {
                    TextField(L10n.text("想记点什么？"), text: $meal.note, axis: .vertical).lineLimit(2...6)
                }
                if let failure { Section { Text(failure).font(.callout).foregroundStyle(.red) } }
            }.paperForm()
            .navigationTitle(L10n.text("记{0}", meal.kind.localizedTitle))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.text("取消")) { confirmDiscard = true } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("保存这餐")) { save() }.disabled(meal.items.isEmpty || busy || photoBusy || !store.storageReady)
                }
            }
            .interactiveDismissDisabled()
            .confirmationDialog(L10n.text("放弃修改？"), isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button(L10n.text("放弃修改"), role: .destructive) { requestTask?.cancel(); dismiss() }
            }
            .alert(meal.items.isEmpty ? L10n.text("生成营养草稿？") : L10n.text("重新估算这餐？"), isPresented: $confirmUpload) {
                Button(L10n.text("取消"), role: .cancel) {}
                Button(meal.items.isEmpty ? L10n.text("开始估算") : L10n.text("重新估算")) { analyze() }
            } message: {
                Text(L10n.text("将{0}发送给 {1}。{2}", mode == .description ? L10n.text("这段餐食描述") : mode == .photo ? L10n.text("所选照片和补充文字") : L10n.text("标签文字及食用量"), store.settings.chatProvider.displayName, meal.items.isEmpty ? L10n.text("估算后可修改份量，再保存。") : L10n.text("新结果会替换当前食物列表，保存前可修改。")))
            }
            .sheet(isPresented: $newFood) { FoodEditor { meal.items.append($0) } }
            .sheet(isPresented: $showFrequent) { FrequentFoodsView(date: meal.date, onChoose: { meal.items.append($0) }).environmentObject(store) }
            .sheet(item: $favoriteFood) { FrequentFoodEditor(food: $0).environmentObject(store) }
            .sheet(item: $editingFood) { item in
                FoodEditor(existing: item) { updated in if let i = meal.items.firstIndex(where: { $0.id == updated.id }) { meal.items[i] = updated } }
            }
            #if os(iOS)
            .sheet(isPresented: $camera) {
                CameraPicker(onPick: { data in photo = data; ocrText = ""; camera = false }, onCancel: { camera = false }, onError: { error in failure = L10n.error(error); camera = false })
            }
            #endif
            .onChange(of: selection) { _, selected in
                Task { @MainActor in
                    photoBusy = true
                    defer { photoBusy = false }
                    do {
                        guard let data = try await selected?.loadTransferable(type: Data.self) else { return }
                        photo = try PhotoNormalizer.jpeg(data: data)
                        ocrText = ""
                    } catch { failure = L10n.error(error) }
                }
            }
            .onDisappear { requestTask?.cancel() }
            #if os(macOS)
            .frame(minWidth: 460, minHeight: 720)
            #endif
        }
    }

    private func save() {
        meal.mealDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        do { try store.save(meal, photo: photo); dismiss() }
        catch { failure = L10n.error(error) }
    }

    private func runOCR() {
        guard let data = displayedPhoto else { return }
        busy = true; failure = nil
        requestTask = Task { @MainActor in
            defer { busy = false }
            do {
                let result = try await LocalOCR.recognize(data)
                try Task.checkCancellation()
                ocrText = result
                if result.isEmpty { failure = L10n.text("没识别到文字，请拍清楚营养表，或手动填写。") }
            } catch { if !Task.isCancelled { failure = L10n.error(error) } }
        }
    }

    private var analysisTitle: String {
        switch mode {
        case .description: return L10n.text("AI 估算这一餐")
        case .photo: return L10n.text("识别这一餐")
        case .label: return L10n.text("按标签换算")
        }
    }

    private func analyze() {
        guard mode.canAnalyze(hasPhoto: displayedPhoto != nil, description: description, labelText: ocrText) else { return }
        busy = true; failure = nil
        let image = mode == .photo ? displayedPhoto : nil
        let text = mode == .label ? L10n.text("这是营养标签 OCR，请仅按实际食用量换算，不确定单位或食用量时不要编造。\n实际食用：{0}\n标签：{1}", description, ocrText) : description
        let settings = store.settings
        requestTask = Task { @MainActor in
            defer { busy = false }
            do {
                let key = try await store.key(for: settings.chatProvider.rawValue)
                let result = try await store.client.analyze(photoJPEG: image, description: text, settings: settings, apiKey: key, language: L10n.language)
                try Task.checkCancellation()
                meal.items = result
            } catch { if !Task.isCancelled { failure = L10n.error(error) } }
        }
    }
}

struct FoodEditor: View {
    @Environment(\.dismiss) private var dismiss
    let existing: FoodItem?
    let onSave: (FoodItem) -> Void
    @State private var name: String
    @State private var grams: String
    @State private var kcal: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
    @State private var uncertainty: String
    @State private var unit: String
    @State private var per100 = false
    @State private var kilojoules = false
    @State private var error: String?

    init(existing: FoodItem? = nil, onSave: @escaping (FoodItem) -> Void) {
        self.existing = existing; self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _grams = State(initialValue: existing.map { String($0.grams) } ?? "")
        _kcal = State(initialValue: existing.map { String($0.nutrients.kcal) } ?? "")
        _protein = State(initialValue: existing.map { String($0.nutrients.protein) } ?? "")
        _carbs = State(initialValue: existing.map { String($0.nutrients.carbs) } ?? "")
        _fat = State(initialValue: existing.map { String($0.nutrients.fat) } ?? "")
        _uncertainty = State(initialValue: existing?.uncertainty ?? "")
        _unit = State(initialValue: existing?.unit ?? "g")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("食物与份量")) {
                    TextField(L10n.text("食物名称"), text: $name)
                    Picker(L10n.text("份量单位"), selection: $unit) { Text(L10n.text("克 g")).tag("g"); Text(L10n.text("毫升 mL")).tag("mL") }
                    numeric(L10n.text("食用量（{0}）", unit), $grams)
                    if existing == nil { Toggle(L10n.text("按标签每 100 g／mL 换算"), isOn: $per100) }
                    else {
                        Button(L10n.text("按新份量换算营养")) {
                            if let amount = Double(grams.replacingOccurrences(of: ",", with: ".")), let resized = existing?.resized(toGrams: amount) {
                                kcal = String(resized.nutrients.kcal); protein = String(resized.nutrients.protein)
                                carbs = String(resized.nutrients.carbs); fat = String(resized.nutrients.fat)
                                error = nil
                            } else { error = L10n.text("请填写合理的食用量。") }
                        }
                    }
                }
                Section(per100 ? L10n.text("每 100 g／mL 的营养") : L10n.text("整份营养")) {
                    if existing == nil { Toggle(L10n.text("能量单位为 kJ"), isOn: $kilojoules) }
                    numeric(kilojoules ? L10n.text("能量（kJ）") : L10n.text("能量（kcal）"), $kcal)
                    numeric(L10n.text("蛋白质（g）"), $protein)
                    numeric(L10n.text("碳水（g）"), $carbs)
                    numeric(L10n.text("脂肪（g）"), $fat)
                }
                Section {
                    TextField(L10n.text("补充来源或估算说明（选填）"), text: $uncertainty, axis: .vertical)
                    if per100 { Text(L10n.text("食用量与标签请使用相同单位。")).font(.caption).foregroundStyle(.secondary) }
                    if let error { Text(error).foregroundStyle(.red) }
                }
            }.paperForm().navigationTitle(existing == nil ? L10n.text("添加食物") : L10n.text("编辑食物"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(L10n.text("取消")) { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button(L10n.text("完成")) { submit() } }
                }
                #if os(macOS)
                .frame(minWidth: 450, minHeight: 600)
                #endif
        }
    }

    private func numeric(_ title: String, _ binding: Binding<String>) -> some View {
        HStack { Text(title); Spacer(); TextField(L10n.text("必填"), text: binding).numericEntry().multilineTextAlignment(.trailing).frame(maxWidth: 115).accessibilityLabel(title) }
    }

    private func submit() {
        let values = [grams, kcal, protein, carbs, fat].map { Double($0.replacingOccurrences(of: ",", with: ".")) }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              values.allSatisfy({ $0 != nil && $0!.isFinite && $0! >= 0 }), let amount = values[0], amount > 0 else {
            error = L10n.text("请填全名称和营养值，食用量需大于 0。"); return
        }
        let factor = per100 ? amount / 100 : 1
        let nutrients = Nutrients(kcal: values[1]! / (kilojoules ? 4.184 : 1) * factor, protein: values[2]! * factor, carbs: values[3]! * factor, fat: values[4]! * factor)
        let result = FoodItem(id: existing?.id ?? UUID(), name: name.trimmingCharacters(in: .whitespacesAndNewlines), grams: amount, unit: unit, nutrients: nutrients, source: per100 ? "标签换算" : (existing == nil ? "手动" : L10n.text("手动修正（原{0}）", existing!.source)), uncertainty: uncertainty)
        guard result.isValid else { error = L10n.text("数值不合理，请检查单位及小数点。"); return }
        onSave(result); dismiss()
    }
}
