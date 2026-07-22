import SwiftUI

/// Settings: appearance only — intentionally sparse for now.
struct SettingsView: View {
    @AppStorage("appearance") private var appearanceRaw = AppearanceMode.auto.rawValue
    @AppStorage("historyEnabled") private var historyEnabled = false

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "ShortcutsQL \(short) (build \(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appearanceRaw) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("Enable History", isOn: $historyEnabled)
                } header: {
                    Text("History")
                } footer: {
                    Text("Retain the last few results of each query as it runs from Shortcuts, and add a \u{201C}Historical <query>\u{201D} action that returns them as JSON. Set how many results to keep per query when editing it.")
                }

                Section {
                    ContentUnavailableView(
                        "Nothing else here yet",
                        systemImage: "gearshape",
                        description: Text("More settings are coming soon.")
                    )
                    .listRowBackground(Color.clear)
                } footer: {
                    Text(version)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
