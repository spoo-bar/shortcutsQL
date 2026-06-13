import SwiftUI

/// App shell: Home / Database / Settings tabs, sheet presentation for the
/// query editor and Add Database, and transient save/delete feedback.
struct ContentView: View {
    @State private var store = QueryStore()
    @State private var activeSheet: ActiveSheet?
    @State private var toast: String?

    private enum ActiveSheet: Identifiable {
        case newQuery
        case editQuery(SavedQuery)
        case addServer
        case editServer(DatabaseServer)

        var id: String {
            switch self {
            case .newQuery: "new-query"
            case .editQuery(let query): "edit-\(query.id)"
            case .addServer: "add-server"
            case .editServer(let server): "edit-server-\(server.id)"
            }
        }
    }

    var body: some View {
        TabView {
            Tab("Home", systemImage: "chevron.left.forwardslash.chevron.right") {
                HomeView(
                    store: store,
                    onNew: { activeSheet = .newQuery },
                    onOpen: { activeSheet = .editQuery($0) }
                )
            }
            Tab("Database", systemImage: "cylinder.split.1x2") {
                DatabasesView(
                    store: store,
                    onAdd: { activeSheet = .addServer },
                    onEdit: { activeSheet = .editServer($0) }
                )
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .newQuery:
                QueryEditorView(store: store, query: nil, notify: showToast)
            case .editQuery(let query):
                QueryEditorView(store: store, query: query, notify: showToast)
            case .addServer:
                AddDatabaseView(store: store, server: nil, notify: showToast)
            case .editServer(let server):
                AddDatabaseView(store: store, server: server, notify: showToast)
            }
        }
        .overlay(alignment: .top) {
            if let toast {
                ToastView(text: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: toast) {
                        try? await Task.sleep(for: .seconds(2.6))
                        withAnimation(.snappy) { self.toast = nil }
                    }
            }
        }
    }

    private func showToast(_ text: String) {
        withAnimation(.snappy) { toast = text }
    }
}

private struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            .padding(.horizontal, 16)
    }
}

#Preview {
    ContentView()
}
