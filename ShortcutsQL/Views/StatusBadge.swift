import SwiftUI

/// Small tinted status pill with a leading dot (OK, INVALID SQL, …).
struct StatusBadge: View {
    enum Tone {
        case success
        case danger

        var color: Color {
            switch self {
            case .success: .green
            case .danger: .red
            }
        }
    }

    let text: String
    let tone: Tone

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tone.color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
        }
        .padding(.vertical, 2.5)
        .padding(.horizontal, 8)
        .foregroundStyle(tone.color)
        .background(tone.color.opacity(0.14), in: Capsule())
    }
}

/// Tinted capsule carrying a server's name in the server's color.
struct ServerBadge: View {
    let name: String
    let color: Color

    var body: some View {
        Text(name.uppercased())
            .font(.system(.caption2, design: .monospaced).weight(.semibold))
            .tracking(0.4)
            .padding(.vertical, 2.5)
            .padding(.horizontal, 9)
            .foregroundStyle(color)
            .background(color.opacity(0.16), in: Capsule())
    }
}

#Preview {
    VStack(spacing: 12) {
        StatusBadge(text: "OK", tone: .success)
        StatusBadge(text: "INVALID SQL", tone: .danger)
        ServerBadge(name: "prod-readonly", color: .blue)
    }
    .padding()
}
