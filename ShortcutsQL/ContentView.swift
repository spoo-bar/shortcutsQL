import SwiftUI

struct ContentView: View {
    @State private var counter = Counter()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "swift")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                Text("Welcome to ShortcutsQL")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("\(counter.count)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .animation(.snappy, value: counter.count)
                    .accessibilityLabel("Count is \(counter.count)")

                HStack(spacing: 16) {
                    Button {
                        counter.decrement()
                    } label: {
                        Label("Decrement", systemImage: "minus")
                    }

                    Button {
                        counter.increment()
                    } label: {
                        Label("Increment", systemImage: "plus")
                    }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderedProminent)
                .font(.title2)
            }
            .padding()
            .navigationTitle("ShortcutsQL")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset", systemImage: "arrow.counterclockwise") {
                        counter.reset()
                    }
                    .disabled(counter.count == 0)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
