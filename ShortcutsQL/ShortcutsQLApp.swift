import SwiftUI

@main
struct ShortcutsQLApp: App {
    @AppStorage("appearance") private var appearanceRaw = AppearanceMode.auto.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(AppearanceMode(rawValue: appearanceRaw)?.colorScheme)
        }
    }
}
