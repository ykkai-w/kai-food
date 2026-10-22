import SwiftUI
import KaiiFoodCore

struct MealQuickEntryView: View {
    var compact = false
    var isEnabled = true
    let onSelect: (MealKind) -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize

    private let kinds: [MealKind] = [.breakfast, .lunch, .dinner, .snack]
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 0), spacing: 14),
              count: typeSize.isAccessibilitySize ? 1 : 2)
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
            ForEach(kinds) { kind in
                Button { onSelect(kind) } label: {
                    Group {
                        if compact || typeSize.isAccessibilitySize {
                            HStack(spacing: 8) {
                                EditorialImage(artworkName(kind))
                                    .frame(width: 40, height: 40)
                                    .clipped().clipShape(RoundedRectangle(cornerRadius: 7))
                                Text(kind.localizedTitle).font(.body.weight(.medium))
                                Spacer(minLength: 0)
                                plus
                            }.padding(10)
                        } else {
                            VStack(spacing: 0) {
                                GeometryReader { geometry in
                                    let side = min(geometry.size.width, 180)
                                    EditorialImage(artworkName(kind))
                                        .frame(width: side, height: side)
                                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                                        .clipped()
                                }.frame(height: 120)
                                HStack {
                                    Text(kind.localizedTitle).font(.body.weight(.medium))
                                    Spacer(minLength: 4)
                                    plus
                                }.padding(.horizontal, 14).padding(.vertical, 12)
                            }
                        }
                    }
                    .foregroundStyle(Palette.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.surface(scheme))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.accent.opacity(0.12), lineWidth: 1))
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1 : 0.5)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L10n.text("添加{0}", kind.localizedTitle))
                .accessibilityHint(L10n.text("打开这一餐的记录页面"))
            }
        }
    }

    private var plus: some View {
        Image(systemName: "plus")
            .font(.subheadline.weight(.medium))
            .frame(width: 24, height: 24)
            .background(Palette.accent.opacity(0.07), in: Circle())
            .accessibilityHidden(true)
    }

    private func artworkName(_ kind: MealKind) -> String {
        switch kind {
        case .breakfast: return "MealBreakfast"
        case .lunch: return "MealLunch"
        case .dinner: return "MealDinner"
        case .snack: return "MealSnack"
        }
    }
}
