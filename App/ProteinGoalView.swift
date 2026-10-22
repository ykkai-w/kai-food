import SwiftUI

enum ProteinGoalPreference {
    static let key = "kaii.proteinGoalGrams"

    static func isValid(_ value: Double) -> Bool {
        value.isFinite && (1...300).contains(value)
    }

    static func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}

struct ProteinGoalView: View {
    let protein: Double
    let hasEntries: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(ProteinGoalPreference.key) private var goalGrams = 0.0
    @State private var editGoal = false

    private var hasGoal: Bool { ProteinGoalPreference.isValid(goalGrams) }
    private var recordedProtein: Double { protein.isFinite ? max(protein, 0) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.text("蛋白质")).font(.title3.weight(.medium))
                    goalButton
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.text("蛋白质")).font(.title3.weight(.medium))
                    Spacer(minLength: 12)
                    goalButton
                }
            }
            if dynamicTypeSize.isAccessibilitySize {
                proteinDetails
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        proteinDetails.frame(minWidth: 200)
                        EditorialImage("DumbbellLine")
                            .frame(width: 80, height: 80)
                            .clipped()
                            .accessibilityHidden(true)
                    }
                    proteinDetails
                }
            }
        }
        .sheet(isPresented: $editGoal) { ProteinGoalEditor() }
    }

    private var goalButton: some View {
        Button(hasGoal ? L10n.text("调整目标") : L10n.text("设置目标")) { editGoal = true }
            .font(.subheadline).foregroundStyle(Palette.accent).buttonStyle(.plain)
    }

    private var proteinDetails: some View {
        VStack(alignment: .leading, spacing: 14) {
            if hasGoal {
                Text(hasEntries
                     ? L10n.text("已记录 {0} g / 目标 {1} g", ProteinGoalPreference.formatted(recordedProtein), ProteinGoalPreference.formatted(goalGrams))
                     : L10n.text("尚未记录 · 目标 {0} g", ProteinGoalPreference.formatted(goalGrams)))
                    .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ProgressView(value: hasEntries ? min(recordedProtein, goalGrams) : 0, total: goalGrams)
                    .tint(Palette.accent)
                    .accessibilityLabel(L10n.text("蛋白质目标"))
                    .accessibilityValue(hasEntries
                                        ? L10n.text("已记录 {0} 克，目标 {1} 克", ProteinGoalPreference.formatted(recordedProtein), ProteinGoalPreference.formatted(goalGrams))
                                        : L10n.text("尚未记录，目标 {0} 克", ProteinGoalPreference.formatted(goalGrams)))
            } else {
                Text(hasEntries ? L10n.text("已记录 {0} g", ProteinGoalPreference.formatted(recordedProtein)) : L10n.text("尚未记录"))
                    .font(.body).monospacedDigit().foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProteinGoalEditor: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ProteinGoalPreference.key) private var goalGrams = 0.0
    @State private var input = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("每日蛋白质目标")) {
                    HStack {
                        TextField(L10n.text("输入克数"), text: $input)
                            .numericEntry()
                            .accessibilityLabel(L10n.text("每日蛋白质目标，克"))
                        Text("g").foregroundStyle(.secondary)
                    }
                    if let error { Text(error).font(.callout).foregroundStyle(.red) }
                }
                Section {
                    Button(L10n.text("不设目标")) {
                        goalGrams = 0
                        dismiss()
                    }.foregroundStyle(.secondary)
                }
            }
            .paperForm()
            .navigationTitle(L10n.text("蛋白质目标"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.text("取消")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(L10n.text("保存")) { save() } }
            }
            .onAppear {
                if ProteinGoalPreference.isValid(goalGrams) {
                    input = goalGrams.formatted(.number.grouping(.never))
                }
            }
            .onChange(of: input) { _, _ in error = nil }
            #if os(macOS)
            .frame(minWidth: 380, minHeight: 300)
            #endif
        }
    }

    private func save() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(text), ProteinGoalPreference.isValid(value) else {
            error = L10n.text("请输入 1 到 300 之间的数值。")
            return
        }
        goalGrams = value
        dismiss()
    }
}
