import Foundation
import Testing
@testable import DolmusCore

/// Widget'ların kurduğu adres uygulamada aynı yere çözülmeli.
@Suite struct DeepLinkTests {
    @Test("Adres gidip gelir", arguments: [
        DeepLink.commute(.toWork), .commute(.toHome), .hat(id: "M19"), .hat(id: "M35#toki"),
        .tripPlanner, .goHome, .settings,
    ])
    func roundTrip(link: DeepLink) {
        #expect(DeepLink(url: link.url) == link, "\(link.url)")
    }

    @Test func knownAddresses() throws {
        #expect(DeepLink.commute(.toHome).url.absoluteString == "izmirdolmus://trip?direction=toHome")
        #expect(DeepLink.hat(id: "M35#toki").url.absoluteString == "izmirdolmus://hat/M35%23toki")
        #expect(DeepLink(url: try #require(URL(string: "izmirdolmus://plan?to=home"))) == .goHome)
    }

    @Test("Tanınmayan adresler", arguments: [
        "https://izmirdolmus.com/hat/M19", "izmirdolmus://trip", "izmirdolmus://trip?direction=north",
        "izmirdolmus://hat", "izmirdolmus://bilinmeyen",
    ])
    func unknown(address: String) throws {
        #expect(DeepLink(url: try #require(URL(string: address))) == nil)
    }

    @Test("Ücret sınıfları: 55 / 90 / 140 eşikleri")
    func feeTiers() {
        #expect(FeeTier(nil) == .unknown)
        #expect(FeeTier(40) == .low && FeeTier(55) == .low)
        #expect(FeeTier(56) == .standard && FeeTier(90) == .standard)
        #expect(FeeTier(91) == .high && FeeTier(140) == .high)
        #expect(FeeTier(141) == .top)
    }
}
