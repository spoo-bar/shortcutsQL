import SwiftUI

/// New Query / Edit Query: name the query, pick a server + database, write
/// SQL, run it read-only to preview the result, then save. Editing adds a
/// confirmed Delete Query action.
struct QueryEditorView: View {
    let store: QueryStore
    let query: SavedQuery?
    let notify: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var serverID: String
    @State private var database: String
    @State private var sql: String
    @State private var phase = RunPhase.idle
    @State private var activePicker: PickerKind?
    @State private var confirmDelete = false

    private enum RunPhase: Equatable {
        case idle
        case invalid(String)
        case running
        case failed(String)
        case tested
    }

    private enum PickerKind: String, Identifiable {
        case server, database
        var id: String { rawValue }
    }

    init(store: QueryStore, query: SavedQuery?, notify: @escaping (String) -> Void) {
        self.store = store
        self.query = query
        self.notify = notify
        let server = query.flatMap { q in store.servers.first { $0.name == q.serverName } }
            ?? store.servers[0]
        _name = State(initialValue: query?.name ?? "")
        _serverID = State(initialValue: server.id)
        _database = State(initialValue: query?.database ?? server.databases[0].name)
        _sql = State(initialValue: query?.sql ?? "")
    }

    private var isEditing: Bool { query != nil }

    private var server: DatabaseServer {
        store.servers.first { $0.id == serverID } ?? store.servers[0]
    }

    private var databaseUser: String { server.user(forDatabase: database) }

    private var canRun: Bool {
        !sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSave: Bool {
        canRun && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isInvalid: Bool {
        if case .invalid = phase { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Daily signups", text: $name)
                }

                Section("Database") {
                    Button {
                        activePicker = .server
                    } label: {
                        pickerRow(title: "Server", value: server.name) {
                            Circle()
                                .fill(server.color.color)
                                .frame(width: 10, height: 10)
                        }
                    }
                    Button {
                        activePicker = .database
                    } label: {
                        pickerRow(title: "Database", value: database) {
                            Image(systemName: "cylinder.split.1x2")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Query") {
                    SQLEditor(text: $sql, invalid: isInvalid)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section {
                    Button {
                        run()
                    } label: {
                        Label(phase == .running ? "Running…" : "Run query", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!canRun || phase == .running)
                } footer: {
                    if phase == .idle {
                        Text("Run the query read-only to preview its result, then Save.")
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                }

                resultSection

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Text("Delete Query")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing ? "Edit Query" : "New Query")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
            .onChange(of: sql) { phase = .idle }
            .sheet(item: $activePicker) { picker in
                switch picker {
                case .server:
                    PickerSheetView(
                        title: "Server",
                        options: store.servers.map {
                            PickerOption(id: $0.id, label: $0.name,
                                         subtitle: "\($0.engine) · \($0.host)", color: $0.color.color)
                        },
                        selection: serverID,
                        onSelect: selectServer
                    )
                case .database:
                    PickerSheetView(
                        title: "Database",
                        options: server.databases.map {
                            PickerOption(id: $0.name, label: $0.name,
                                         color: server.color.color)
                        },
                        selection: database,
                        onSelect: { database = $0; phase = .idle }
                    )
                }
            }
            .confirmationDialog(
                "Delete \u{201C}\(name.isEmpty ? "Untitled" : name)\u{201D}? This can\u{2019}t be undone.",
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button("Delete Query", role: .destructive, action: deleteQuery)
            }
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        switch phase {
        case .tested:
            let shape = ResultShape.shape(of: sql)
            if shape == .scalar {
                Section {
                    ScalarResultView()
                } header: {
                    ResultSectionHeader(badgeText: "OK", badgeTone: .success,
                                        meta: "\(MockResults.scalarCountLabel) · 84 ms")
                }
            } else {
                let table = MockResults.table(for: shape)
                Section {
                    ResultTableView(table: table)
                        .listRowInsets(EdgeInsets())
                } header: {
                    ResultSectionHeader(badgeText: "OK", badgeTone: .success,
                                        meta: "\(table.countLabel) · \(table.columns.count) cols · 84 ms")
                } footer: {
                    if shape == .wide {
                        Text("Swipe the table sideways to see all \(table.columns.count) columns.")
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        case .invalid(let message):
            Section {
                ErrorMessageView(message: message)
            } header: {
                ResultSectionHeader(badgeText: "INVALID SQL", badgeTone: .danger,
                                    meta: "not sent to server")
            }
        case .failed(let message):
            Section {
                ErrorMessageView(message: message)
            } header: {
                ResultSectionHeader(badgeText: "QUERY FAILED", badgeTone: .danger,
                                    meta: "after 5,000 ms")
            }
        case .idle, .running:
            EmptyView()
        }
    }

    private func pickerRow(
        title: String, subtitle: String? = nil, value: String,
        @ViewBuilder leading: () -> some View
    ) -> some View {
        HStack(spacing: 12) {
            leading()
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private func selectServer(_ id: String) {
        serverID = id
        database = server.databases[0].name
        phase = .idle
    }

    private func run() {
        if let error = SQLValidator.validate(sql) {
            phase = .invalid(error)
            return
        }
        phase = .running
        // Prototype rule: the staging server is unreachable — running against
        // it demonstrates the query-failure state.
        let failure = server.name == "staging"
            ? "could not connect to server: connection timed out\n\t\(server.host) · database \"\(database)\" as \"\(databaseUser)\""
            : nil
        Task {
            try? await Task.sleep(for: .milliseconds(850))
            guard phase == .running else { return }
            if let failure {
                phase = .failed(failure)
            } else {
                phase = .tested
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let shape = ResultShape.shape(of: sql)
        store.save(SavedQuery(
            id: query?.id ?? "q\(Int(Date().timeIntervalSince1970 * 1000))",
            name: trimmedName,
            serverName: server.name,
            database: database,
            sql: sql.trimmingCharacters(in: .whitespacesAndNewlines),
            lastRun: "just now",
            duration: "84 ms",
            rowsLabel: MockResults.rowsLabel(for: shape)
        ))
        dismiss()
        notify("Query \u{201C}\(trimmedName)\u{201D} \(isEditing ? "updated" : "saved").")
    }

    private func deleteQuery() {
        guard let query else { return }
        store.deleteQuery(id: query.id)
        dismiss()
        notify("Query \u{201C}\(query.name)\u{201D} deleted.")
    }
}

#Preview("New query") {
    QueryEditorView(store: QueryStore(), query: nil, notify: { _ in })
}

#Preview("Edit query") {
    QueryEditorView(store: QueryStore(), query: MockData.queries[3], notify: { _ in })
}
