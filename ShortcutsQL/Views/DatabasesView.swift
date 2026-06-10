import SwiftUI

/// Database tab: every configured server, its engine/host and database
/// count. + presents Add Database.
struct DatabasesView: View {
    let store: QueryStore
    let onAdd: () -> Void

    private var databaseCount: Int {
        store.servers.reduce(0) { $0 + $1.databases.count }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.servers) { server in
                        Button(action: onAdd) {
                            HStack(spacing: 12) {
                                Image(systemName: "cylinder.split.1x2")
                                    .foregroundStyle(server.color.color)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(server.name)
                                        .foregroundStyle(.primary)
                                    Text("\(server.engine) · \(server.host)")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(server.databases.count == 1
                                     ? "1 database"
                                     : "\(server.databases.count) databases")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                } header: {
                    Text("Servers")
                } footer: {
                    Text("Credentials are stored in the iOS Keychain, never synced in plaintext.")
                }
            }
            .navigationTitle("Database")
            .navigationSubtitle("\(store.servers.count) servers · \(databaseCount) databases")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add database server", systemImage: "plus", action: onAdd)
                }
            }
        }
    }
}

#Preview {
    DatabasesView(store: QueryStore(), onAdd: {})
}
