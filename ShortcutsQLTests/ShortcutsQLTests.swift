import Testing
@testable import ShortcutsQL

@Suite("Counter")
struct CounterTests {
    @Test("Starts at zero by default")
    func startsAtZero() {
        let counter = Counter()
        #expect(counter.count == 0)
    }

    @Test("Respects a custom initial value")
    func customInitialValue() {
        let counter = Counter(count: 42)
        #expect(counter.count == 42)
    }

    @Test("Increment increases the count by one")
    func increment() {
        let counter = Counter()
        counter.increment()
        #expect(counter.count == 1)
    }

    @Test("Decrement decreases the count by one")
    func decrement() {
        let counter = Counter(count: 5)
        counter.decrement()
        #expect(counter.count == 4)
    }

    @Test("Reset returns the count to zero")
    func reset() {
        let counter = Counter(count: 10)
        counter.reset()
        #expect(counter.count == 0)
    }

    @Test("Repeated increments accumulate", arguments: [1, 3, 10])
    func repeatedIncrements(times: Int) {
        let counter = Counter()
        for _ in 0..<times {
            counter.increment()
        }
        #expect(counter.count == times)
    }
}
