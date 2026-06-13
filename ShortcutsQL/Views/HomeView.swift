import SwiftUI

/// Home: every saved SQL query — name, tinted server badge, database, the
/// query body (collapsible when long), and last-run meta.
struct HomeView: View {
    let store: QueryStore
    let onNew: () -> Void
    let onOpen: (SavedQuery) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if store.queries.isEmpty {
                    ContentUnavailableView(
                        "No queries yet",
                        systemImage: "chevron.left.forwardslash.chevron.right",
                        description: Text("Tap + to write and save your first SQL query.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(store.queries) { query in
                                QueryCard(
                                    query: query,
                                    serverColor: store.server(named: query.serverName)?.color.color ?? .secondary,
                                    onOpen: { onOpen(query) }
                                )
                            }
                            Text("Saved queries run against their selected database.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 28)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Queries")
            .navigationSubtitle("\(store.queries.count) saved")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New query", systemImage: "plus", action: onNew)
                }
            }
        }
    }
}

private struct QueryCard: View {
    let query: SavedQuery
    let serverColor: Color
    let onOpen: () -> Void

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(query.name)
                            .font(.headline)
                        HStack(spacing: 7) {
                            ServerBadge(name: query.serverName, color: serverColor)
                            Text(query.database)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(serverColor)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
                CollapsibleSQLView(sql: query.sql)
                HStack(spacing: 7) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    if let ranAt = query.lastRanAt {
                        Text(Self.relativeFormatter.localizedString(for: ranAt, relativeTo: Date()))
                        if let rows = query.rowsLabel { Text("·"); Text(rows) }
                        if let duration = query.durationLabel { Text("·"); Text(duration) }
                    } else {
                        Text("Not run yet")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView(store: QueryStore(), onNew: {}, onOpen: { _ in })
}
