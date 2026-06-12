import SwiftUI

/// Add Database: server details with an engine picker, a color swatch row,
/// the server's databases, and Test connection (with a failure state).
struct AddDatabaseView: View {
    let store: QueryStore
    let notify: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = "prod-readonly"
    @State private var engine = "PostgreSQL"
    @State private var showEnginePicker = false
    @State private var host = "db.internal"
    @State private var port = "5432"
    @State private var user = "readonly"
    @State private var password = "hunter2hunter2"
    @State private var color = ServerColor.blue
    @State private var databases = ["app_production"]
    @State private var newDatabase = ""
    @State private var test = TestPhase.idle

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
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add Database")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save)
                        .disabled(databases.isEmpty)
                }
            }
            .onChange(of: host) { test = .idle }
            .onChange(of: password) { test = .idle }
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
                SecureField("Required", text: $password)
                    .multilineTextAlignment(.trailing)
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
        } footer: {
            Text("Note: databases on a server may use different credentials — per-database credentials aren\u{2019}t configurable yet.")
        }
    }

    private var connectionSection: some View {
        Section {
            Button {
                runTest()
            } label: {
                Label(test == .running ? "Testing…" : "Test connection",
                      systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .disabled(test == .running)

            switch test {
            case .ok:
                HStack(spacing: 10) {
                    StatusBadge(text: "CONNECTED", tone: .success)
                    Text("\(engine) · 38 ms · \(databases.count) database\(databases.count == 1 ? "" : "s") reachable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .failed(let message):
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        StatusBadge(text: "CONNECTION FAILED", tone: .danger)
                        Text("after 5,000 ms")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ErrorMessageView(message: message)
                }
            case .idle, .running:
                EmptyView()
            }
        } header: {
            Text("Connection")
        } footer: {
            if test == .idle {
                Text("Credentials are stored in the iOS Keychain. Test before saving. Tip: a host outside *.internal (or a blank password) previews the failure state.")
            }
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
        // Prototype rule: an unreachable host (outside *.internal) or a blank
        // password previews the failure state.
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        let failure: String?
        if password.trimmingCharacters(in: .whitespaces).isEmpty {
            failure = "FATAL: password authentication failed for user \"\(user)\"\nHINT: check the password stored for \(trimmedHost.isEmpty ? "this server" : trimmedHost)."
        } else if !trimmedHost.hasSuffix(".internal") {
            failure = "could not translate host name \"\(trimmedHost)\" to address:\nName or service not known"
        } else {
            failure = nil
        }
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            guard test == .running else { return }
            if let failure {
                test = .failed(failure)
            } else {
                test = .ok
            }
        }
    }

    private func save() {
        let server = DatabaseServer(
            id: "s\(Int(Date().timeIntervalSince1970 * 1000))",
            name: name.trimmingCharacters(in: .whitespaces),
            engine: engine,
            host: "\(host.trimmingCharacters(in: .whitespaces)):\(port)",
            user: user,
            color: color,
            databases: databases.map { ServerDatabase(name: $0) }
        )
        store.addServer(server)
        dismiss()
        notify("Database server \u{201C}\(server.name)\u{201D} saved.")
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
