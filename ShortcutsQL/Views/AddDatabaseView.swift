import SwiftUI

/// Add / Edit Database: server details with an engine picker, a color swatch
/// row, the server's databases, and Test connection (with a failure state).
/// Editing an existing server also offers a confirmed Delete Database action.
struct AddDatabaseView: View {
    let store: QueryStore
    let server: DatabaseServer?
    let notify: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var engine = "PostgreSQL"
    @State private var showEnginePicker = false
    @State private var host = ""
    @State private var port = ""
    @State private var user = ""
    @State private var password = ""
    @State private var color = ServerColor.blue
    @State private var databases: [String] = []
    @State private var newDatabase = ""
    @State private var revealPassword = false
    @State private var test = TestPhase.idle
    @State private var confirmDelete = false

    init(store: QueryStore, server: DatabaseServer? = nil, notify: @escaping (String) -> Void) {
        self.store = store
        self.server = server
        self.notify = notify
        guard let server else { return }
        let (host, port) = Self.splitHostPort(server.host)
        let credentials = store.credentials(for: server.id)
        _name = State(initialValue: server.name)
        _engine = State(initialValue: server.engine)
        _host = State(initialValue: host)
        _port = State(initialValue: port)
        _user = State(initialValue: credentials?.user ?? "")
        _password = State(initialValue: credentials?.password ?? "")
        _color = State(initialValue: server.color)
        _databases = State(initialValue: server.databases.map(\.name))
    }

    private var isEditing: Bool { server != nil }

    private enum TestPhase: Equatable {
        case idle
        case running
        case ok
        case failed(String)
    }

    // SQLite is test-only and ClickHouse is unsupported, so neither appears here.
    // MySQL, MariaDB, and SQL Server stay visible but aren't selectable yet.
    private static let engines: [PickerOption] = [
        PickerOption(id: "PostgreSQL", label: "PostgreSQL", subtitle: "default port 5432", systemImage: "server.rack"),
        PickerOption(id: "MySQL", label: "MySQL", subtitle: "default port 3306", systemImage: "server.rack", disabled: true),
        PickerOption(id: "MariaDB", label: "MariaDB", subtitle: "default port 3306", systemImage: "server.rack", disabled: true),
        PickerOption(id: "SQL Server", label: "SQL Server", subtitle: "default port 1433", systemImage: "server.rack", disabled: true),
    ]

    var body: some View {
        NavigationStack {
            Form {
                serverSection
                colorSection
                databasesSection
                connectionSection
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Text("Delete Database")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing ? "Edit Database" : "Add Database")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Delete \u{201C}\(name.isEmpty ? "this server" : name)\u{201D}? This can\u{2019}t be undone.",
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button("Delete Database", role: .destructive, action: deleteServer)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save)
                        .disabled(test != .ok)
                }
            }
            .onChange(of: host) { test = .idle }
            .onChange(of: password) { test = .idle }
            .onChange(of: port) { test = .idle }
            .onChange(of: user) { test = .idle }
            .onChange(of: engine) { test = .idle }
            .onChange(of: databases) { test = .idle }
            .sheet(isPresented: $showEnginePicker) {
                PickerSheetView(
                    title: "Engine",
                    options: Self.engines,
                    selection: engine,
                    onSelect: { engine = $0 }
                )
            }
        }
    }

    private var serverSection: some View {
        Section("Server") {
            TextField("prod-readonly", text: $name)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button {
                showEnginePicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .foregroundStyle(.secondary)
                    Text("Engine")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(engine)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            LabeledContent("Host") {
                TextField("db.internal", text: $host)
                    .monospacedField()
            }
            LabeledContent("Port") {
                TextField("5432", text: $port)
                    .monospacedField()
                    .keyboardType(.numberPad)
            }
            LabeledContent("User") {
                TextField("readonly", text: $user)
                    .monospacedField()
            }
            LabeledContent("Password") {
                HStack(spacing: 8) {
                    Group {
                        if revealPassword {
                            TextField("Required", text: $password)
                        } else {
                            SecureField("Required", text: $password)
                        }
                    }
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    Button {
                        revealPassword.toggle()
                    } label: {
                        Image(systemName: revealPassword ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(revealPassword ? "Hide password" : "Show password")
                }
            }
        }
    }

    private var colorSection: some View {
        Section("Color") {
            HStack(spacing: 14) {
                ForEach(ServerColor.allCases) { swatch in
                    Button {
                        color = swatch
                    } label: {
                        Circle()
                            .fill(swatch.color)
                            .frame(width: 30, height: 30)
                            .overlay {
                                if color == swatch {
                                    Circle()
                                        .stroke(Color.secondary, lineWidth: 2.5)
                                        .frame(width: 39, height: 39)
                                }
                            }
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Server color \(swatch.rawValue)")
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var databasesSection: some View {
        Section {
            ForEach(databases, id: \.self) { database in
                HStack(spacing: 12) {
                    Circle()
                        .fill(color.color)
                        .frame(width: 10, height: 10)
                    Text(database)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Button("Remove \(database)", systemImage: "xmark") {
                        databases.removeAll { $0 == database }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                }
            }
            TextField("e.g. app_billing", text: $newDatabase)
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("Add database", systemImage: "plus", action: addDatabase)
                .disabled(newDatabase.trimmingCharacters(in: .whitespaces).isEmpty)
        } header: {
            HStack {
                Text("Databases")
                Spacer()
                Text("\(databases.count) added")
            }
        }
    }

    private var connectionSection: some View {
        Section {
            Button {
                runTest()
            } label: {
                Label(test == .running ? "Testing…" : "Test",
                      systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .disabled(test == .running)

            switch test {
            case .ok:
                HStack(spacing: 10) {
                    StatusBadge(text: "CONNECTED", tone: .success)
                    Text("\(engine) · \(databases.first ?? "postgres") reachable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .failed(let message):
                VStack(alignment: .leading, spacing: 8) {
                    StatusBadge(text: "CONNECTION FAILED", tone: .danger)
                    ErrorMessageView(message: message)
                }
            case .idle, .running:
                EmptyView()
            }
        } header: {
            Text("Connection")
        } footer: {
            // Keep the footer always present: toggling it in/out recreates the
            // Section and makes the Form scroll back to the top on Test connection.
            Text("Credentials are stored in the iOS Keychain. Test before saving.")
        }
    }

    private func addDatabase() {
        let trimmed = newDatabase.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        databases.append(trimmed)
        newDatabase = ""
    }

    private func runTest() {
        test = .running
        let parameters = ConnectionParameters(
            host: host.trimmingCharacters(in: .whitespaces),
            port: Int(port.trimmingCharacters(in: .whitespaces)) ?? 5432,
            database: databases.first ?? "postgres",
            user: user.trimmingCharacters(in: .whitespaces),
            password: password
        )
        Task {
            do {
                try await PostgresConnectionService.testConnection(parameters)
                guard test == .running else { return }
                test = .ok
            } catch {
                guard test == .running else { return }
                test = .failed(error.localizedDescription)
            }
        }
    }

    private func save() {
        let saved = DatabaseServer(
            id: server?.id ?? "s\(Int(Date().timeIntervalSince1970 * 1000))",
            name: name.trimmingCharacters(in: .whitespaces),
            engine: engine,
            host: "\(host.trimmingCharacters(in: .whitespaces)):\(port)",
            color: color,
            databases: databases.map { ServerDatabase(name: $0) }
        )
        let credentials = ServerCredentials(
            user: user.trimmingCharacters(in: .whitespaces),
            password: password
        )
        store.saveServer(saved, credentials: credentials)
        dismiss()
        notify("Database server \u{201C}\(saved.name)\u{201D} saved.")
    }

    private func deleteServer() {
        guard let server else { return }
        store.deleteServer(id: server.id)
        dismiss()
        notify("Database server \u{201C}\(server.name)\u{201D} deleted.")
    }

    /// Splits a stored `host:port` value back into its parts for editing.
    private static func splitHostPort(_ combined: String) -> (host: String, port: String) {
        guard let separator = combined.lastIndex(of: ":") else { return (combined, "") }
        return (String(combined[..<separator]), String(combined[combined.index(after: separator)...]))
    }
}

private extension View {
    func monospacedField() -> some View {
        self
            .font(.system(.body, design: .monospaced))
            .multilineTextAlignment(.trailing)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
    }
}

#Preview {
    AddDatabaseView(store: QueryStore(), notify: { _ in })
}
