import Testing
import Foundation
@testable import ShortcutsQL

@Suite("MySQL connection service")
struct MySQLConnectionServiceTests {
    @Test("A hostname is used for TLS server-name indication")
    func sniUsesHostnames() {
        #expect(MySQLConnectionService.sniHostname(for: "mysql.internal") == "mysql.internal")
        #expect(MySQLConnectionService.sniHostname(for: "db-1.example.com") == "db-1.example.com")
    }

    @Test("An IP literal is not sent as an SNI hostname")
    func sniSkipsIPLiterals() {
        // NIOSSL rejects IP literals as SNI names, which would turn a
        // connection to a bare address into a TLS error.
        #expect(MySQLConnectionService.sniHostname(for: "10.0.0.5") == nil)
        #expect(MySQLConnectionService.sniHostname(for: "127.0.0.1") == nil)
        #expect(MySQLConnectionService.sniHostname(for: "::1") == nil)
        #expect(MySQLConnectionService.sniHostname(for: "2001:db8::1") == nil)
    }

    @Test("A non-driver error still produces a readable message")
    func readableMessageForForeignError() {
        let error = NSError(domain: "test", code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Something went wrong."])
        #expect(MySQLConnectionService.readableMessage(for: error) == "Something went wrong.")
    }
}
