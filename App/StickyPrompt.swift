import SwiftUI

/// Native counterpart of kai-local's .suggestions button and .paper-pin.
struct StickyPrompt: View {
    let title: String
    let index: Int
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    private let ink = Color(red: 0.094, green: 0.094, blue: 0.086)
    private let paper = Color(red: 1, green: 0.992, blue: 0.973)

    init(_ title: String, index: Int, action: @escaping () -> Void) {
        self.title = title; self.index = index; self.action = action
    }

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 2, bottomLeadingRadius: 7,
                               bottomTrailingRadius: 3, topTrailingRadius: 10)
    }
    private var angle: Double { [-0.45, 0, 0.45, 0.45][index % 4] }
    private var pinAngle: Double { [-6, 5, -3, 4][index % 4] }

    var body: some View {
        Button(action: action) {
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 25).padding(.trailing, 13).padding(.top, 20).padding(.bottom, 16)
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                .background {
                    shape.fill(paper)
                        .overlay(shape.strokeBorder(ink.opacity(hovering ? 0.25 : 0.12), lineWidth: 1))
                        .shadow(color: ink.opacity(0.06), radius: 0, x: 4, y: 5)
                }
                .overlay(alignment: .topLeading) {
                    PaperPin().rotationEffect(.degrees(pinAngle), anchor: .top)
                        .offset(x: index % 2 == 0 ? 10 : 12, y: -5)
                        .accessibilityHidden(true).allowsHitTesting(false)
                }
                .contentShape(shape)
        }.buttonStyle(.plain)
            .rotationEffect(.degrees(hovering && !reduceMotion ? -0.3 : angle))
            .offset(y: hovering && !reduceMotion ? -2 : (index == 1 ? 2 : 0))
            .onHover { hovering = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: hovering)
    }
}

private struct PaperPin: View {
    private let ink = Color(red: 0.094, green: 0.094, blue: 0.086)
    private let blue = Color(red: 0.255, green: 0.435, blue: 0.624)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Capsule().fill(ink).frame(width: 1, height: 12)
                .rotationEffect(.degrees(11), anchor: .top).offset(x: 6.5, y: 7)
            Rectangle().fill(blue).frame(width: 3.8, height: 4.5)
                .overlay(Rectangle().strokeBorder(ink, lineWidth: 0.7))
                .rotationEffect(.degrees(-8)).offset(x: 4.6, y: 4.5)
            Ellipse().fill(blue).frame(width: 6, height: 6)
                .overlay(Ellipse().strokeBorder(ink, lineWidth: 0.7))
                .shadow(color: ink.opacity(0.12), radius: 0, x: 0.8, y: 0.8)
                .offset(x: 3.5, y: 0)
        }.frame(width: 12, height: 21)
    }
}
