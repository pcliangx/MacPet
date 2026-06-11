import XCTest
@testable import SoulCore

final class KeychainStoreTests: XCTestCase {
    let service = "com.mpet.test.keychain"
    override func setUp() { super.setUp(); KeychainStore.delete(service: service, account: "test-key") }

    func testSaveAndLoad() {
        let store = KeychainStore(service: service)
        XCTAssertTrue(store.save("my-secret-api-key", account: "test-key"))
        XCTAssertEqual(store.load(account: "test-key"), "my-secret-api-key")
    }
    func testDelete() {
        let store = KeychainStore(service: service)
        _ = store.save("secret", account: "test-key")
        XCTAssertTrue(store.delete(account: "test-key"))
        XCTAssertNil(store.load(account: "test-key"))
    }
    func testLoadNonexistentReturnsNil() {
        XCTAssertNil(KeychainStore(service: service).load(account: "nonexistent-\(UUID().uuidString)"))
    }
    func testUpdateExistingKey() {
        let store = KeychainStore(service: service)
        _ = store.save("first", account: "test-key"); _ = store.save("second", account: "test-key")
        XCTAssertEqual(store.load(account: "test-key"), "second")
    }
}
