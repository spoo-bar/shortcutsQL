import SwiftUI

/// New Query / Edit Query: name the query, pick a server + database, write
/// SQL, run it read-only to preview the result, then save. Editing adds a
/// confirmed Delete Query action.
struct QueryEditorView: View {
    let store: QueryStore
    let query: SavedQuery?
    let notify: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("historyEnabled") private var historyEnabled = false

    @State private var name: String
    @State private var serverID: String
    @State private var database: String
    @State private var sql: String
    @State private var historyLimit: Int
    @State private var phase = RunPhase.idle
    @State private var activePicker: PickerKind?
    @State private var confirmDelete = false
    @State private var lastRanAt: Date?

    private enum RunPhase: Equatable {
        case idle
        case invalid(String)
        case running
        case failed(String)
        case success(ResultTable, durationMilliseconds: Int)
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
            ?? store.servers.first
        _name = State(initialValue: query?.name ?? "")
        _serverID = State(initialValue: server?.id ?? "")
        _database = State(initialValue: query?.database ?? server?.databases.first?.name ?? "")
        _sql = State(initialValue: query?.sql ?? "")
        _historyLimit = State(initialValue: query?.historyLimit ?? SavedQuery.defaultHistoryLimit)
    }

    private var isEditing: Bool { query != nil }

    private var server: DatabaseServer? {
        store.servers.first { $0.id == serverID } ?? store.servers.first
    }

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
                        pickerRow(title: "Server", value: server?.name ?? "None") {
                            Circle()
                                .fill(server?.color.color ?? .secondary)
                                .frame(width: 10, height: 10)
                        }
                    }
                    .disabled(store.servers.isEmpty)
                    Button {
                        activePicker = .database
                    } label: {
                        pickerRow(title: "Database", value: database.isEmpty ? "None" : database) {
                            Image(systemName: "cylinder.split.1x2")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(server?.databases.isEmpty ?? true)
                }

                Section("Query") {
                    SQLEditor(text: $sql, invalid: isInvalid)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                if historyEnabled {
                    historySection
                }

                Section {
                    Button {
                        run()
                    } label: {
                        Label(phase == .running ? "Running…" : "Run", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!canRun || phase == .running)
                } footer: {
                    if phase == .idle {
                        Text("Run the query to preview its result, then Save")
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
                                         subtitle: "\($0.engine.rawValue) · \($0.host)", color: $0.color.color)
                        },
                        selection: serverID,
                        onSelect: selectServer
                    )
                case .database:
                    PickerSheetView(
                        title: "Database",
                        options: (server?.databases ?? []).map {
                            PickerOption(id: $0.name, label: $0.name,
                                         color: server?.color.color)
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
    private var historySection: some View {
        Section {
            Stepper(value: $historyLimit, in: 1...50) {
                HStack {
                    Text("Keep last")
                    Spacer()
                    Text(historyLimit == 1 ? "1 result" : "\(historyLimit) results")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            if let id = query?.id {
                let count = store.history(forQueryID: id).count
                if count > 0 {
                    Button(role: .destructive) {
                        store.clearHistory(forQueryID: id)
                        notify("History cleared.")
                    } label: {
                        HStack {
                            Text("Clear History")
                            Spacer()
                            Text(count == 1 ? "1 stored" : "\(count) stored")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("History")
        } footer: {
            Text("Each time this query runs from Shortcuts, its result is retained (up to the limit above) and returned by the \u{201C}Historical \(name.isEmpty ? "query" : name)\u{201D} action.")
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        switch phase {
        case .success(let table, let ms) where table.rows.isEmpty:
            Section {
                Text("Query ran successfully. No rows returned.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } header: {
                ResultSectionHeader(badgeText: "OK", badgeTone: .success, meta: "0 rows · \(ms) ms")
            }
        case .success(let table, let ms) where table.columns.count == 1 && table.rows.count == 1:
            Section {
                ScalarResultView(value: table.rows[0][0], unit: table.columns[0].name)
            } header: {
                ResultSectionHeader(badgeText: "OK", badgeTone: .success,
                                    meta: "\(table.countLabel) · \(ms) ms")
            }
        case .success(let table, let ms):
            Section {
                ResultTableView(table: table)
                    .listRowInsets(EdgeInsets())
            } header: {
                ResultSectionHeader(badgeText: "OK", badgeTone: .success,
                                    meta: "\(table.countLabel) · \(table.columns.count) cols · \(ms) ms")
            } footer: {
                if table.columns.count >= 8 {
                    Text("Swipe the table sideways to see all \(table.columns.count) columns.")
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
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
                                    meta: "not completed")
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
        database = store.servers.first { $0.id == id }?.databases.first?.name ?? ""
        phase = .idle
    }

    private func run() {
        if let error = SQLValidator.validate(sql, engine: server?.engine ?? .fallback) {
            phase = .invalid(error)
            return
        }
        guard let server else {
            phase = .failed("Select a server to run against.")
            return
        }
        guard let credentials = store.credentials(for: server.id) else {
            phase = .failed("No saved credentials for \u{201C}\(server.name)\u{201D}. Re-save it in the Database tab.")
            return
        }
        let endpoint = server.endpoint
        let parameters = ConnectionParameters(
            engine: server.engine,
            host: endpoint.host,
            port: endpoint.port,
            database: database.isEmpty ? server.engine.defaultDatabase : database,
            user: credentials.user,
            password: credentials.password
        )
        let sqlText = sql
        phase = .running
        Task {
            do {
                let result = try await DatabaseConnectionService.runQuery(sqlText, parameters)
                guard phase == .running else { return }
                let ranAt = Date()
                lastRanAt = ranAt
                phase = .success(result.table, durationMilliseconds: result.durationMilliseconds)
                // Persist run stats immediately for an already-saved query so
                // the Home screen reflects this execution.
                if let id = query?.id {
                    store.recordRun(queryID: id, at: ranAt,
                                    durationMilliseconds: result.durationMilliseconds,
                                    rowCount: result.table.rows.count)
                }
            } catch {
                guard phase == .running else { return }
                phase = .failed(error.localizedDescription)
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // Carry over any existing run stats; overwrite them if this session
        // produced a fresh successful run.
        var ranAt = query?.lastRanAt
        var durationMilliseconds = query?.durationMilliseconds
        var rowCount = query?.rowCount
        if case .success(let table, let ms) = phase {
            ranAt = lastRanAt
            durationMilliseconds = ms
            rowCount = table.rows.count
        }
        store.save(SavedQuery(
            id: query?.id ?? "q\(Int(Date().timeIntervalSince1970 * 1000))",
            name: trimmedName,
            serverName: server?.name ?? "",
            database: database,
            sql: sql.trimmingCharacters(in: .whitespacesAndNewlines),
            lastRanAt: ranAt,
            durationMilliseconds: durationMilliseconds,
            rowCount: rowCount,
            historyLimit: historyLimit
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
    QueryEditorView(
        store: QueryStore(),
        query: SavedQuery(
            id: "demo", name: "Daily signups", serverName: "", database: "",
            sql: "SELECT count(*) AS signups\nFROM users\nWHERE created_at >= current_date;",
            lastRanAt: nil, durationMilliseconds: nil, rowCount: nil
        ),
        notify: { _ in }
    )
}
