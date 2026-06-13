import Testing
import Foundation
@testable import ShortcutsQL

@Suite("Keychain credential storage")
struct KeychainStoreTests {
    /// A unique id per test so concurrently-run tests don't collide, with
    /// cleanup of the Keychain item afterwards.
    private func withTemporaryID(_ body: (String) -> Void) {
        let id = "test-\(UUID().uuidString)"
        defer { KeychainStore.delete(for: id) }
        body(id)
    }

    @Test("Saved credentials round-trip")
    func roundTrip() {
        withTemporaryID { id in
            let credentials = ServerCredentials(user: "readonly", password: "hunter2hunter2")
            #expect(KeychainStore.save(credentials, for: id))
            #expect(KeychainStore.read(for: id) == credentials)
        }
    }

    @Test("Saving again overwrites the previous value")
    func overwrite() {
        withTemporaryID { id in
            KeychainStore.save(ServerCredentials(user: "a", password: "1"), for: id)
            KeychainStore.save(ServerCredentials(user: "b", password: "2"), for: id)
            #expect(KeychainStore.read(for: id) == ServerCredentials(user: "b", password: "2"))
        }
    }

    @Test("Reading an unknown id returns nil")
    func missing() {
        #expect(KeychainStore.read(for: "test-does-not-exist-\(UUID().uuidString)") == nil)
    }

    @Test("Deleting removes the credentials")
    func delete() {
        withTemporaryID { id in
            KeychainStore.save(ServerCredentials(user: "a", password: "1"), for: id)
            KeychainStore.delete(for: id)
            #expect(KeychainStore.read(for: id) == nil)
        }
    }
}
