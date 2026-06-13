import SwiftUI

/// Syntax-highlighted SQL editor surface: wraps the Runestone-backed
/// `SQLEditorView` with the inset background and an invalid-state border.
struct SQLEditor: View {
    @Binding var text: String
    var invalid = false

    var body: some View {
        SQLEditorView(text: $text)
            .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                if invalid {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.red, lineWidth: 1)
                }
            }
    }
}

#Preview {
    @Previewable @State var sql = "SELECT count(*) AS signups\nFROM users\nWHERE created_at >= current_date;"
    SQLEditor(text: $sql)
        .padding()
}
