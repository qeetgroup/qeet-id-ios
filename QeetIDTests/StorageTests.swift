import CryptoKit
import Foundation
import Security
import Testing

@testable import QeetID

extension SerializedTests {
    /// The Keychain stores, in services of their own so the app's real items are never touched.
    @Suite(.serialized)
    struct AccountStoreTests {
        static let service = "com.qeetgroup.qeetid.account.tests"
        let store = KeychainAccountStore(service: AccountStoreTests.service)

        init() throws {
            try store.deleteAll()
        }

        static func draft(_ issuer: String, key: String = "JBSWY3DPEHPK3PXP") throws -> AccountDraft {
            AccountDraft(issuer: issuer, name: "brightleaf-foods", secret: try SetupKey.decode(key), parameters: OTPParameters())
        }

        @Test func addsListsAndReadsSecrets() throws {
            let github = try store.add(try Self.draft("GitHub"), now: Date(timeIntervalSince1970: 1))
            let aws = try store.add(try Self.draft("AWS", key: "GEZDGNBVGY3TQOJQ"), now: Date(timeIntervalSince1970: 2))
            #expect(try store.accounts().map(\.issuer) == ["GitHub", "AWS"])
            #expect(try store.secret(for: github.id) == Base32.decode("JBSWY3DPEHPK3PXP"))
            #expect(try store.secret(for: aws.id) == Base32.decode("GEZDGNBVGY3TQOJQ"))
        }

        @Test func refusesTheSameSecretTwice() throws {
            _ = try store.add(try Self.draft("GitHub"), now: Date())
            #expect(throws: AccountStoreError.duplicate) { try store.add(try Self.draft("GitHub again"), now: Date()) }
        }

        @Test func updatesMetadataAndKeepsTheSecret() throws {
            var account = try store.add(try Self.draft("GitHub"), now: Date())
            account.issuer = "GitHub (work)"
            account.websites = ["github.com"]
            try store.update(account)
            let stored = try #require(try store.accounts().first)
            #expect(stored.issuer == "GitHub (work)")
            #expect(stored.websites == ["github.com"])
            #expect(try store.secret(for: account.id) == Base32.decode("JBSWY3DPEHPK3PXP"))
        }

        @Test func deletes() throws {
            let account = try store.add(try Self.draft("GitHub"), now: Date())
            try store.delete(account.id)
            #expect(try store.accounts().isEmpty)
            #expect(try store.secret(for: account.id) == nil)
        }

        @Test func listingNeverReturnsASecret() throws {
            _ = try store.add(try Self.draft("GitHub"), now: Date())
            let item = try #require(try store.accounts().first)
            let metadata = try JSONEncoder().encode(item)
            let text = try #require(String(data: metadata, encoding: .utf8))
            #expect(!text.contains("JBSWY3DPEHPK3PXP"))
            #expect(!text.lowercased().contains("secret"))
        }

        @Test func itemsAreThisDeviceOnlyAndNeverSynchronised() throws {
            _ = try store.add(try Self.draft("GitHub"), now: Date())
            let query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword, kSecAttrService: Self.service, kSecReturnAttributes: true,
                kSecMatchLimit: kSecMatchLimitOne, kSecAttrSynchronizable: kSecAttrSynchronizableAny,
            ]
            var result: CFTypeRef?
            #expect(SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess)
            let attributes = try #require(result as? [String: Any])
            #expect(attributes[kSecAttrAccessible as String] as? String == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
            #expect((attributes[kSecAttrSynchronizable as String] as? NSNumber)?.boolValue != true)
        }

        @MainActor
        @Test func codeBookMakesCodesAndForgets() throws {
            let account = try store.add(try Self.draft("GitHub", key: "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"), now: Date())
            let book = CodeBook(store: store)
            let code = try #require(book.code(for: account, at: Date(timeIntervalSince1970: 59)))
            #expect(code.code == "287082")
            #expect(code.validity == Date(timeIntervalSince1970: 30)...Date(timeIntervalSince1970: 60))
            try store.delete(account.id)
            // Still in memory until forgotten…
            #expect(book.code(for: account, at: Date(timeIntervalSince1970: 59)) != nil)
            book.forgetAll()
            #expect(book.code(for: account, at: Date(timeIntervalSince1970: 59)) == nil)
        }
    }

    @Suite(.serialized)
    struct DeviceLinkStoreTests {
        let store = DeviceLinkStore(service: "com.qeetgroup.qeetid.device-link.tests")

        init() throws {
            try store.clear()
        }

        static let link = DeviceLink(
            userID: UUID(), deviceID: UUID(), deviceToken: "d3v1c3-t0k3n-secret", linkedAt: Date(timeIntervalSince1970: 1_800_000_000),
            deviceName: "Meera's iPhone", accountEmail: "meera@brightleaffoods.in", pushToken: "abcd")

        @Test func savesLoadsAndClears() throws {
            #expect(try store.load() == nil)
            try store.save(Self.link)
            #expect(try store.load() == Self.link)
            try store.clear()
            #expect(try store.load() == nil)
        }

        @Test func neverPrintsTheCredential() {
            #expect(!String(describing: Self.link).contains("d3v1c3"))
            #expect(!String(reflecting: Self.link).contains("d3v1c3"))
            #expect(!"\(Self.link)".contains("d3v1c3"))
        }

        @Test func linkedUntilIs180DaysLater() {
            #expect(Self.link.linkedUntil.timeIntervalSince(Self.link.linkedAt) == 180 * 24 * 60 * 60)
            #expect(
                Self.link.summary
                    == LinkSummary(
                        deviceName: "Meera's iPhone", accountEmail: "meera@brightleaffoods.in", linkedUntil: Self.link.linkedUntil))
        }
    }
}
