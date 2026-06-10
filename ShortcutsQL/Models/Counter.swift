import Foundation
import Observation

/// A minimal observable model used to demonstrate state-driven SwiftUI views
/// and to give the unit-test suite something real to assert against.
@Observable
final class Counter {
    private(set) var count: Int

    init(count: Int = 0) {
        self.count = count
    }

    func increment() {
        count += 1
    }

    func decrement() {
        count -= 1
    }

    func reset() {
        count = 0
    }
}
