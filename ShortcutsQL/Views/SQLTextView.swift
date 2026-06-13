import SwiftUI
@preconcurrency import Runestone
import TreeSitterSQLRunestone

/// Shared Runestone configuration for the SQL surfaces. Main-actor isolated
/// because `TextView`'s properties are; only called from the representables'
/// main-actor `makeUIView`/`updateUIView`.
@MainActor
private func makeConfiguredTextView() -> TextView {
    let textView = TextView()
    textView.backgroundColor = .clear
    textView.showLineNumbers = false
    textView.lineHeightMultiplier = 1.2
    textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
    textView.autocorrectionType = .no
    textView.autocapitalizationType = .none
    textView.smartQuotesType = .no
    textView.smartDashesType = .no
    textView.smartInsertDeleteType = .no
    textView.spellCheckingType = .no
    return textView
}

private func sqlState(_ text: String) -> TextViewState {
    TextViewState(text: text, theme: SQLTheme(), language: .sql)
}

/// Editable, syntax-highlighted SQL editor backed by Runestone.
struct SQLEditorView: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> TextView {
        let textView = makeConfiguredTextView()
        textView.editorDelegate = context.coordinator
        textView.isEditable = true
        textView.keyboardType = .asciiCapable
        textView.setState(sqlState(text))
        return textView
    }

    func updateUIView(_ textView: TextView, context: Context) {
        if textView.text != text {
            textView.setState(sqlState(text))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency TextViewDelegate {
        private let text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textViewDidChange(_ textView: TextView) {
            text.wrappedValue = textView.text
        }
    }
}

/// Read-only, syntax-highlighted SQL that sizes itself to its content so it
/// can sit inside a SwiftUI `ScrollView` / `Form` without nested scrolling.
struct SQLReadOnlyView: View {
    let sql: String

    @State private var height: CGFloat = 0

    var body: some View {
        Representable(text: sql, height: $height)
            .frame(height: max(height, 1))
    }

    private struct Representable: UIViewRepresentable {
        let text: String
        @Binding var height: CGFloat

        func makeUIView(context: Context) -> TextView {
            let textView = makeConfiguredTextView()
            textView.isEditable = false
            textView.isSelectable = true
            textView.isScrollEnabled = false
            textView.setState(sqlState(text))
            return textView
        }

        func updateUIView(_ textView: TextView, context: Context) {
            if textView.text != text {
                textView.setState(sqlState(text))
            }
            let measured = textView.contentSize.height
            if abs(measured - height) > 0.5 {
                DispatchQueue.main.async { height = measured }
            }
        }
    }
}
