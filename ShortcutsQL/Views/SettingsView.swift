import SwiftUI

/// Settings: appearance only — intentionally sparse for now.
struct SettingsView: View {
    @AppStorage("appearance") private var appearanceRaw = AppearanceMode.auto.rawValue

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
