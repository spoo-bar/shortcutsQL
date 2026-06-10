import SwiftUI

/// Big mono number for single-aggregate results.
struct ScalarResultView: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(MockResults.scalarValue)
                .font(.system(size: 44, weight: .semibold, design: .monospaced))
            Text(MockResults.scalarUnit)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// Mono result table. Wide results scroll horizontally; numeric columns
/// are right-aligned in the syntax number color.
struct ResultTableView: View {
    let table: ResultTable

    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(table.columns, id: \.self) { column in
                        Text(column.name)
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.secondary)
                            .gridColumnAlignment(column.isNumeric ? .trailing : .leading)
                            .padding(.vertical, 7)
                            .padding(.horizontal, 10)
                    }
                }
                Divider()
                ForEach(table.rows.indices, id: \.self) { rowIndex in
                    GridRow {
                        ForEach(table.columns.indices, id: \.self) { columnIndex in
                            Text(table.rows[rowIndex][columnIndex])
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(table.columns[columnIndex].isNumeric ? Color.synNumber : .primary)
                                .padding(.vertical, 7)
                                .padding(.horizontal, 10)
                        }
                    }
                    if rowIndex < table.rows.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }
}

/// Postgres-style mono error message for invalid SQL or failed runs.
struct ErrorMessageView: View {
    let message: String

    var body: some View {
        Text("ERROR: \(message)")
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Section header row: "Result" plus a status badge and meta text.
struct ResultSectionHeader: View {
    let badgeText: String
    let badgeTone: StatusBadge.Tone
    let meta: String

    var body: some View {
        HStack {
            Text("Result")
            Spacer()
            StatusBadge(text: badgeText, tone: badgeTone)
            Text(meta)
                .font(.caption)
                .textCase(nil)
        }
    }
}

#Preview {
    Form {
        Section {
            ScalarResultView()
        } header: {
            ResultSectionHeader(badgeText: "OK", badgeTone: .success, meta: "1 row · 84 ms")
        }
        Section {
            ResultTableView(table: MockResults.wideTable)
                .listRowInsets(EdgeInsets())
        } header: {
            ResultSectionHeader(badgeText: "OK", badgeTone: .success, meta: "50 rows · 12 cols · 84 ms")
        }
        Section {
            ErrorMessageView(message: "syntax error at or near \"SELEC\"\nLINE 1: SELEC …\n        ^")
        } header: {
            ResultSectionHeader(badgeText: "INVALID SQL", badgeTone: .danger, meta: "not sent to server")
        }
    }
}
