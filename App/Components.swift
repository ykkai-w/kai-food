import SwiftUI
import KaiiFoodCore
#if os(iOS)
import UIKit
#else
import AppKit
#endif

enum Palette {
    static let accent: Color = {
        #if os(iOS)
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.50, green: 0.70, blue: 1.00, alpha: 1)
                : UIColor(red: 0.012, green: 0.275, blue: 0.580, alpha: 1)
        })
        #else
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.50, green: 0.70, blue: 1.00, alpha: 1)
                : NSColor(red: 0.012, green: 0.275, blue: 0.580, alpha: 1)
        })
        #endif
    }()
    static func paper(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.045, green: 0.065, blue: 0.10) : Color(red: 0.97, green: 0.98, blue: 0.99)
    }
    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.08, green: 0.11, blue: 0.16) : .white
    }
}

struct EditorialImage: View {
    let name: String
    init(_ name: String) { self.name = name }
    var body: some View {
        Group {
        #if os(iOS)
        if let image = EditorialAssets.image(named: name) {
            Image(uiImage: image).resizable().scaledToFill()
        }
        #else
        if let image = EditorialAssets.image(named: name) {
            Image(nsImage: image).resizable().scaledToFill()
        }
        #endif
        }.accessibilityHidden(true)
    }
}

private enum EditorialAssets {
    #if os(iOS)
    typealias PlatformImage = UIImage
    #else
    typealias PlatformImage = NSImage
    #endif
    private static let cache: NSCache<NSString, PlatformImage> = {
        let cache = NSCache<NSString, PlatformImage>()
        cache.countLimit = 12
        return cache
    }()

    static func image(named name: String) -> PlatformImage? {
        if let image = cache.object(forKey: name as NSString) { return image }
        #if SWIFT_PACKAGE
        let url = Bundle.module.url(forResource: name, withExtension: "png")
        #else
        let url = Bundle.main.url(forResource: name, withExtension: "png")
        #endif
        guard let url else { return nil }
        #if os(iOS)
        let image = UIImage(contentsOfFile: url.path)
        #else
        let image = NSImage(contentsOf: url)
        #endif
        if let image { cache.setObject(image, forKey: name as NSString) }
        return image
    }
}

struct PaperCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface(scheme), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.primary.opacity(0.09)))
    }
}

struct MacroRow: View {
    let nutrients: Nutrients
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: typeSize.isAccessibilitySize ? 2 : 4), alignment: .leading, spacing: 12) {
            metric(L10n.text("能量"), nutrients.kcal, "kcal")
            metric(L10n.text("蛋白质"), nutrients.protein, "g")
            metric(L10n.text("碳水"), nutrients.carbs, "g")
            metric(L10n.text("脂肪"), nutrients.fat, "g")
        }
    }
    func metric(_ title: String, _ value: Double, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value.formatted(.number.precision(.fractionLength(0...1))))
                .font(.system(.title3, design: .default, weight: .medium)).monospacedDigit()
            Text(unit).font(.caption2).foregroundStyle(.secondary)
        }.accessibilityElement(children: .combine)
    }
}

struct PhotoView: View {
    let data: Data
    var body: some View {
        #if os(iOS)
        if let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill() }
        #else
        if let image = NSImage(data: data) { Image(nsImage: image).resizable().scaledToFill() }
        #endif
    }
}

extension View {
    func paperForm() -> some View { modifier(PaperFormStyle()) }
    func numericEntry() -> some View {
        #if os(iOS)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }
    func apiEntry() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.never).autocorrectionDisabled()
        #else
        self.autocorrectionDisabled()
        #endif
    }
}

private struct PaperFormStyle: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content.formStyle(.grouped).scrollContentBackground(.hidden).background(Palette.paper(scheme))
    }
}

func copyText(_ value: String) {
    #if os(iOS)
    UIPasteboard.general.string = value
    #else
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
    #endif
}
