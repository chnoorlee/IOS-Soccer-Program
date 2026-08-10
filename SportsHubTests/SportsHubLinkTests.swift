import Foundation
import XCTest
@testable import SportsHub

final class SportsHubLinkTests: XCTestCase {
    private let routes: [SportsHubRoute] = [
        .fixture("fixture-1"),
        .article("article-1"),
        .video("video-1"),
        .team("team-1"),
        .player("player-1"),
        .competition("competition-1")
    ]

    func testEveryPublicRouteRoundTripsThroughConfiguredBasePath() throws {
        let policy = try SportsHubLinkPolicy(
            publicBaseURL: try XCTUnwrap(URL(string: "https://share.example.test/app"))
        )

        for route in routes {
            let url = try XCTUnwrap(policy.publicURL(for: route))
            XCTAssertEqual(try policy.route(from: url), route)
            XCTAssertTrue(url.absoluteString.hasPrefix("https://share.example.test/app/"))
        }
    }

    func testEveryCustomSchemeRouteRoundTripsWithoutPublicConfiguration() throws {
        let policy = SportsHubLinkPolicy.localOnly

        for route in routes {
            let url = try XCTUnwrap(policy.customURL(for: route))
            XCTAssertEqual(try policy.route(from: url), route)
            XCTAssertEqual(url.scheme, "sportshub")
        }
        XCTAssertNil(policy.publicURL(for: .fixture("fixture-1")))
    }

    func testPercentEncodedUnicodeIdentifierRoundTrips() throws {
        let policy = try SportsHubLinkPolicy(
            publicBaseURL: try XCTUnwrap(URL(string: "https://share.example.test"))
        )
        let route = SportsHubRoute.team("فريق-١")

        let url = try XCTUnwrap(policy.publicURL(for: route))

        XCTAssertEqual(try policy.route(from: url), route)
    }

    func testPublicBaseRejectsUnsafeOrNonCanonicalConfiguration() throws {
        let values = [
            "http://share.example.test",
            "https://user@share.example.test",
            "https://share.example.test:8443",
            "https://share.example.test/app/",
            "https://share.example.test/app?campaign=x",
            "https://share.example.test/app#fragment",
            "https://share.example.test/a//b",
            "https://share.example.test/../app"
        ]

        for value in values {
            XCTAssertThrowsError(
                try SportsHubLinkPolicy(
                    publicBaseURL: try XCTUnwrap(URL(string: value))
                ),
                "Expected unsafe public base to fail: \(value)"
            )
        }
    }

    func testIncomingLinksRejectUntrustedOriginsAndNonCanonicalRoutes() throws {
        let policy = try SportsHubLinkPolicy(
            publicBaseURL: try XCTUnwrap(URL(string: "https://share.example.test/app"))
        )
        let values = [
            "http://share.example.test/app/fixtures/fixture-1",
            "https://other.example.test/app/fixtures/fixture-1",
            "https://share.example.test:8443/app/fixtures/fixture-1",
            "https://user@share.example.test/app/fixtures/fixture-1",
            "https://share.example.test/app/fixtures/fixture-1?utm_source=test",
            "https://share.example.test/app/fixtures/fixture-1#summary",
            "https://share.example.test/app/unknown/fixture-1",
            "https://share.example.test/app/fixtures",
            "https://share.example.test/app/fixtures/fixture-1/extra",
            "https://share.example.test/app/fixtures/fixture-1/",
            "https://share.example.test/app//fixtures/fixture-1",
            "https://share.example.test/app/%66ixtures/fixture-1",
            "https://share.example.test/application/fixtures/fixture-1",
            "sportshub://unknown/fixture-1",
            "otherapp://fixtures/fixture-1",
            "sportshub://fixtures/fixture-1?source=test"
        ]

        for value in values {
            XCTAssertThrowsError(
                try policy.route(from: try XCTUnwrap(URL(string: value))),
                "Expected incoming URL to fail closed: \(value)"
            )
        }
    }

    func testIdentifiersRejectTraversalEncodingWhitespaceAndLengthAttacks() throws {
        let policy = try SportsHubLinkPolicy(
            publicBaseURL: try XCTUnwrap(URL(string: "https://share.example.test"))
        )
        let values = [
            "https://share.example.test/fixtures/..",
            "https://share.example.test/fixtures/%2E%2E",
            "https://share.example.test/fixtures/a%2Fb",
            "https://share.example.test/fixtures/a%252Fb",
            "https://share.example.test/fixtures/a%20b",
            "https://share.example.test/fixtures/%00",
            "https://share.example.test/fixtures/\(String(repeating: "a", count: 129))"
        ]

        for value in values {
            XCTAssertThrowsError(
                try policy.route(from: try XCTUnwrap(URL(string: value))),
                "Expected invalid identifier to fail: \(value)"
            )
        }
        XCTAssertNil(policy.publicURL(for: .fixture("../another")))
        XCTAssertNil(policy.customURL(for: .fixture("a/b")))
    }

    func testRoutesChooseExpectedNavigationTab() {
        XCTAssertEqual(SportsHubRoute.fixture("fixture-1").preferredTab, .matches)
        for route in routes.dropFirst() {
            XCTAssertEqual(route.preferredTab, .explore)
        }
    }

    @MainActor
    func testCoordinatorQueuesNewestValidRouteAndConsumesOnlyOnce() throws {
        let coordinator = SportsHubLinkCoordinator(policy: .localOnly, seedUITestRoute: false)
        let first = try XCTUnwrap(URL(string: "sportshub://articles/article-1"))
        let second = try XCTUnwrap(URL(string: "sportshub://fixtures/fixture-1"))

        coordinator.receive(first)
        coordinator.receive(second)

        XCTAssertEqual(coordinator.pendingRoute, .fixture("fixture-1"))
        XCTAssertEqual(coordinator.consumePendingRoute(), .fixture("fixture-1"))
        XCTAssertNil(coordinator.consumePendingRoute())
    }

    @MainActor
    func testCoordinatorExposesErrorWithoutReplacingValidPendingRoute() throws {
        let coordinator = SportsHubLinkCoordinator(policy: .localOnly, seedUITestRoute: false)
        coordinator.receive(try XCTUnwrap(URL(string: "sportshub://articles/article-1")))

        coordinator.receive(try XCTUnwrap(URL(string: "sportshub://unknown/value")))

        XCTAssertEqual(coordinator.pendingRoute, .article("article-1"))
        XCTAssertNotNil(coordinator.presentationError)
        coordinator.dismissPresentationError()
        XCTAssertNil(coordinator.presentationError)
    }
}
