import SwiftUI

/// A read-only, syntax-highlighted SQL block on an inset surface.
struct SQLCodeView: View {
    let sql: String

    var body: some View {
        SQLReadOnlyView(sql: sql)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.tertiarySystemGroupedBackground))
    }
}

/// Shows a query body; long queries (>9 lines) collapse behind a gradient
/// fade and a "Show full query" toggle.
struct CollapsibleSQLView: View {
    let sql: String

    @State private var expanded = false

    private static let collapsedHeight: CGFloat = 150

    private var isLong: Bool {
        sql.split(separator: "\n", omittingEmptySubsequences: false).count > 9
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SQLCodeView(sql: sql)
                .frame(maxHeight: isLong && !expanded ? Self.collapsedHeight : nil, alignment: .top)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(alignment: .bottom) {
                    if isLong, !expanded {
                        LinearGradient(
                            colors: [.clear, Color(.tertiarySystemGroupedBackground)],
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 56)
                        .allowsHitTesting(false)
                    }
                }
            if isLong {
                Button(expanded ? "Collapse" : "Show full query") {
                    withAnimation(.snappy) { expanded.toggle() }
                }
                .font(.footnote.weight(.medium))
                .buttonStyle(.borderless)
            }
        }
    }
}

#Preview {
    CollapsibleSQLView(sql: """
    -- monthly churn by signup cohort
    WITH cohorts AS (
      SELECT id, date_trunc('month', created_at) AS cohort
      FROM users
      WHERE created_at >= now() - interval '90 days'
    )
    SELECT c.cohort, count(*) AS total
    FROM cohorts c
    GROUP BY c.cohort
    ORDER BY c.cohort DESC;
    """)
    .padding()
}
