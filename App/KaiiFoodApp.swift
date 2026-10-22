import SwiftUI

@main struct KaiiFoodApp: App {
    @StateObject private var store = AppStore()
    @AppStorage("kaii.welcome.v1") private var welcomeComplete = false
    @AppStorage(L10n.preferenceKey) private var language = "system"
    var body: some Scene {
        WindowGroup {
            Group {
                if welcomeComplete { RootView() }
                else { WelcomeView { welcomeComplete = true } }
            }.environmentObject(store)
                .environment(\.locale, L10n.locale)
                .environment(\.calendar, L10n.calendar)
                .id(language)
                .tint(Palette.accent)
                #if os(macOS)
                .frame(minWidth: 430, minHeight: 760)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 490, height: 850)
        #endif
    }
}
