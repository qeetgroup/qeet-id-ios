import Foundation
import Testing

@testable import QeetID

struct ServiceMatcherTests {
    static func account(_ issuer: String, websites: [String] = []) -> OTPAccount {
        OTPAccount(id: UUID(), issuer: issuer, name: "", parameters: OTPParameters(), createdAt: Date(), websites: websites)
    }

    @Test func hostsFromIdentifiers() {
        #expect(ServiceMatcher.host(from: "https://www.github.com/login") == "github.com")
        #expect(ServiceMatcher.host(from: "GitHub.com") == "github.com")
        #expect(ServiceMatcher.host(from: "books.zoho.in.") == "books.zoho.in")
    }

    @Test func issuersMatchALabelOfTheHost() {
        #expect(ServiceMatcher.issuerMatches(Self.account("GitHub"), host: "github.com"))
        #expect(ServiceMatcher.issuerMatches(Self.account("Zoho"), host: "books.zoho.in"))
        #expect(ServiceMatcher.issuerMatches(Self.account("github.com"), host: "github.com"))
        #expect(!ServiceMatcher.issuerMatches(Self.account("Zoho Books"), host: "books.zoho.in"))
        #expect(!ServiceMatcher.issuerMatches(Self.account("Git"), host: "github.com"))
        // A look-alike's top-level label doesn't count.
        #expect(!ServiceMatcher.issuerMatches(Self.account("com"), host: "github.com"))
    }

    @Test func rememberedSitesComeFirst() {
        let aws = Self.account("AWS", websites: ["signin.aws.amazon.com"])
        let github = Self.account("GitHub")
        let qeet = Self.account("Qeet ID")
        let (matching, others) = ServiceMatcher.partition([qeet, github, aws], for: "signin.aws.amazon.com")
        #expect(matching.map(\.issuer) == ["AWS"])
        #expect(others.map(\.issuer) == ["Qeet ID", "GitHub"])
        let forGitHub = ServiceMatcher.partition([qeet, github, aws], for: "github.com")
        #expect(forGitHub.matching.map(\.issuer) == ["GitHub"])
    }

    @Test func rememberedSitesCoverTheirSubdomains() {
        let account = Self.account("Acme", websites: ["acme.in"])
        #expect(ServiceMatcher.isRemembered(account, for: "login.acme.in"))
        #expect(!ServiceMatcher.isRemembered(account, for: "notacme.in"))
    }

    @Test func onlyRealHostsAreRemembered() {
        #expect(ServiceMatcher.siteToRemember("github.com") == "github.com")
        #expect(ServiceMatcher.siteToRemember("localhost") == nil)
        #expect(ServiceMatcher.siteToRemember("") == nil)
    }
}
