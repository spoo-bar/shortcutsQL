import AppIntents

/// Registers the app's actions with the Shortcuts app and Siri.
struct ShortcutsQLAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RunSavedQueryIntent(),
            phrases: [
                "Run a \(.applicationName) query",
                "Run a query with \(.applicationName)",
            ],
            shortTitle: "Run Saved Query",
            systemImageName: "chevron.left.forwardslash.chevron.right"
        )
    }
}
