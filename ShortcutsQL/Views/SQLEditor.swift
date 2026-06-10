import SwiftUI

/// Syntax-highlighted SQL editor: a clear-text field layered over the same
/// highlighted rendering the read-only blocks use. Both layers share one
/// font and layout, so the colored text stays aligned while editing.
struct SQLEditor: View {
    @Binding var text: String
    var invalid = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("SELECT …")
                    .foregroundStyle(.tertiary)
            } else {
                Text(SQLHighlighter.highlighted(text))
            }
            TextField("", text: $text, axis: .vertical)
                .foregroundStyle(.clear)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.asciiCapable)
        }
        .font(.system(.footnote, design: .monospaced))
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
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
    @Previewable @State var sql = MockData.queries[0].sql
    SQLEditor(text: $sql)
        .padding()
}
