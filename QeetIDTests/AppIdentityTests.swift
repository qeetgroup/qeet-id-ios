import Testing

@testable import QeetID

struct AppIdentityTests {
    @Test func appGroupIsTheSharedGroup() {
        #expect(AppIdentity.appGroup == "group.com.qeetgroup.qeetid")
    }
}
