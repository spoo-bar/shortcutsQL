import SwiftUI

struct PickerOption: Identifiable {
    let id: String
    let label: String
    var subtitle: String?
    var color: Color?
    var systemImage: String?
    /// When true the row stays visible but isn't selectable, with a
    /// "Not supported yet" note in place of the checkmark.
    var disabled: Bool = false
}

/// iOS "dropdown": a sheet listing options with a checkmark on the
/// selected one. Pair with a tappable row showing the current value.
struct PickerSheetView: View {
    let title: String
    let options: [PickerOption]
    let selection: String
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(options) { option in
                Button {
                    onSelect(option.id)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        if let color = option.color {
                            Circle()
                                .fill(color)
                                .frame(width: 10, height: 10)
                        } else if let systemImage = option.systemImage {
                            Image(systemName: systemImage)
                                .foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.label)
                                .foregroundStyle(option.disabled ? .secondary : .primary)
                            if let subtitle = option.subtitle {
                                Text(subtitle)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if option.disabled {
                            Text("Not supported yet")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else if option.id == selection {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .disabled(option.disabled)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    PickerSheetView(
        title: "Server",
        options: MockData.servers.map {
            PickerOption(id: $0.id, label: $0.name, subtitle: "\($0.engine) · \($0.host)", color: $0.color.color)
        },
        selection: "prod",
        onSelect: { _ in }
    )
}
