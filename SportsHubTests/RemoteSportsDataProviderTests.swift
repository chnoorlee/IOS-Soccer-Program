import Foundation
import XCTest
@testable import SportsHub

final class RemoteSportsDataProviderTests: XCTestCase {
    func testFixtureEventUpdatesRejectUnsafeFixtureIDBeforeNetworking() async throws {
        let client = SequencedHTTPClient(results: [])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache()
        )

        do {
            _ = try await provider.fixtureEventUpdates(
                id: "fixture/another-resource",
                afterRevision: 0
            )
            XCTFail("Expected an unsafe path identifier to be rejected")
        } catch let error as SportsDataError {
            XCTAssertEqual(error, .fixtureNotFound)
        }

        let requestCount = await client.requestCount
        XCTAssertEqual(requestCount, 0)
    }

    func testFixtureEventUpdatesUseExclusiveRevisionWithoutCachingAndMapTombstones() async throws {
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.fixtureEventUpdates,
                statusCode: 200,
                headers: [:]
            ))
        ])
        let freshness = PublicContentFreshnessStore()
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache,
            freshnessReporter: freshness,
            now: { now }
        )

        let batch = try await provider.fixtureEventUpdates(
            id: "fixture-1",
            afterRevision: 3
        )
        let requestURL = await client.url(at: 0)
        let cacheControl = await client.header(named: "Cache-Control", at: 0)
        let authorization = await client.header(named: "Authorization", at: 0)
        let cacheStoreCount = await cache.storeCount
        let status = await freshness.status(for: .fixture(id: "fixture-1"))

        XCTAssertEqual(requestURL?.path, "/v1/fixtures/fixture-1/events")
        XCTAssertTrue(requestURL?.absoluteString.contains("afterRevision=3") == true)
        XCTAssertEqual(cacheControl, "no-store")
        XCTAssertNil(authorization)
        XCTAssertEqual(cacheStoreCount, 0)
        XCTAssertEqual(batch.fixtureRevision, 5)
        XCTAssertEqual(batch.fixture.revision, 5)
        XCTAssertEqual(batch.fixture.homeScore, 2)
        XCTAssertEqual(batch.mutations.count, 2)
        XCTAssertEqual(batch.mutations[0].event?.addedTime, 1)
        XCTAssertNil(batch.mutations[1].event)
        XCTAssertEqual(batch.mutations[1].id, "event-yellow")
        XCTAssertEqual(status, .network(at: now))
    }

    func testFixtureEventUpdatesRejectOutOfOrderRevisionsAndReportFailure() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.fixtureEventUpdatesOutOfOrder,
                statusCode: 200,
                headers: [:]
            ))
        ])
        let freshness = PublicContentFreshnessStore()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            freshnessReporter: freshness
        )

        do {
            _ = try await provider.fixtureEventUpdates(id: "fixture-1", afterRevision: 3)
            XCTFail("Expected out-of-order mutations to violate the live-event contract")
        } catch let error as SportsDataError {
            guard case .contractViolation = error else {
                return XCTFail("Expected a contract violation, received \(error)")
            }
        }

        let status = await freshness.status(for: .fixture(id: "fixture-1"))
        XCTAssertEqual(status?.source, .refreshFailed)
    }

    func testFreshnessTracksNetworkRevalidationAndOfflineSnapshot() async throws {
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.home,
                statusCode: 200,
                headers: ["ETag": "\"home-v1\""]
            )),
            .success(HTTPResponse(data: Data(), statusCode: 304, headers: [:])),
            .failure(.networkUnavailable)
        ])
        let freshness = PublicContentFreshnessStore()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            freshnessReporter: freshness,
            now: { now }
        )

        _ = try await provider.homeFeed()
        let network = await freshness.status(for: .home)
        _ = try await provider.homeFeed()
        let revalidated = await freshness.status(for: .home)
        _ = try await provider.homeFeed()
        let offline = await freshness.status(for: .home)

        XCTAssertEqual(network, .network(at: now))
        XCTAssertEqual(revalidated, .revalidated(storedAt: now, checkedAt: now))
        XCTAssertEqual(offline, .offlineSnapshot(storedAt: now, checkedAt: now))
    }

    func testRecoverableMockFallbackIsReportedAsDemoInsteadOfOfflineCache() async throws {
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        let client = SequencedHTTPClient(results: [.failure(.networkUnavailable)])
        let freshness = PublicContentFreshnessStore()
        let remote = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            freshnessReporter: freshness,
            now: { now }
        )
        let provider = FallbackSportsDataProvider(
            primary: remote,
            fallback: MockSportsDataProvider(),
            freshnessReporter: freshness,
            now: { now }
        )

        _ = try await provider.homeFeed()
        let status = await freshness.status(for: .home)

        XCTAssertEqual(status, .demoFallback(checkedAt: now))
    }

    func testHomeMapsContractAndRevalidatesWithETag() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.home,
                statusCode: 200,
                headers: ["ETag": "\"home-v1\""]
            )),
            .success(HTTPResponse(data: Data(), statusCode: 304, headers: [:]))
        ])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache()
        )

        let first = try await provider.homeFeed()
        let second = try await provider.homeFeed()

        XCTAssertEqual(first.fixtures.first?.id, "fixture-1")
        XCTAssertEqual(first.fixtures.first?.state, .live)
        XCTAssertEqual(first.articles.first?.categoryKey, "category.breaking")
        XCTAssertEqual(second, first)
        let ifNoneMatch = await client.ifNoneMatchHeader(at: 1)
        XCTAssertEqual(ifNoneMatch, "\"home-v1\"")
    }

    func testTeamContentMapsAuthoritativeScopeAndRevalidatesWithETag() async throws {
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.teamContent,
                statusCode: 200,
                headers: ["ETag": "\"team-content-v1\""]
            )),
            .success(HTTPResponse(data: Data(), statusCode: 304, headers: [:]))
        ])
        let freshness = PublicContentFreshnessStore()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            freshnessReporter: freshness,
            now: { now }
        )

        let first = try await provider.teamContent(id: "team-home")
        let second = try await provider.teamContent(id: "team-home")
        let requestURL = await client.url(at: 0)
        let ifNoneMatch = await client.ifNoneMatchHeader(at: 1)
        let status = await freshness.status(for: .teamContent(id: "team-home"))

        XCTAssertEqual(requestURL?.path, "/v1/teams/team-home/content")
        XCTAssertEqual(first.teamID, "team-home")
        XCTAssertEqual(first.articles.map(\.id), ["article-remote"])
        XCTAssertEqual(first.videos.map(\.id), ["video-remote"])
        XCTAssertEqual(second, first)
        XCTAssertEqual(ifNoneMatch, "\"team-content-v1\"")
        XCTAssertEqual(status, .revalidated(storedAt: now, checkedAt: now))
    }

    func testPlayerAndCompetitionContentUseExactPathsAndPlayerETagRevalidation() async throws {
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.playerContent,
                statusCode: 200,
                headers: ["ETag": "\"player-content-v1\""]
            )),
            .success(HTTPResponse(data: Data(), statusCode: 304, headers: [:])),
            .success(HTTPResponse(
                data: TestPayloads.competitionContent,
                statusCode: 200,
                headers: ["ETag": "\"competition-content-v1\""]
            ))
        ])
        let freshness = PublicContentFreshnessStore()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            freshnessReporter: freshness,
            now: { now }
        )

        let firstPlayer = try await provider.playerContent(id: "player-one")
        let secondPlayer = try await provider.playerContent(id: "player-one")
        let competition = try await provider.competitionContent(id: "competition-one")
        let playerURL = await client.url(at: 0)
        let competitionURL = await client.url(at: 2)
        let ifNoneMatch = await client.ifNoneMatchHeader(at: 1)
        let playerStatus = await freshness.status(for: .playerContent(id: "player-one"))
        let competitionStatus = await freshness.status(
            for: .competitionContent(id: "competition-one")
        )

        XCTAssertEqual(playerURL?.path, "/v1/players/player-one/content")
        XCTAssertEqual(competitionURL?.path, "/v1/competitions/competition-one/content")
        XCTAssertEqual(firstPlayer.playerID, "player-one")
        XCTAssertEqual(firstPlayer.articles.map(\.id), ["article-remote"])
        XCTAssertEqual(secondPlayer, firstPlayer)
        XCTAssertEqual(competition.competitionID, "competition-one")
        XCTAssertEqual(competition.videos.map(\.id), ["video-remote"])
        XCTAssertEqual(ifNoneMatch, "\"player-content-v1\"")
        XCTAssertEqual(playerStatus, .revalidated(storedAt: now, checkedAt: now))
        XCTAssertEqual(competitionStatus, .network(at: now))
    }

    func testFixtureContentMapsAuthoritativeScopeAndRevalidatesWithETag() async throws {
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.fixtureContent,
                statusCode: 200,
                headers: ["ETag": "\"fixture-content-v1\""]
            )),
            .success(HTTPResponse(data: Data(), statusCode: 304, headers: [:]))
        ])
        let freshness = PublicContentFreshnessStore()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            freshnessReporter: freshness,
            now: { now }
        )

        let first = try await provider.fixtureContent(id: "fixture-1")
        let second = try await provider.fixtureContent(id: "fixture-1")
        let requestURL = await client.url(at: 0)
        let ifNoneMatch = await client.ifNoneMatchHeader(at: 1)
        let status = await freshness.status(for: .fixtureContent(id: "fixture-1"))

        XCTAssertEqual(requestURL?.path, "/v1/fixtures/fixture-1/content")
        XCTAssertEqual(first.fixtureID, "fixture-1")
        XCTAssertEqual(first.moments.map(\.id), ["moment-remote"])
        XCTAssertEqual(first.articles.map(\.id), ["article-remote"])
        XCTAssertFalse(first.moments[0].video.isPlayable)
        XCTAssertEqual(second, first)
        XCTAssertEqual(ifNoneMatch, "\"fixture-content-v1\"")
        XCTAssertEqual(status, .revalidated(storedAt: now, checkedAt: now))
    }

    func testTeamMatchSnapshotsPreserveQueryOrderAndRevalidateWithETag() async throws {
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        let ids = ["team-one", "team-two"]
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.teamMatchSnapshots(ids: ids),
                statusCode: 200,
                headers: ["ETag": "\"team-snapshots-v1\""]
            )),
            .success(HTTPResponse(data: Data(), statusCode: 304, headers: [:]))
        ])
        let freshness = PublicContentFreshnessStore()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            freshnessReporter: freshness,
            now: { now }
        )

        let first = try await provider.teamMatchSnapshots(ids: ids)
        let second = try await provider.teamMatchSnapshots(ids: ids)
        let capturedRequestURL = await client.url(at: 0)
        let requestURL = try XCTUnwrap(capturedRequestURL)
        let queryIDs = URLComponents(
            url: requestURL,
            resolvingAgainstBaseURL: false
        )?.queryItems?.filter { $0.name == "teamId" }.compactMap(\.value)
        let ifNoneMatch = await client.ifNoneMatchHeader(at: 1)
        let status = await freshness.status(for: .teamMatchSnapshots(ids: ids))

        XCTAssertEqual(requestURL.path, "/v1/teams/match-snapshots")
        XCTAssertEqual(queryIDs, ids)
        XCTAssertEqual(first.map(\.team.id), ids)
        XCTAssertEqual(second, first)
        XCTAssertEqual(ifNoneMatch, "\"team-snapshots-v1\"")
        XCTAssertEqual(status, .revalidated(storedAt: now, checkedAt: now))
    }

    func testTeamMatchSnapshotsChunkRequestsAtTwentyWithoutReordering() async throws {
        let ids = (0..<21).map { "team-\($0)" }
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.teamMatchSnapshots(ids: Array(ids.prefix(20))),
                statusCode: 200,
                headers: [:]
            )),
            .success(HTTPResponse(data: Data(), statusCode: 304, headers: [:])),
            .success(HTTPResponse(
                data: TestPayloads.teamMatchSnapshots(ids: Array(ids.suffix(1))),
                statusCode: 200,
                headers: [:]
            ))
        ])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache()
        )

        let result = try await provider.teamMatchSnapshots(ids: ids)
        let capturedFirstURL = await client.url(at: 0)
        let capturedSecondURL = await client.url(at: 1)
        let firstURL = try XCTUnwrap(capturedFirstURL)
        let secondURL = try XCTUnwrap(capturedSecondURL)
        let firstIDs = URLComponents(
            url: firstURL,
            resolvingAgainstBaseURL: false
        )?.queryItems?.compactMap(\.value)
        let secondIDs = URLComponents(
            url: secondURL,
            resolvingAgainstBaseURL: false
        )?.queryItems?.compactMap(\.value)

        XCTAssertEqual(result.map(\.team.id), ids)
        XCTAssertEqual(firstIDs, Array(ids.prefix(20)))
        XCTAssertEqual(secondIDs, Array(ids.suffix(1)))
        let requestCount = await client.requestCount
        XCTAssertEqual(requestCount, 2)
    }

    func testTeamMatchSnapshotsReportWorstFreshnessAcrossBatches() async throws {
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        let ids = (0..<21).map { "team-\($0)" }
        let firstBatchIDs = Array(ids.prefix(20))
        let secondBatchIDs = Array(ids.suffix(1))
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.teamMatchSnapshots(ids: firstBatchIDs),
                statusCode: 200,
                headers: ["ETag": "\"team-snapshots-first\""]
            )),
            .success(HTTPResponse(
                data: TestPayloads.teamMatchSnapshots(ids: secondBatchIDs),
                statusCode: 200,
                headers: ["ETag": "\"team-snapshots-second\""]
            )),
            .success(HTTPResponse(data: Data(), statusCode: 304, headers: [:])),
            .failure(.networkUnavailable)
        ])
        let freshness = PublicContentFreshnessStore()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            freshnessReporter: freshness,
            now: { now }
        )

        _ = try await provider.teamMatchSnapshots(ids: ids)
        let snapshots = try await provider.teamMatchSnapshots(ids: ids)
        let status = await freshness.status(for: .teamMatchSnapshots(ids: ids))

        XCTAssertEqual(snapshots.map(\.team.id), ids)
        XCTAssertEqual(
            status,
            .offlineSnapshot(storedAt: now, checkedAt: now)
        )
    }

    func testTeamMatchSnapshotsRejectDuplicateIDsBeforeNetworking() async throws {
        let client = SequencedHTTPClient(results: [])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache()
        )

        do {
            _ = try await provider.teamMatchSnapshots(ids: ["team-one", "team-one"])
            XCTFail("Expected duplicate team IDs to be rejected")
        } catch let error as SportsDataError {
            XCTAssertEqual(error, .invalidQuery)
        }
        let requestCount = await client.requestCount
        XCTAssertEqual(requestCount, 0)
    }

    func testTeamMatchSnapshotsRejectReorderedRowsBeforeCaching() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.teamMatchSnapshots(ids: ["team-two", "team-one"]),
                statusCode: 200,
                headers: [:]
            ))
        ])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache()
        )

        do {
            _ = try await provider.teamMatchSnapshots(ids: ["team-one", "team-two"])
            XCTFail("Expected reordered rows to fail closed")
        } catch {
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data[0].team.id")
            )
        }
        let storeCount = await cache.storeCount
        XCTAssertEqual(storeCount, 0)
    }

    func testTeamContentRejectsMismatchedEchoBeforeCaching() async throws {
        let payload = Data(
            String(decoding: TestPayloads.teamContent, as: UTF8.self)
                .replacingOccurrences(
                    of: "\"teamId\": \"team-home\"",
                    with: "\"teamId\": \"team-away\""
                )
                .utf8
        )
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: payload, statusCode: 200, headers: [:]))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache
        )

        do {
            _ = try await provider.teamContent(id: "team-home")
            XCTFail("Expected a mismatched team echo to fail closed")
        } catch {
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.teamId")
            )
        }
        let storeCount = await cache.storeCount
        XCTAssertEqual(storeCount, 0)
    }

    func testCompetitionContentRejectsMismatchedEchoBeforeCaching() async throws {
        let payload = Data(
            String(decoding: TestPayloads.competitionContent, as: UTF8.self)
                .replacingOccurrences(
                    of: "\"competitionId\": \"competition-one\"",
                    with: "\"competitionId\": \"competition-other\""
                )
                .utf8
        )
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: payload, statusCode: 200, headers: [:]))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache
        )

        do {
            _ = try await provider.competitionContent(id: "competition-one")
            XCTFail("Expected a mismatched competition echo to fail closed")
        } catch {
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.competitionId")
            )
        }
        let storeCount = await cache.storeCount
        XCTAssertEqual(storeCount, 0)
    }

    func testFixtureContentRejectsMismatchedEchoBeforeCaching() async throws {
        let payload = Data(
            String(decoding: TestPayloads.fixtureContent, as: UTF8.self)
                .replacingOccurrences(
                    of: "\"fixtureId\": \"fixture-1\"",
                    with: "\"fixtureId\": \"fixture-away\""
                )
                .utf8
        )
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: payload, statusCode: 200, headers: [:]))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache
        )

        do {
            _ = try await provider.fixtureContent(id: "fixture-1")
            XCTFail("Expected a mismatched fixture echo to fail closed")
        } catch {
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.fixtureId")
            )
        }
        let storeCount = await cache.storeCount
        XCTAssertEqual(storeCount, 0)
    }

    func testTeamDetailsRejectsLiveFixtureInNextWindowBeforeCaching() async throws {
        let payload = Data(
            String(decoding: TestPayloads.teamDetails, as: UTF8.self)
                .replacingOccurrences(of: "\"state\": \"SCHEDULED\"", with: "\"state\": \"LIVE\"")
                .utf8
        )
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: payload, statusCode: 200, headers: [:]))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache
        )

        do {
            _ = try await provider.teamDetails(id: "team-home")
            XCTFail("Expected a live fixture in the next window to fail closed")
        } catch {
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.nextFixtures.state")
            )
        }
        let storeCount = await cache.storeCount
        XCTAssertEqual(storeCount, 0)
    }

    func testRecoverableNetworkFailureUsesPreviouslyValidatedCache() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: TestPayloads.home, statusCode: 200, headers: [:])),
            .failure(.networkUnavailable)
        ])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache()
        )

        let online = try await provider.homeFeed()
        let offline = try await provider.homeFeed()

        XCTAssertEqual(offline, online)
    }

    func testMalformedSuccessIsNotCached() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: Data("{}".utf8), statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: Data(), statusCode: 304, headers: [:]))
        ])
        let freshness = PublicContentFreshnessStore()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            freshnessReporter: freshness
        )

        do {
            _ = try await provider.homeFeed()
            XCTFail("Expected malformed JSON to fail decoding")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .decoding)
        }
        let malformedStatus = await freshness.status(for: .home)
        XCTAssertEqual(malformedStatus?.source, .refreshFailed)

        do {
            _ = try await provider.homeFeed()
            XCTFail("A 304 must fail when no validated payload was cached")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .invalidResponse(statusCode: 304))
        }
    }

    func testMockFallbackDoesNotHideContractFailure() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: Data("{}".utf8), statusCode: 200, headers: [:]))
        ])
        let remote = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache()
        )
        let provider = FallbackSportsDataProvider(primary: remote, fallback: MockSportsDataProvider())

        do {
            _ = try await provider.homeFeed()
            XCTFail("Contract failures must remain visible")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .decoding)
        }
    }

    func testFixturesRequestCarriesLocalDateAndIANAZone() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: TestPayloads.fixtures, statusCode: 200, headers: [:]))
        ])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache()
        )
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-05T12:00:00Z"))

        let fixtures = try await provider.fixtures(on: date)

        let recordedURL = await client.url(at: 0)
        let url = try XCTUnwrap(recordedURL)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let dateValue = components.queryItems?.first { $0.name == "date" }?.value
        let timeZoneValue = components.queryItems?.first { $0.name == "timeZone" }?.value
        XCTAssertEqual(url.path, "/v1/fixtures")
        XCTAssertNotNil(dateValue)
        XCTAssertEqual(timeZoneValue, TimeZone.autoupdatingCurrent.identifier)
        XCTAssertEqual(fixtures[0].broadcasts.map(\.channelEnglish), ["Demo Sports One"])
        XCTAssertEqual(fixtures[0].broadcasts[0].regionCode, "SA")
    }

    func testFixturesRejectInvalidBroadcastMetadataBeforeCaching() async throws {
        let payload = Data(
            String(decoding: TestPayloads.fixtures, as: UTF8.self)
                .replacingOccurrences(
                    of: "\"regionCode\": \"SA\"",
                    with: "\"regionCode\": \"sa\""
                )
                .utf8
        )
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: payload, statusCode: 200, headers: [:]))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache
        )

        do {
            _ = try await provider.fixtures(on: Date(timeIntervalSince1970: 1_788_000_000))
            XCTFail("Expected invalid broadcast metadata to fail closed")
        } catch let error as SportsDataError {
            guard case .contractViolation = error else {
                return XCTFail("Expected contract violation, received \(error)")
            }
        }

        let storeCount = await cache.storeCount
        XCTAssertEqual(storeCount, 0)
    }

    func testCompetitionFixturesValidateScopeAndPaginateInStableOrder() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.competitionFixturePage(
                    fixtures: [("fixture-1", "2026-08-05T12:00:00Z")],
                    nextCursor: "season-page-2",
                    hasMore: true
                ),
                statusCode: 200,
                headers: ["ETag": "\"fixtures-1\""]
            )),
            .success(HTTPResponse(
                data: TestPayloads.competitionFixturePage(
                    fixtures: [("fixture-2", "2026-08-05T14:00:00Z")]
                ),
                statusCode: 200,
                headers: [:]
            ))
        ])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache()
        )

        let fixtures = try await provider.competitionFixtures(
            id: "competition-1",
            seasonID: "season-2025"
        )
        let firstURLValue = await client.url(at: 0)
        let secondURLValue = await client.url(at: 1)
        let firstURL = try XCTUnwrap(firstURLValue)
        let secondURL = try XCTUnwrap(secondURLValue)
        let firstQuery = try XCTUnwrap(
            URLComponents(url: firstURL, resolvingAgainstBaseURL: false)?.queryItems
        )
        let secondQuery = try XCTUnwrap(
            URLComponents(url: secondURL, resolvingAgainstBaseURL: false)?.queryItems
        )

        XCTAssertEqual(fixtures.map(\.id), ["fixture-1", "fixture-2"])
        XCTAssertTrue(fixtures.allSatisfy { $0.competition.id == "competition-1" })
        XCTAssertEqual(firstURL.path, "/v1/competitions/competition-1/fixtures")
        XCTAssertEqual(firstQuery.first(where: { $0.name == "seasonId" })?.value, "season-2025")
        XCTAssertEqual(firstQuery.first(where: { $0.name == "limit" })?.value, "100")
        XCTAssertNil(firstQuery.first(where: { $0.name == "cursor" }))
        XCTAssertEqual(secondQuery.first(where: { $0.name == "cursor" })?.value, "season-page-2")
    }

    func testCompetitionFixturesRejectMismatchedEchoBeforeCaching() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.competitionFixturePage(
                    competitionID: "another-competition",
                    fixtures: [("fixture-1", "2026-08-05T12:00:00Z")]
                ),
                statusCode: 200,
                headers: [:]
            ))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache
        )

        do {
            _ = try await provider.competitionFixtures(
                id: "competition-1",
                seasonID: "season-2025"
            )
            XCTFail("Expected the echoed competition scope to be enforced")
        } catch let error as SportsDataError {
            guard case .contractViolation(field: "competitionId") = error else {
                return XCTFail("Expected competitionId violation, received \(error)")
            }
        }

        let storeCount = await cache.storeCount
        XCTAssertEqual(storeCount, 0)
    }

    func testCompetitionFixturesRejectCrossPageOrderingFailures() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.competitionFixturePage(
                    fixtures: [("fixture-2", "2026-08-05T14:00:00Z")],
                    nextCursor: "page-2",
                    hasMore: true
                ),
                statusCode: 200,
                headers: [:]
            )),
            .success(HTTPResponse(
                data: TestPayloads.competitionFixturePage(
                    fixtures: [("fixture-1", "2026-08-05T12:00:00Z")]
                ),
                statusCode: 200,
                headers: [:]
            ))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache
        )

        do {
            _ = try await provider.competitionFixtures(
                id: "competition-1",
                seasonID: "season-2025"
            )
            XCTFail("Expected global fixture order to be enforced across pages")
        } catch let error as SportsDataError {
            XCTAssertEqual(error, .contractViolation(field: "data.order"))
        }
        let storeCount = await cache.storeCount
        XCTAssertEqual(storeCount, 1, "The invalid second page must not be cached")
    }

    func testCompetitionFixturesRejectCrossPageDuplicateIDs() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.competitionFixturePage(
                    fixtures: [("fixture-1", "2026-08-05T12:00:00Z")],
                    nextCursor: "page-2",
                    hasMore: true
                ),
                statusCode: 200,
                headers: [:]
            )),
            .success(HTTPResponse(
                data: TestPayloads.competitionFixturePage(
                    fixtures: [("fixture-1", "2026-08-05T14:00:00Z")]
                ),
                statusCode: 200,
                headers: [:]
            ))
        ])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache()
        )

        do {
            _ = try await provider.competitionFixtures(
                id: "competition-1",
                seasonID: "season-2025"
            )
            XCTFail("Expected duplicate fixture IDs across pages to be rejected")
        } catch let error as SportsDataError {
            XCTAssertEqual(error, .contractViolation(field: "data.id"))
        }
    }

    func testCompetitionFixturesLaterPageFailureFallsBackToCompleteDemoSchedule() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.competitionFixturePage(
                    competitionID: MockSportsData.competition.id,
                    seasonID: MockSportsData.season.id,
                    fixtures: [("remote-page-1", "2026-08-05T12:00:00Z")],
                    nextCursor: "page-2",
                    hasMore: true
                ),
                statusCode: 200,
                headers: [:]
            )),
            .failure(.networkUnavailable)
        ])
        let freshness = PublicContentFreshnessStore()
        let remote = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            freshnessReporter: freshness
        )
        let provider = FallbackSportsDataProvider(
            primary: remote,
            fallback: MockSportsDataProvider(),
            freshnessReporter: freshness
        )
        let resource = PublicContentResource.competitionFixtures(
            id: MockSportsData.competition.id,
            seasonID: MockSportsData.season.id
        )

        let fixtures = try await provider.competitionFixtures(
            id: MockSportsData.competition.id,
            seasonID: MockSportsData.season.id
        )
        let status = await freshness.status(for: resource)

        XCTAssertEqual(fixtures.count, 4)
        XCTAssertFalse(fixtures.contains { $0.id == "remote-page-1" })
        XCTAssertTrue(fixtures.allSatisfy {
            $0.competition.id == MockSportsData.competition.id
        })
        XCTAssertEqual(status?.source, .demoFallback)
    }

    func testTeamsAndFixtureDetailsMapAllCoreProviderMethods() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: TestPayloads.teams, statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: TestPayloads.fixtureDetails, statusCode: 200, headers: [:]))
        ])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache()
        )

        let teams = try await provider.teams()
        let details = try await provider.fixtureDetails(id: "fixture-1")

        XCTAssertEqual(teams.first?.colorHex, "006C75")
        XCTAssertEqual(details.events.map(\.kind), [.goal])
        XCTAssertEqual(details.homeLineup.players.first?.positionKey, "position.goalkeeper")
        XCTAssertEqual(details.statistics.first?.titleKey, "stat.possession")
        XCTAssertEqual(details.sourceName, "Licensed Data Partner")
    }

    func testPlayerCatalogUsesBoundedPublicCacheableRequest() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.players,
                statusCode: 200,
                headers: ["ETag": "\"players-v1\""]
            )),
            .success(HTTPResponse(data: Data(), statusCode: 304, headers: [:]))
        ])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache()
        )

        let first = try await provider.players()
        let second = try await provider.players()

        XCTAssertEqual(first.first?.id, "player-9")
        XCTAssertEqual(second, first)
        let recordedURL = await client.url(at: 0)
        let authorization = await client.header(named: "Authorization", at: 0)
        let ifNoneMatch = await client.ifNoneMatchHeader(at: 1)
        let firstURL = try XCTUnwrap(recordedURL)
        let components = try XCTUnwrap(
            URLComponents(url: firstURL, resolvingAgainstBaseURL: false)
        )
        XCTAssertEqual(firstURL.path, "/v1/players")
        XCTAssertEqual(
            components.queryItems?.first { $0.name == "limit" }?.value,
            "100"
        )
        XCTAssertNil(authorization)
        XCTAssertEqual(ifNoneMatch, "\"players-v1\"")
    }

    func testPlayerCatalogRejectsDuplicateIdentifiersBeforeCaching() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.duplicatePlayers,
                statusCode: 200,
                headers: [:]
            ))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache
        )

        do {
            _ = try await provider.players()
            XCTFail("Expected duplicate player identifiers to violate the catalog contract")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .contractViolation(field: "data.id"))
        }
        let storeCount = await cache.storeCount
        XCTAssertEqual(storeCount, 0)
    }

    func testEditorialVideoSearchAndCompetitionContracts() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: TestPayloads.competitions, statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: TestPayloads.articles, statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: TestPayloads.articleDetails, statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: TestPayloads.videos, statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: TestPayloads.videoDetails, statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: TestPayloads.search, statusCode: 200, headers: [:]))
        ])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache()
        )

        let competitions = try await provider.competitions()
        let articles = try await provider.articles()
        let article = try await provider.articleDetails(id: "article-remote")
        let videos = try await provider.videos()
        let video = try await provider.videoDetails(id: "video-remote")
        let results = try await provider.search(query: "  الهلال\n")
        let searchURL = await client.url(at: 5)
        let searchQueryItems = try XCTUnwrap(
            URLComponents(url: try XCTUnwrap(searchURL), resolvingAgainstBaseURL: false)?.queryItems
        )

        XCTAssertEqual(competitions.first?.id, "competition-remote")
        XCTAssertTrue(articles.first?.isCorrected == true)
        XCTAssertEqual(articles.first?.format, .visualBrief)
        XCTAssertEqual(articles.first?.engagement?.totalReactions, 202)
        XCTAssertEqual(articles.first?.engagement?.publishedComments, 3)
        XCTAssertEqual(articles.first?.heroMedia?.id, "hero-remote")
        XCTAssertEqual(articles.first?.heroMedia?.contentType, .jpeg)
        XCTAssertEqual(articles.first?.heroMedia?.width, 1_600)
        XCTAssertEqual(
            articles.first?.heroMedia?.url.absoluteString,
            "https://media.example.test/articles/hero-remote.jpg?sig=demo"
        )
        XCTAssertEqual(article.revision, 2)
        XCTAssertEqual(article.article.format, .visualBrief)
        XCTAssertEqual(article.article.engagement?.totalReactions, 202)
        XCTAssertEqual(article.article.engagement?.publishedComments, 3)
        XCTAssertEqual(
            article.article.heroMedia?.credit(in: .english),
            "Remote Sports Studio"
        )
        XCTAssertEqual(article.visualBrief?.sections.map(\.id), ["match-pulse", "set-pieces"])
        XCTAssertEqual(
            article.visualBrief?.sections.flatMap { $0.items.map(\.id) },
            ["metric-shots", "metric-possession", "comparison-home", "comparison-away"]
        )
        XCTAssertEqual(videos.first?.availabilityReason, .regionBlocked)
        XCTAssertEqual(videos.first?.poster?.id, "poster-video-remote")
        XCTAssertEqual(videos.first?.poster?.contentType, .jpeg)
        XCTAssertEqual(
            videos.first?.poster?.url.absoluteString,
            "https://media.example.test/videos/poster-video-remote.jpg?sig=demo"
        )
        XCTAssertEqual(video.audioLanguages, ["ar", "en"])
        XCTAssertEqual(video.video.poster?.id, "poster-video-remote")
        XCTAssertEqual(
            video.video.poster?.credit(in: .english),
            "Remote Video Studio"
        )
        XCTAssertEqual(video.publisher(in: .english), "Remote Sports Desk")
        XCTAssertEqual(video.program?.id, "program-remote")
        XCTAssertEqual(
            video.relatedVideos.map(\.id),
            ["video-related-one", "video-related-two"]
        )
        XCTAssertTrue(video.relatedVideos.allSatisfy { !$0.isPlayable })
        XCTAssertEqual(results.map(\.type), [.article, .team])
        XCTAssertEqual(searchURL?.path, "/v1/search")
        XCTAssertEqual(searchQueryItems.first { $0.name == "query" }?.value, "الهلال")
        XCTAssertEqual(searchQueryItems.first { $0.name == "limit" }?.value, "100")

        do {
            _ = try await provider.search(query: String(repeating: "a", count: 101))
            XCTFail("Oversized search queries must fail before network access")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .invalidQuery)
        }
        let requestCount = await client.requestCount
        XCTAssertEqual(requestCount, 6)
    }

    func testVideoProgramEndpointsPreserveQueriesOrderAndPublicCaching() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.videoPrograms,
                statusCode: 200,
                headers: ["ETag": "\"programs-v1\""]
            )),
            .success(HTTPResponse(
                data: Data(),
                statusCode: 304,
                headers: [:]
            )),
            .success(HTTPResponse(
                data: TestPayloads.videoProgramDetails,
                statusCode: 200,
                headers: [:]
            ))
        ])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache()
        )

        let programs = try await provider.videoPrograms(
            cursor: "cursor-one",
            limit: 2,
            sport: .esports
        )
        let revalidatedPrograms = try await provider.videoPrograms(
            cursor: "cursor-one",
            limit: 2,
            sport: .esports
        )
        let details = try await provider.videoProgramDetails(
            id: "program-remote",
            cursor: nil,
            limit: 20
        )

        let recordedListURL = await client.url(at: 0)
        let recordedDetailURL = await client.url(at: 2)
        let revalidationHeader = await client.ifNoneMatchHeader(at: 1)
        let listURL = try XCTUnwrap(recordedListURL)
        let listQuery = try XCTUnwrap(
            URLComponents(url: listURL, resolvingAgainstBaseURL: false)?.queryItems
        )
        let detailURL = try XCTUnwrap(recordedDetailURL)
        let detailQuery = try XCTUnwrap(
            URLComponents(url: detailURL, resolvingAgainstBaseURL: false)?.queryItems
        )
        XCTAssertEqual(listURL.path, "/v1/video-programs")
        XCTAssertEqual(listQuery.first { $0.name == "cursor" }?.value, "cursor-one")
        XCTAssertEqual(listQuery.first { $0.name == "limit" }?.value, "2")
        XCTAssertEqual(listQuery.first { $0.name == "sport" }?.value, "ESPORTS")
        XCTAssertEqual(programs.programs.map(\.id), ["program-remote", "program-second"])
        XCTAssertEqual(programs.programs.map(\.sport), [.esports, .football])
        XCTAssertEqual(revalidatedPrograms, programs)
        XCTAssertEqual(revalidationHeader, "\"programs-v1\"")
        XCTAssertEqual(detailURL.path, "/v1/video-programs/program-remote")
        XCTAssertEqual(detailQuery.first { $0.name == "limit" }?.value, "20")
        XCTAssertNil(detailQuery.first { $0.name == "cursor" })
        XCTAssertEqual(details.program.id, "program-remote")
        XCTAssertEqual(details.episodes.map(\.id), ["episode-remote"])
        XCTAssertNil(details.episodes.first?.publishedAt)
    }

    func testVideoProgramDetailRejectsUnsafeOrMismatchedIdentifierBeforeCaching() async throws {
        let mismatchClient = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.mismatchedVideoProgramDetails,
                statusCode: 200,
                headers: [:]
            ))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: mismatchClient,
            cache: cache
        )

        do {
            _ = try await provider.videoProgramDetails(
                id: "program-remote",
                cursor: nil,
                limit: 20
            )
            XCTFail("Expected a response for another program to fail closed")
        } catch {
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.program.id")
            )
        }
        let mismatchStoreCount = await cache.storeCount
        XCTAssertEqual(mismatchStoreCount, 0)

        let unsafeClient = SequencedHTTPClient(results: [])
        let unsafeProvider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: unsafeClient,
            cache: MemorySportsDataCache()
        )
        do {
            _ = try await unsafeProvider.videoProgramDetails(
                id: "program/unsafe",
                cursor: nil,
                limit: 20
            )
            XCTFail("Expected an unsafe path identifier to fail before networking")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .notFound)
        }
        let unsafeRequestCount = await unsafeClient.requestCount
        XCTAssertEqual(unsafeRequestCount, 0)
    }

    func testSearchDoesNotReturnSilentStaleSnapshotAfterNetworkFailure() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: TestPayloads.search, statusCode: 200, headers: [:])),
            .failure(.networkUnavailable)
        ])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            now: { Date(timeIntervalSince1970: 1_788_000_000) }
        )

        let first = try await provider.search(query: "الهلال")
        XCTAssertEqual(first.map(\.type), [.article, .team])

        do {
            _ = try await provider.search(query: "الهلال")
            XCTFail("Search must not present an unlabelled stale response")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .networkUnavailable)
        }
    }

    func testVideoDetailsRejectMismatchedPathIdentifierBeforeCaching() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.mismatchedVideoDetails,
                statusCode: 200,
                headers: [:]
            ))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache
        )

        do {
            _ = try await provider.videoDetails(id: "video-remote")
            XCTFail("Expected a response for another video to fail closed")
        } catch {
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.id")
            )
        }
        let storeCount = await cache.storeCount
        XCTAssertEqual(storeCount, 0)
    }

    func testVideosRejectUnsafePosterBeforeCaching() async throws {
        let invalidPayload = Data(
            String(decoding: TestPayloads.videos, as: UTF8.self)
                .replacingOccurrences(
                    of: "https://media.example.test/videos/poster-video-remote.jpg?sig=demo",
                    with: "http://media.example.test/videos/poster-video-remote.jpg"
                )
                .utf8
        )
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: invalidPayload, statusCode: 200, headers: [:]))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache
        )

        do {
            _ = try await provider.videos()
            XCTFail("Unsafe video poster must fail before caching")
        } catch {
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data[0].poster.url")
            )
        }
        let storeCount = await cache.storeCount
        XCTAssertEqual(storeCount, 0)
    }

    func testVideoDiscoveryMapsEditorialContractAndRevalidatesWithETag() async throws {
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.videoDiscovery,
                statusCode: 200,
                headers: ["ETag": "\"video-discovery-v1\""]
            )),
            .success(HTTPResponse(data: Data(), statusCode: 304, headers: [:]))
        ])
        let freshness = PublicContentFreshnessStore()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            freshnessReporter: freshness,
            now: { now }
        )

        let first = try await provider.videoDiscovery()
        let second = try await provider.videoDiscovery()
        let requestURL = await client.url(at: 0)
        let ifNoneMatch = await client.ifNoneMatchHeader(at: 1)
        let status = await freshness.status(for: .videoDiscovery)

        XCTAssertEqual(requestURL?.path, "/v1/videos/discovery")
        XCTAssertNil(requestURL?.query)
        XCTAssertEqual(first.items.map(\.id), [
            "video-original", "video-highlight", "video-esports"
        ])
        XCTAssertEqual(first.items.map(\.sport), [.football, .football, .esports])
        XCTAssertEqual(first.featuredVideoID, "video-original")
        XCTAssertEqual(first.trendingVideoIDs, ["video-esports", "video-highlight"])
        XCTAssertEqual(second, first)
        XCTAssertEqual(ifNoneMatch, "\"video-discovery-v1\"")
        XCTAssertEqual(status, .revalidated(storedAt: now, checkedAt: now))
    }

    func testVideoDiscoveryRejectsDanglingEditorialReferenceBeforeCaching() async throws {
        let invalidPayload = Data(
            String(decoding: TestPayloads.videoDiscovery, as: UTF8.self)
                .replacingOccurrences(
                    of: "\"featuredVideoId\": \"video-original\"",
                    with: "\"featuredVideoId\": \"video-missing\""
                )
                .utf8
        )
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: invalidPayload, statusCode: 200, headers: [:]))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache
        )

        do {
            _ = try await provider.videoDiscovery()
            XCTFail("Expected dangling featured placement to fail closed")
        } catch let error as SportsDataError {
            XCTAssertEqual(error, .contractViolation(field: "data.featuredVideoId"))
        }
        let storeCount = await cache.storeCount
        XCTAssertEqual(storeCount, 0)
    }

    func testVideoDiscoveryFailureFallsBackToOneCompleteDemoSnapshot() async throws {
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        let client = SequencedHTTPClient(results: [.failure(.networkUnavailable)])
        let freshness = PublicContentFreshnessStore()
        let remote = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            freshnessReporter: freshness,
            now: { now }
        )
        let provider = FallbackSportsDataProvider(
            primary: remote,
            fallback: MockSportsDataProvider(),
            freshnessReporter: freshness,
            now: { now }
        )

        let result = try await provider.videoDiscovery()
        let status = await freshness.status(for: .videoDiscovery)

        XCTAssertEqual(result, MockSportsData.videoDiscovery)
        XCTAssertEqual(status, .demoFallback(checkedAt: now))
    }

    func testVideosPaginateAndPreserveServerOrder() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.videoPage(
                    videos: [("video-highlight", "HIGHLIGHT"), ("video-live", "LIVE")],
                    nextCursor: "video-page-2",
                    hasMore: true
                ),
                statusCode: 200,
                headers: [:]
            )),
            .success(HTTPResponse(
                data: TestPayloads.videoPage(
                    videos: [("video-interview", "INTERVIEW")]
                ),
                statusCode: 200,
                headers: [:]
            ))
        ])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache()
        )

        let videos = try await provider.videos()
        let firstURLValue = await client.url(at: 0)
        let secondURLValue = await client.url(at: 1)
        let firstURL = try XCTUnwrap(firstURLValue)
        let secondURL = try XCTUnwrap(secondURLValue)
        let firstQuery = try XCTUnwrap(
            URLComponents(url: firstURL, resolvingAgainstBaseURL: false)?.queryItems
        )
        let secondQuery = try XCTUnwrap(
            URLComponents(url: secondURL, resolvingAgainstBaseURL: false)?.queryItems
        )

        XCTAssertEqual(videos.map(\.id), [
            "video-highlight", "video-live", "video-interview"
        ])
        XCTAssertEqual(firstURL.path, "/v1/videos")
        XCTAssertEqual(firstQuery.first(where: { $0.name == "limit" })?.value, "100")
        XCTAssertNil(firstQuery.first(where: { $0.name == "cursor" }))
        XCTAssertEqual(
            secondQuery.first(where: { $0.name == "cursor" })?.value,
            "video-page-2"
        )
    }

    func testVideosRejectCrossPageDuplicateBeforeCachingSecondPage() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.videoPage(
                    videos: [("video-duplicate", "HIGHLIGHT")],
                    nextCursor: "video-page-2",
                    hasMore: true
                ),
                statusCode: 200,
                headers: [:]
            )),
            .success(HTTPResponse(
                data: TestPayloads.videoPage(
                    videos: [("video-duplicate", "REPLAY")]
                ),
                statusCode: 200,
                headers: [:]
            ))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache
        )

        do {
            _ = try await provider.videos()
            XCTFail("Expected duplicate video IDs across pages to fail closed")
        } catch let error as SportsDataError {
            XCTAssertEqual(error, .contractViolation(field: "data.id"))
        }

        let storeCount = await cache.storeCount
        XCTAssertEqual(storeCount, 1, "The invalid second page must not be cached")
    }

    func testVideosRejectInvalidTerminalCursorBeforeCaching() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.videoPage(
                    videos: [("video-one", "ORIGINAL")],
                    nextCursor: "unexpected-cursor",
                    hasMore: false
                ),
                statusCode: 200,
                headers: [:]
            ))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache
        )

        do {
            _ = try await provider.videos()
            XCTFail("Expected terminal pages to reject an unexpected cursor")
        } catch let error as SportsDataError {
            XCTAssertEqual(error, .contractViolation(field: "page.nextCursor"))
        }

        let storeCount = await cache.storeCount
        XCTAssertEqual(storeCount, 0)
    }

    func testVideosRejectBlankContinuingCursorBeforeCaching() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.videoPage(
                    videos: [("video-one", "LIVE")],
                    nextCursor: " ",
                    hasMore: true
                ),
                statusCode: 200,
                headers: [:]
            ))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache
        )

        do {
            _ = try await provider.videos()
            XCTFail("Expected a blank continuation cursor to fail closed")
        } catch let error as SportsDataError {
            XCTAssertEqual(error, .contractViolation(field: "page.nextCursor"))
        }

        let storeCount = await cache.storeCount
        XCTAssertEqual(storeCount, 0)
    }

    func testVideosRejectPageLargerThanRequestedLimitBeforeCaching() async throws {
        let oversizedVideos: [(id: String, type: String)] = (0...100).map {
            ("video-\($0)", "HIGHLIGHT")
        }
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.videoPage(videos: oversizedVideos),
                statusCode: 200,
                headers: [:]
            ))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache
        )

        do {
            _ = try await provider.videos()
            XCTFail("Expected a page larger than the requested limit to fail closed")
        } catch let error as SportsDataError {
            XCTAssertEqual(error, .contractViolation(field: "data"))
        }

        let storeCount = await cache.storeCount
        XCTAssertEqual(storeCount, 0)
    }

    func testVideosRejectAggregateLargerThanMaximumBeforeCachingOverflowPage() async throws {
        var results: [Result<HTTPResponse, SportsDataError>] = []
        for pageIndex in 0..<10 {
            let pageVideos: [(id: String, type: String)] = (0..<100).map {
                ("video-\(pageIndex)-\($0)", "HIGHLIGHT")
            }
            results.append(.success(HTTPResponse(
                data: TestPayloads.videoPage(
                    videos: pageVideos,
                    nextCursor: "video-page-\(pageIndex + 1)",
                    hasMore: true
                ),
                statusCode: 200,
                headers: [:]
            )))
        }
        results.append(.success(HTTPResponse(
            data: TestPayloads.videoPage(videos: [("video-overflow", "INTERVIEW")]),
            statusCode: 200,
            headers: [:]
        )))
        let client = SequencedHTTPClient(results: results)
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache
        )

        do {
            _ = try await provider.videos()
            XCTFail("Expected an aggregate larger than 1,000 videos to fail closed")
        } catch let error as SportsDataError {
            XCTAssertEqual(error, .contractViolation(field: "data"))
        }

        let storeCount = await cache.storeCount
        XCTAssertEqual(storeCount, 10, "The overflow page must not be cached")
    }

    func testVideosLaterPageFailureFallsBackToCompleteDemoLibrary() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.videoPage(
                    videos: [("remote-page-one", "HIGHLIGHT")],
                    nextCursor: "video-page-2",
                    hasMore: true
                ),
                statusCode: 200,
                headers: [:]
            )),
            .failure(.networkUnavailable)
        ])
        let freshness = PublicContentFreshnessStore()
        let remote = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            freshnessReporter: freshness
        )
        let provider = FallbackSportsDataProvider(
            primary: remote,
            fallback: MockSportsDataProvider(),
            freshnessReporter: freshness
        )

        let videos = try await provider.videos()
        let status = await freshness.status(for: .videos)

        XCTAssertEqual(videos, MockSportsData.videos)
        XCTAssertFalse(videos.contains { $0.id == "remote-page-one" })
        XCTAssertEqual(status?.source, .demoFallback)
    }

    func testArticleDetailsRejectsMismatchedIDBeforeCaching() async throws {
        let mismatchedPayload = Data(
            String(decoding: TestPayloads.articleDetails, as: UTF8.self)
                .replacingOccurrences(of: "article-remote", with: "different-article")
                .utf8
        )
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: mismatchedPayload, statusCode: 200, headers: [:]))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache
        )

        do {
            _ = try await provider.articleDetails(id: "article-remote")
            XCTFail("A detail response for another article must be rejected")
        } catch {
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.article.id")
            )
        }

        let cacheStoreCount = await cache.storeCount
        XCTAssertEqual(cacheStoreCount, 0)
    }

    func testVisualBriefArticleWithoutPayloadIsRejectedBeforeCaching() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.articleDetailsMissingVisualBrief,
                statusCode: 200,
                headers: [:]
            ))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache
        )

        do {
            _ = try await provider.articleDetails(id: "article-remote")
            XCTFail("A visual-brief article without structured visual data must be rejected")
        } catch {
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.visualBrief")
            )
        }
        let cacheStoreCount = await cache.storeCount
        XCTAssertEqual(cacheStoreCount, 0)
    }

    func testArticlesRejectInvalidEngagementBeforeCaching() async throws {
        let invalidPayload = Data(
            String(decoding: TestPayloads.articles, as: UTF8.self)
                .replacingOccurrences(
                    of: "\"totalReactions\": 202",
                    with: "\"totalReactions\": -1"
                )
                .utf8
        )
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: invalidPayload, statusCode: 200, headers: [:]))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache
        )

        do {
            _ = try await provider.articles()
            XCTFail("Invalid public engagement counts must fail before caching")
        } catch {
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data[0].engagement.totalReactions")
            )
        }
        let cacheStoreCount = await cache.storeCount
        XCTAssertEqual(cacheStoreCount, 0)
    }

    func testArticlesRejectUnsafeHeroMediaBeforeCaching() async throws {
        let invalidPayload = Data(
            String(decoding: TestPayloads.articles, as: UTF8.self)
                .replacingOccurrences(
                    of: "https://media.example.test/articles/hero-remote.jpg?sig=demo",
                    with: "http://media.example.test/articles/hero-remote.jpg"
                )
                .utf8
        )
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: invalidPayload, statusCode: 200, headers: [:]))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache
        )

        do {
            _ = try await provider.articles()
            XCTFail("Unsafe article media must fail before caching")
        } catch {
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data[0].heroMedia.url")
            )
        }
        let cacheStoreCount = await cache.storeCount
        XCTAssertEqual(cacheStoreCount, 0)
    }

    func testPlaybackSessionUsesExplicitCapabilitiesAndNeverFallsBack() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.playbackSession,
                statusCode: 201,
                headers: ["Cache-Control": "no-store"]
            ))
        ])
        let now = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-08-05T12:00:00Z")
        )
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache,
            now: { now }
        )

        let session = try await provider.createPlaybackSession(
            videoID: "video-remote",
            deviceID: "test-device-identifier-1234",
            capabilities: .nativeHLS
        )

        XCTAssertEqual(session.id, "playback-1")
        XCTAssertEqual(session.videoID, "video-remote")
        XCTAssertEqual(session.hlsURL.scheme, "https")
        XCTAssertNil(session.fairPlay)
        XCTAssertFalse(session.isExpired(at: now))
        XCTAssertTrue(session.allowsAirPlay)
        XCTAssertTrue(session.allowsPictureInPicture)
        let method = await client.method(at: 0)
        let contentType = await client.header(named: "Content-Type", at: 0)
        let cacheControl = await client.header(named: "Cache-Control", at: 0)
        let idempotencyKey = await client.header(named: "Idempotency-Key", at: 0)
        let recordedBody = await client.body(at: 0)
        let cacheStoreCount = await cache.storeCount
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(contentType, "application/json")
        XCTAssertEqual(cacheControl, "no-store")
        XCTAssertNotNil(idempotencyKey)
        XCTAssertEqual(cacheStoreCount, 0)

        let body = try XCTUnwrap(recordedBody)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        XCTAssertEqual(json["deviceID"] as? String, "test-device-identifier-1234")
        XCTAssertEqual(json["supportsFairPlay"] as? Bool, false)

        let unavailableClient = SequencedHTTPClient(results: [
            .failure(.networkUnavailable)
        ])
        let unavailableRemote = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: unavailableClient,
            cache: MemorySportsDataCache()
        )
        let fallback = FallbackSportsDataProvider(
            primary: unavailableRemote,
            fallback: MockSportsDataProvider()
        )
        do {
            _ = try await fallback.createPlaybackSession(
                videoID: "video-highlight-1",
                deviceID: "test-device-identifier-1234",
                capabilities: .nativeHLS
            )
            XCTFail("Playback authorization must never be fabricated by fallback data")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .networkUnavailable)
        }
    }

    func testPlaybackSessionRejectsInsecureExpiredAndUnexpectedDRMResponses() async throws {
        let now = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-08-05T12:00:00Z")
        )
        let payloads: [(Data, String)] = [
            (TestPayloads.insecurePlaybackSession, "data.hlsURL"),
            (TestPayloads.expiredPlaybackSession, "data.expiresAt"),
            (TestPayloads.unexpectedFairPlaySession, "data.fairPlay")
        ]

        for (payload, expectedField) in payloads {
            let client = SequencedHTTPClient(results: [
                .success(HTTPResponse(data: payload, statusCode: 201, headers: [:]))
            ])
            let provider = try RemoteSportsDataProvider(
                baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
                client: client,
                cache: MemorySportsDataCache(),
                now: { now }
            )

            do {
                _ = try await provider.createPlaybackSession(
                    videoID: "video-remote",
                    deviceID: "test-device-identifier-1234",
                    capabilities: .nativeHLS
                )
                XCTFail("Expected playback contract violation at \(expectedField)")
            } catch {
                XCTAssertEqual(
                    error as? SportsDataError,
                    .contractViolation(field: expectedField)
                )
            }
        }
    }

    func testPersonalVideoStateRequiresAuthenticationBeforeNetworkAccess() async throws {
        let client = SequencedHTTPClient(results: [])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache()
        )

        do {
            _ = try await provider.continueWatching()
            XCTFail("Personalized media state requires an access token")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .unauthorized)
        }
        do {
            _ = try await provider.notificationPreferences()
            XCTFail("Notification preferences require an access token")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .unauthorized)
        }
        do {
            try await provider.removeWatchHistoryItem(videoID: "video-remote")
            XCTFail("History deletion requires an access token")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .unauthorized)
        }
        let requestCount = await client.requestCount
        XCTAssertEqual(requestCount, 0)
    }

    func testSingleHistoryRemovalIsAuthorizedUncachedIdempotentAndValidatesID() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: Data(), statusCode: 204, headers: [:]))
        ])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            accessTokenProvider: StaticAccessTokenProvider(token: "test-token")
        )

        try await provider.removeWatchHistoryItem(videoID: "video-remote")

        let url = await client.url(at: 0)
        let method = await client.method(at: 0)
        let authorization = await client.header(named: "Authorization", at: 0)
        let cacheControl = await client.header(named: "Cache-Control", at: 0)
        let idempotencyKey = await client.header(named: "Idempotency-Key", at: 0)
        XCTAssertEqual(url?.path, "/v1/me/watch-progress/video-remote")
        XCTAssertEqual(method, "DELETE")
        XCTAssertEqual(authorization, "Bearer test-token")
        XCTAssertEqual(cacheControl, "no-store")
        XCTAssertNotNil(idempotencyKey)

        do {
            try await provider.removeWatchHistoryItem(videoID: "../video-remote")
            XCTFail("Malformed video IDs must be rejected before network access")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .notFound)
        }
        let requestCount = await client.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    func testWatchProgressAndVideoFavoritesAreAuthorizedAndNeverCached() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: TestPayloads.continueWatching, statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: TestPayloads.watchProgress, statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: TestPayloads.updatedWatchProgress, statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: TestPayloads.videos, statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: TestPayloads.videoFavoriteFalse, statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: TestPayloads.videoFavoriteTrue, statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: Data(), statusCode: 204, headers: [:]))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache,
            accessTokenProvider: StaticAccessTokenProvider(token: "test-token")
        )

        let continuing = try await provider.continueWatching()
        let initial = try await provider.watchProgress(videoID: "video-remote")
        let updated = try await provider.saveWatchProgress(
            videoID: "video-remote",
            positionSeconds: 130,
            completed: false
        )
        let favorites = try await provider.favoriteVideos()
        let initialFavorite = try await provider.videoFavorite(videoID: "video-remote")
        let saved = try await provider.setVideoFavorite(videoID: "video-remote", isFavorite: true)
        let removed = try await provider.setVideoFavorite(videoID: "video-remote", isFavorite: false)

        XCTAssertEqual(continuing.first?.percentageCompleted, 40)
        XCTAssertEqual(initial?.positionSeconds, 120)
        XCTAssertEqual(updated.positionSeconds, 130)
        XCTAssertEqual(favorites.first?.id, "video-remote")
        XCTAssertFalse(initialFavorite.isFavorite)
        XCTAssertTrue(saved.isFavorite)
        XCTAssertFalse(removed.isFavorite)
        let cacheStoreCount = await cache.storeCount
        XCTAssertEqual(cacheStoreCount, 0)

        for index in 0..<7 {
            let authorization = await client.header(named: "Authorization", at: index)
            let cacheControl = await client.header(named: "Cache-Control", at: index)
            XCTAssertEqual(authorization, "Bearer test-token")
            XCTAssertEqual(cacheControl, "no-store")
        }
        let progressMethod = await client.method(at: 2)
        let progressIdempotencyKey = await client.header(named: "Idempotency-Key", at: 2)
        let saveFavoriteMethod = await client.method(at: 5)
        let removeFavoriteMethod = await client.method(at: 6)
        XCTAssertEqual(progressMethod, "PUT")
        XCTAssertNotNil(progressIdempotencyKey)
        XCTAssertEqual(saveFavoriteMethod, "PUT")
        XCTAssertEqual(removeFavoriteMethod, "DELETE")

        let recordedBody = await client.body(at: 2)
        let body = try XCTUnwrap(recordedBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["positionSeconds"] as? Int, 130)
        XCTAssertEqual(json["completed"] as? Bool, false)
    }

    func testArticleFavoritesAreAuthorizedUncachedIdempotentAndValidateEchoedState() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: TestPayloads.articles, statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: TestPayloads.articleFavoriteFalse, statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: TestPayloads.articleFavoriteTrue, statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: Data(), statusCode: 204, headers: [:]))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache,
            accessTokenProvider: StaticAccessTokenProvider(token: "test-token")
        )

        let articles = try await provider.favoriteArticles()
        let initial = try await provider.articleFavorite(articleID: "article-remote")
        let saved = try await provider.setArticleFavorite(
            articleID: "article-remote",
            isFavorite: true
        )
        let removed = try await provider.setArticleFavorite(
            articleID: "article-remote",
            isFavorite: false
        )

        XCTAssertEqual(articles.map(\.id), ["article-remote"])
        XCTAssertFalse(initial.isFavorite)
        XCTAssertTrue(saved.isFavorite)
        XCTAssertFalse(removed.isFavorite)
        let cacheStoreCount = await cache.storeCount
        XCTAssertEqual(cacheStoreCount, 0)

        for index in 0..<4 {
            let authorization = await client.header(named: "Authorization", at: index)
            let cacheControl = await client.header(named: "Cache-Control", at: index)
            XCTAssertEqual(
                authorization,
                "Bearer test-token"
            )
            XCTAssertEqual(cacheControl, "no-store")
        }
        let listURL = await client.url(at: 0)
        let saveMethod = await client.method(at: 2)
        let saveKey = await client.header(named: "Idempotency-Key", at: 2)
        let deleteMethod = await client.method(at: 3)
        let deleteKey = await client.header(named: "Idempotency-Key", at: 3)
        XCTAssertEqual(listURL?.path, "/v1/me/article-favorites")
        XCTAssertEqual(listURL?.query, "limit=100")
        XCTAssertEqual(saveMethod, "PUT")
        XCTAssertNotNil(saveKey)
        XCTAssertEqual(deleteMethod, "DELETE")
        XCTAssertNotNil(deleteKey)

        do {
            _ = try await provider.articleFavorite(articleID: "../article-remote")
            XCTFail("Malformed article IDs must be rejected before network access")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .notFound)
        }
        do {
            _ = try await provider.articleFavorite(articleID: "article\nremote")
            XCTFail("Control characters in article IDs must be rejected before network access")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .notFound)
        }
        let requestCount = await client.requestCount
        XCTAssertEqual(requestCount, 4)
    }

    func testArticleFavoriteRejectsMismatchedResponseState() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.articleFavoriteMismatchedID,
                statusCode: 200,
                headers: [:]
            )),
            .success(HTTPResponse(
                data: TestPayloads.articleFavoriteFalse,
                statusCode: 200,
                headers: [:]
            ))
        ])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            accessTokenProvider: StaticAccessTokenProvider(token: "test-token")
        )

        do {
            _ = try await provider.articleFavorite(articleID: "article-remote")
            XCTFail("A mismatched echoed article ID must be rejected")
        } catch {
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.articleId")
            )
        }

        do {
            _ = try await provider.setArticleFavorite(
                articleID: "article-remote",
                isFavorite: true
            )
            XCTFail("A PUT response that is not saved must be rejected")
        } catch {
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.isFavorite")
            )
        }

        let requestCount = await client.requestCount
        XCTAssertEqual(requestCount, 2)
    }

    func testArticleFavoriteRequiresAuthenticationBeforeNetworkAccess() async throws {
        let client = SequencedHTTPClient(results: [])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            accessTokenProvider: NoAccessTokenProvider()
        )

        do {
            _ = try await provider.favoriteArticles()
            XCTFail("Personal article state must require an account session")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .unauthorized)
        }

        let requestCount = await client.requestCount
        XCTAssertEqual(requestCount, 0)
    }

    func testMissingWatchProgressMaps404ToNil() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: Data(), statusCode: 404, headers: [:]))
        ])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            accessTokenProvider: StaticAccessTokenProvider(token: "test-token")
        )

        let progress = try await provider.watchProgress(videoID: "video-remote")

        XCTAssertNil(progress)
    }

    func testHistoryClearAndFollowsAreAuthorizedUncachedAndIdempotent() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: TestPayloads.watchHistory, statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: Data(), statusCode: 204, headers: [:])),
            .success(HTTPResponse(data: TestPayloads.follows, statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: TestPayloads.follow, statusCode: 201, headers: [:])),
            .success(HTTPResponse(data: TestPayloads.follows, statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: Data(), statusCode: 204, headers: [:]))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache,
            accessTokenProvider: StaticAccessTokenProvider(token: "test-token")
        )

        let history = try await provider.watchHistory()
        try await provider.clearWatchHistory()
        let follows = try await provider.follows()
        let created = try await provider.setFollow(
            type: .team,
            entityID: "team-home",
            isFollowing: true
        )
        let removed = try await provider.setFollow(
            type: .team,
            entityID: "team-home",
            isFollowing: false
        )

        XCTAssertTrue(history.first?.progress.completed == true)
        XCTAssertEqual(follows.first?.entityID, "team-home")
        XCTAssertEqual(created?.entityID, "team-home")
        guard case let .team(listedTeam)? = follows.first?.entity,
              case let .team(createdTeam)? = created?.entity else {
            return XCTFail("Expected typed team snapshots")
        }
        XCTAssertEqual(listedTeam.id, "team-home")
        XCTAssertEqual(createdTeam.id, "team-home")
        XCTAssertNil(removed)
        let cacheStoreCount = await cache.storeCount
        XCTAssertEqual(cacheStoreCount, 0)

        for index in 0..<6 {
            let authorization = await client.header(named: "Authorization", at: index)
            let cacheControl = await client.header(named: "Cache-Control", at: index)
            XCTAssertEqual(authorization, "Bearer test-token")
            XCTAssertEqual(cacheControl, "no-store")
        }
        let historyURL = await client.url(at: 0)
        let clearMethod = await client.method(at: 1)
        let clearIdempotencyKey = await client.header(named: "Idempotency-Key", at: 1)
        let createMethod = await client.method(at: 3)
        let createIdempotencyKey = await client.header(named: "Idempotency-Key", at: 3)
        let createBody = await client.body(at: 3)
        let deleteMethod = await client.method(at: 5)
        let deleteIdempotencyKey = await client.header(named: "Idempotency-Key", at: 5)
        XCTAssertEqual(historyURL?.path, "/v1/me/watch-history")
        XCTAssertEqual(clearMethod, "DELETE")
        XCTAssertNotNil(clearIdempotencyKey)
        XCTAssertEqual(createMethod, "POST")
        XCTAssertNotNil(createIdempotencyKey)
        let unwrappedCreateBody = try XCTUnwrap(createBody)
        let createJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: unwrappedCreateBody) as? [String: Any]
        )
        XCTAssertEqual(createJSON["type"] as? String, "TEAM")
        XCTAssertEqual(createJSON["entityId"] as? String, "team-home")
        XCTAssertNil(createJSON["entity"])
        XCTAssertEqual(deleteMethod, "DELETE")
        XCTAssertNotNil(deleteIdempotencyKey)
    }

    func testFollowListDecodesAllEntityTypesAndCanonicalizesServerOrder() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.multiEntityFollows,
                statusCode: 200,
                headers: [:]
            ))
        ])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            accessTokenProvider: StaticAccessTokenProvider(token: "test-token")
        )

        let follows = try await provider.follows()

        XCTAssertEqual(follows.map(\.type), [.competition, .player, .team])
        guard case let .competition(competition)? = follows[0].entity,
              case let .player(player)? = follows[1].entity,
              case let .team(team)? = follows[2].entity else {
            return XCTFail("Expected competition, player, and team snapshots")
        }
        XCTAssertEqual(competition.id, "competition-league")
        XCTAssertEqual(player.id, "player-nine")
        XCTAssertEqual(team.id, "team-home")
    }

    func testFollowListRejectsSnapshotThatDoesNotMatchOuterTarget() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.followWithMismatchedEntity,
                statusCode: 200,
                headers: [:]
            ))
        ])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            accessTokenProvider: StaticAccessTokenProvider(token: "test-token")
        )

        do {
            _ = try await provider.follows()
            XCTFail("A mismatched typed snapshot must reject the complete follow response")
        } catch {
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data[0].entity")
            )
        }
    }

    func testIdentityScopedFollowUsesOnlyTheExpectedAccountsToken() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: TestPayloads.follows, statusCode: 200, headers: [:]))
        ])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            accessTokenProvider: AccountBoundAccessTokenProvider(
                accountID: "account-a",
                token: "account-a-token"
            )
        )

        do {
            _ = try await provider.follows(forAccountID: "account-b")
            XCTFail("A token from a different account must be rejected before network access")
        } catch let error as SportsDataError {
            XCTAssertEqual(error, .unauthorized)
        }
        let requestCountAfterMismatch = await client.requestCount
        XCTAssertEqual(requestCountAfterMismatch, 0)

        let follows = try await provider.follows(forAccountID: "account-a")
        let authorization = await client.header(named: "Authorization", at: 0)
        XCTAssertEqual(follows.map(\.entityID), ["team-home"])
        XCTAssertEqual(authorization, "Bearer account-a-token")
    }

    func testNotificationPreferencesAndAPNsRegistrationArePrivateAndIdempotent() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.notificationPreferences,
                statusCode: 200,
                headers: [:]
            )),
            .success(HTTPResponse(
                data: TestPayloads.notificationPreferencesSubstitutionDisabled,
                statusCode: 200,
                headers: [:]
            )),
            .success(HTTPResponse(data: Data(), statusCode: 204, headers: [:]))
        ])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            accessTokenProvider: StaticAccessTokenProvider(token: "test-token")
        )
        let registration = PushDeviceRegistration(
            installationID: "notification-installation-1234",
            token: String(repeating: "ab", count: 32),
            environment: .sandbox,
            locale: "ar_SA",
            timeZone: "Asia/Riyadh"
        )

        let initial = try await provider.notificationPreferences()
        let updated = try await provider.setNotificationPreference(.substitution, enabled: false)
        try await provider.registerNotificationDevice(registration)

        XCTAssertTrue(initial.goal)
        XCTAssertTrue(initial.yellowCard)
        XCTAssertTrue(initial.redCard)
        XCTAssertTrue(initial.substitution)
        XCTAssertFalse(updated.substitution)
        for index in 0..<3 {
            let authorization = await client.header(named: "Authorization", at: index)
            let cacheControl = await client.header(named: "Cache-Control", at: index)
            XCTAssertEqual(authorization, "Bearer test-token")
            XCTAssertEqual(cacheControl, "no-store")
        }
        let patchMethod = await client.method(at: 1)
        let patchContentType = await client.header(named: "Content-Type", at: 1)
        let patchIdempotencyKey = await client.header(named: "Idempotency-Key", at: 1)
        let registrationMethod = await client.method(at: 2)
        let registrationIdempotencyKey = await client.header(
            named: "Idempotency-Key",
            at: 2
        )
        XCTAssertEqual(patchMethod, "PATCH")
        XCTAssertEqual(patchContentType, "application/merge-patch+json")
        XCTAssertNotNil(patchIdempotencyKey)
        XCTAssertEqual(registrationMethod, "PUT")
        XCTAssertNotNil(registrationIdempotencyKey)
        let registrationURL = await client.url(at: 2)
        XCTAssertEqual(
            registrationURL?.path,
            "/v1/me/notification-devices/notification-installation-1234"
        )
        let patchBodyValue = await client.body(at: 1)
        let patchBody = try XCTUnwrap(patchBodyValue)
        let patchJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: patchBody) as? [String: Any]
        )
        XCTAssertEqual(patchJSON.count, 1)
        XCTAssertEqual(patchJSON["substitution"] as? Bool, false)
        let registrationBodyValue = await client.body(at: 2)
        let registrationBody = try XCTUnwrap(registrationBodyValue)
        let registrationJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: registrationBody) as? [String: Any]
        )
        XCTAssertEqual(registrationJSON["environment"] as? String, "SANDBOX")
        XCTAssertEqual(registrationJSON["locale"] as? String, "ar_SA")
        XCTAssertEqual(registrationJSON["timeZone"] as? String, "Asia/Riyadh")
        XCTAssertEqual(registrationJSON["token"] as? String, registration.token)
    }

    func testNotificationRegistrationRejectsMalformedLocaleBeforeNetwork() async throws {
        let client = SequencedHTTPClient(results: [])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            accessTokenProvider: StaticAccessTokenProvider(token: "test-token")
        )
        let registration = PushDeviceRegistration(
            installationID: "notification-installation-1234",
            token: String(repeating: "ab", count: 32),
            environment: .sandbox,
            locale: "ar SA",
            timeZone: "Asia/Riyadh"
        )

        do {
            try await provider.registerNotificationDevice(registration)
            XCTFail("A locale containing whitespace must be rejected")
        } catch {
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "notificationDevice")
            )
        }
        let requestCount = await client.requestCount
        XCTAssertEqual(requestCount, 0)
    }

    func testWatchHistoryRejectsZeroProgressAndNonDescendingActivity() async throws {
        let cases: [(payload: Data, field: String)] = [
            (TestPayloads.zeroProgressWatchHistory, "data[0].progress.positionSeconds"),
            (TestPayloads.nonDescendingWatchHistory, "data")
        ]

        for testCase in cases {
            let client = SequencedHTTPClient(results: [
                .success(HTTPResponse(data: testCase.payload, statusCode: 200, headers: [:]))
            ])
            let provider = try RemoteSportsDataProvider(
                baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
                client: client,
                cache: MemorySportsDataCache(),
                accessTokenProvider: StaticAccessTokenProvider(token: "test-token")
            )

            do {
                _ = try await provider.watchHistory()
                XCTFail("Expected watch-history contract violation")
            } catch {
                XCTAssertEqual(
                    error as? SportsDataError,
                    .contractViolation(field: testCase.field)
                )
            }
        }
    }

    func testWatchHistoryLoadsEveryCursorPageInGlobalActivityOrder() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.paginatedWatchHistoryFirst,
                statusCode: 200,
                headers: [:]
            )),
            .success(HTTPResponse(
                data: TestPayloads.paginatedWatchHistorySecond,
                statusCode: 200,
                headers: [:]
            ))
        ])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            accessTokenProvider: StaticAccessTokenProvider(token: "test-token")
        )

        let history = try await provider.watchHistory()

        XCTAssertEqual(history.map(\.video.id), ["video-newer", "video-older"])
        let firstURLValue = await client.url(at: 0)
        let secondURLValue = await client.url(at: 1)
        let firstURL = try XCTUnwrap(firstURLValue)
        let secondURL = try XCTUnwrap(secondURLValue)
        let firstComponents = try XCTUnwrap(
            URLComponents(url: firstURL, resolvingAgainstBaseURL: false)
        )
        let secondComponents = try XCTUnwrap(
            URLComponents(url: secondURL, resolvingAgainstBaseURL: false)
        )
        XCTAssertNil(firstComponents.queryItems?.first { $0.name == "cursor" })
        XCTAssertEqual(
            secondComponents.queryItems?.first { $0.name == "cursor" }?.value,
            "history-page-2"
        )
        XCTAssertEqual(
            secondComponents.queryItems?.first { $0.name == "limit" }?.value,
            "100"
        )
    }

    func testFollowListRejectsMoreThanTheBoundedAccountLimit() throws {
        let now = Date()
        let response = FollowListResponseDTO(
            data: (0...500).map { index in
                FollowDTO(
                    id: "follow-\(index)",
                    type: .team,
                    entityId: "team-\(index)",
                    createdAt: now
                )
            }
        )

        XCTAssertThrowsError(try response.domain(now: now)) { error in
            XCTAssertEqual(error as? SportsDataError, .contractViolation(field: "data"))
        }
    }

    func testWithdrawnArticleIsNeverHiddenByMockFallback() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: Data(), statusCode: 410, headers: [:]))
        ])
        let remote = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache()
        )
        let provider = FallbackSportsDataProvider(primary: remote, fallback: MockSportsDataProvider())

        do {
            _ = try await provider.articleDetails(id: "article-1")
            XCTFail("Withdrawn editorial content must remain unavailable")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .contentWithdrawn)
        }
    }

    func testTransferCenterSendsStatusPaginationAndRecordsFreshness() async throws {
        let now = Date(timeIntervalSince1970: 1_786_000_000)
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.transfers,
                statusCode: 200,
                headers: ["ETag": "\"transfers-v1\""]
            ))
        ])
        let freshness = PublicContentFreshnessStore()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            freshnessReporter: freshness,
            now: { now }
        )

        let page = try await provider.transferUpdates(
            cursor: "page-2",
            limit: 30,
            status: .completed
        )
        let capturedURL = await client.url(at: 0)
        let requestURL = try XCTUnwrap(capturedURL)
        let components = try XCTUnwrap(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map {
            ($0.name, $0.value)
        })
        let status = await freshness.status(for: .transfers(status: .completed))

        XCTAssertEqual(requestURL.path, "/v1/transfers")
        XCTAssertEqual(query["cursor"] ?? nil, "page-2")
        XCTAssertEqual(query["limit"] ?? nil, "30")
        XCTAssertEqual(query["status"] ?? nil, "COMPLETED")
        XCTAssertEqual(page.transfers.map(\.id), ["transfer-1"])
        XCTAssertEqual(status, .network(at: now))
    }

    func testTransferCenterRejectsInvalidInputBeforeNetworking() async throws {
        let client = SequencedHTTPClient(results: [])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache()
        )

        do {
            _ = try await provider.transferUpdates(cursor: nil, limit: 101, status: nil)
            XCTFail("Expected page-size validation")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .invalidQuery)
        }
        do {
            _ = try await provider.transferUpdates(cursor: "bad cursor", limit: 30, status: nil)
            XCTFail("Expected cursor validation")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .invalidQuery)
        }
        let requestCount = await client.requestCount
        XCTAssertEqual(requestCount, 0)
    }

    func testTransferCenterRejectsMismatchedStatusBeforeCaching() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: TestPayloads.transfers, statusCode: 200, headers: [:]))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache
        )

        do {
            _ = try await provider.transferUpdates(cursor: nil, limit: 30, status: .rumored)
            XCTFail("A completed transfer must not enter a rumored-only result")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .contractViolation(field: "data.status"))
        }
        let storeCount = await cache.storeCount
        XCTAssertEqual(storeCount, 0)
    }

    func testTransferCenterRejectsUnorderedPageBeforeCaching() async throws {
        let payload = Data(
            #"""
            {
              "data": [
                {
                  "id": "older",
                  "player": {"id": "player-1", "name": "First", "position": "Forward"},
                  "fromTeam": null,
                  "toTeam": {
                    "id": "team-1",
                    "name": {"ar": "الفريق الأول", "en": "First Team"},
                    "monogram": "ONE",
                    "accentColorHex": "006C75"
                  },
                  "transferDate": "2025-06-01",
                  "status": "COMPLETED"
                },
                {
                  "id": "newer",
                  "player": {"id": "player-2", "name": "Second", "position": "Defender"},
                  "fromTeam": null,
                  "toTeam": {
                    "id": "team-2",
                    "name": {"ar": "الفريق الثاني", "en": "Second Team"},
                    "monogram": "TWO",
                    "accentColorHex": "B87912"
                  },
                  "transferDate": "2025-07-01",
                  "status": "COMPLETED"
                }
              ],
              "page": {"nextCursor": null, "hasMore": false}
            }
            """#.utf8
        )
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: payload, statusCode: 200, headers: [:]))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache
        )

        do {
            _ = try await provider.transferUpdates(cursor: nil, limit: 30, status: nil)
            XCTFail("An unordered transfer page must be rejected")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .contractViolation(field: "data.order"))
        }
        let storeCount = await cache.storeCount
        XCTAssertEqual(storeCount, 0)
    }

    func testSeasonCalendarUsesAtomicPathAndRecordsFreshness() async throws {
        let now = Date(timeIntervalSince1970: 1_786_000_000)
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.seasonCalendar,
                statusCode: 200,
                headers: ["ETag": "\"calendar-v1\""]
            ))
        ])
        let freshness = PublicContentFreshnessStore()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            freshnessReporter: freshness,
            now: { now }
        )

        let snapshot = try await provider.seasonCalendar()
        let capturedURL = await client.url(at: 0)
        let requestURL = try XCTUnwrap(capturedURL)
        let status = await freshness.status(for: .seasonCalendar)

        XCTAssertEqual(requestURL.path, "/v1/season-calendar")
        XCTAssertNil(requestURL.query)
        XCTAssertEqual(snapshot.events.map(\.id), ["calendar-draw", "calendar-window"])
        XCTAssertEqual(snapshot.sourceName, "Test calendar provider")
        XCTAssertEqual(status, .network(at: now))
    }

    func testSeasonCalendarRejectsOutOfWindowEventBeforeCaching() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.seasonCalendarOutOfRange,
                statusCode: 200,
                headers: [:]
            ))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache
        )

        do {
            _ = try await provider.seasonCalendar()
            XCTFail("An out-of-window event must not be cached")
        } catch {
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.events.startsAt")
            )
        }
        let storeCount = await cache.storeCount
        XCTAssertEqual(storeCount, 0)
    }

    func testSeasonCalendarRequiresExplicitNullableFieldsBeforeCaching() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.seasonCalendarMissingNullableField,
                statusCode: 200,
                headers: [:]
            ))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache
        )

        do {
            _ = try await provider.seasonCalendar()
            XCTFail("OpenAPI-required nullable keys must not decode when omitted")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .decoding)
        }
        let storeCount = await cache.storeCount
        XCTAssertEqual(storeCount, 0)
    }

    func testDeepSportsEntityContractsAndSeasonQueries() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: TestPayloads.teamDetails, statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: TestPayloads.squad, statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: TestPayloads.playerDetails, statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: TestPayloads.transfers, statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: TestPayloads.standings, statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: TestPayloads.leaders, statusCode: 200, headers: [:]))
        ])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache()
        )

        let team = try await provider.teamDetails(id: "team-home")
        let squad = try await provider.teamSquad(id: "team-home", seasonID: "season-2025")
        let player = try await provider.playerDetails(id: "player-9")
        let transfers = try await provider.playerTransfers(id: "player-9")
        let standings = try await provider.competitionStandings(
            id: "competition-remote",
            seasonID: "season-2025"
        )
        let leaders = try await provider.competitionLeaders(
            id: "competition-remote",
            seasonID: "season-2025",
            category: .goals
        )

        XCTAssertEqual(team.competitions.first?.currentSeasonID, "season-2025")
        XCTAssertEqual(squad.first?.id, "player-9")
        XCTAssertEqual(player.statistics.first?.value, 18)
        XCTAssertEqual(transfers.first?.status, .completed)
        XCTAssertEqual(standings.first?.rows.first?.goalDifference, 20)
        XCTAssertEqual(leaders.first?.player.id, "player-9")

        let standingsURL = await client.url(at: 4)
        let leadersURL = await client.url(at: 5)
        XCTAssertTrue(standingsURL?.absoluteString.contains("seasonId=season-2025") == true)
        XCTAssertTrue(leadersURL?.absoluteString.contains("type=GOALS") == true)
    }

    func testFixtureContextEndpointsAreIndependentCacheableResources() async throws {
        let fixture = try APIJSON.makeDecoder()
            .decode(FixtureDetailResponseDTO.self, from: TestPayloads.fixtureDetails)
            .domain()
            .fixture
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.fixtureStandings,
                statusCode: 200,
                headers: ["ETag": "\"standings-v1\""]
            )),
            .success(HTTPResponse(
                data: TestPayloads.fixtureHeadToHead,
                statusCode: 200,
                headers: ["ETag": "\"h2h-v1\""]
            ))
        ])
        let freshness = PublicContentFreshnessStore()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            freshnessReporter: freshness,
            now: { now }
        )

        let standings = try await provider.fixtureStandings(for: fixture)
        let headToHead = try await provider.fixtureHeadToHead(for: fixture, limit: 10)
        let standingsURL = await client.url(at: 0)
        let headToHeadURL = await client.url(at: 1)
        let standingsCacheControl = await client.header(named: "Cache-Control", at: 0)
        let headToHeadCacheControl = await client.header(named: "Cache-Control", at: 1)
        let standingsFreshness = await freshness.status(
            for: .fixtureStandings(id: fixture.id)
        )
        let headToHeadFreshness = await freshness.status(
            for: .fixtureHeadToHead(id: fixture.id)
        )

        XCTAssertEqual(standingsURL?.path, "/v1/fixtures/fixture-1/standings")
        XCTAssertEqual(headToHeadURL?.path, "/v1/fixtures/fixture-1/head-to-head")
        XCTAssertTrue(headToHeadURL?.absoluteString.contains("limit=10") == true)
        XCTAssertEqual(standingsCacheControl, "no-cache")
        XCTAssertEqual(headToHeadCacheControl, "no-cache")
        XCTAssertEqual(standings.season.id, "season-2025")
        XCTAssertEqual(headToHead.meetings.first?.competition.id, "competition-cup")
        XCTAssertEqual(standingsFreshness, .network(at: now))
        XCTAssertEqual(headToHeadFreshness, .network(at: now))
    }

    func testFixtureContextRejectsUnsafeIDBeforeNetworking() async throws {
        let fixture = Fixture(
            id: "fixture/another-resource",
            competition: MockSportsData.competition,
            homeTeam: MockSportsData.teams[0],
            awayTeam: MockSportsData.teams[1],
            kickoff: Date(),
            state: .finished,
            minute: 90,
            homeScore: 1,
            awayScore: 0,
            venueArabic: "ملعب",
            venueEnglish: "Stadium"
        )
        let client = SequencedHTTPClient(results: [])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache()
        )

        do {
            _ = try await provider.fixtureStandings(for: fixture)
            XCTFail("Expected unsafe fixture ID to be rejected")
        } catch let error as SportsDataError {
            XCTAssertEqual(error, .fixtureNotFound)
        }
        do {
            _ = try await provider.fixtureHeadToHead(for: fixture, limit: 10)
            XCTFail("Expected unsafe fixture ID to be rejected")
        } catch let error as SportsDataError {
            XCTAssertEqual(error, .fixtureNotFound)
        }
        let requestCount = await client.requestCount
        XCTAssertEqual(requestCount, 0)
    }

    func testAuthenticatedHomeIsPrivateAndNeverStoredInPublicCache() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: TestPayloads.home, statusCode: 200, headers: [:]))
        ])
        let cache = RecordingSportsDataCache()
        let freshness = PublicContentFreshnessStore()
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache,
            accessTokenProvider: StaticAccessTokenProvider(token: "test-token"),
            freshnessReporter: freshness,
            now: { now }
        )

        _ = try await provider.homeFeed()
        let authorization = await client.header(named: "Authorization", at: 0)
        let cacheControl = await client.header(named: "Cache-Control", at: 0)
        let cacheStoreCount = await cache.storeCount
        let status = await freshness.status(for: .home)

        XCTAssertEqual(authorization, "Bearer test-token")
        XCTAssertEqual(cacheControl, "no-store")
        XCTAssertEqual(cacheStoreCount, 0)
        XCTAssertEqual(status, .accountLive(checkedAt: now))
    }

    func testCommunityReadsAreUncachedAndMapOptionalIdentity() async throws {
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: TestPayloads.articleComments, statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: TestPayloads.articleReactionAnonymous, statusCode: 200, headers: [:]))
        ])
        let cache = RecordingSportsDataCache()
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: cache,
            now: { now }
        )

        let page = try await provider.articleComments(
            articleID: "article-remote",
            cursor: nil,
            limit: 20
        )
        let reaction = try await provider.articleReaction(articleID: "article-remote")

        XCTAssertEqual(page.comments.map(\.id), ["comment-one"])
        XCTAssertEqual(page.comments.first?.authorID, "author-one")
        XCTAssertFalse(page.comments.first?.isMine ?? true)
        XCTAssertNil(reaction.myReaction)
        XCTAssertEqual(reaction.total(for: .like), 12)
        let cacheStoreCount = await cache.storeCount
        let commentsURL = await client.url(at: 0)
        let reactionURL = await client.url(at: 1)
        XCTAssertEqual(cacheStoreCount, 0)
        XCTAssertEqual(commentsURL?.path, "/v1/articles/article-remote/comments")
        XCTAssertEqual(commentsURL?.query, "limit=20")
        XCTAssertEqual(reactionURL?.path, "/v1/articles/article-remote/reaction")
        for index in 0..<2 {
            let cacheControl = await client.header(named: "Cache-Control", at: index)
            let authorization = await client.header(named: "Authorization", at: index)
            XCTAssertEqual(cacheControl, "no-store")
            XCTAssertNil(authorization)
        }
    }

    func testCommunityMutationsUseAuthorizationIdempotencyAndExactPayloads() async throws {
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: TestPayloads.articleReactionLike, statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: TestPayloads.articleReactionAnonymous, statusCode: 200, headers: [:])),
            .success(HTTPResponse(data: TestPayloads.articleCommentPending, statusCode: 201, headers: [:])),
            .success(HTTPResponse(data: TestPayloads.communityReportReceipt, statusCode: 202, headers: [:])),
            .success(HTTPResponse(data: Data(), statusCode: 204, headers: [:]))
        ])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            accessTokenProvider: StaticAccessTokenProvider(token: "community-token"),
            now: { now }
        )

        let selected = try await provider.setArticleReaction(
            articleID: "article-remote",
            reaction: .like
        )
        let removed = try await provider.setArticleReaction(
            articleID: "article-remote",
            reaction: nil
        )
        let comment = try await provider.createArticleComment(
            articleID: "article-remote",
            body: "  A measured take.  "
        )
        let receipt = try await provider.reportArticleComment(
            commentID: "comment-one",
            reason: .spam,
            details: nil
        )
        try await provider.blockCommunityAuthor(authorID: "author-one")

        XCTAssertEqual(selected.myReaction, .like)
        XCTAssertNil(removed.myReaction)
        XCTAssertEqual(comment.moderationState, .pending)
        XCTAssertEqual(comment.body, "A measured take.")
        XCTAssertEqual(receipt.reportID, "report-one")
        let expectedMethods = ["PUT", "DELETE", "POST", "POST", "PUT"]
        let expectedPaths = [
            "/v1/articles/article-remote/reaction",
            "/v1/articles/article-remote/reaction",
            "/v1/articles/article-remote/comments",
            "/v1/community/comments/comment-one/reports",
            "/v1/me/community-blocks/author-one"
        ]
        for index in expectedMethods.indices {
            let method = await client.method(at: index)
            let url = await client.url(at: index)
            let authorization = await client.header(named: "Authorization", at: index)
            let cacheControl = await client.header(named: "Cache-Control", at: index)
            let idempotencyKey = await client.header(named: "Idempotency-Key", at: index)
            XCTAssertEqual(method, expectedMethods[index])
            XCTAssertEqual(url?.path, expectedPaths[index])
            XCTAssertEqual(authorization, "Bearer community-token")
            XCTAssertEqual(cacheControl, "no-store")
            XCTAssertNotNil(idempotencyKey)
        }

        let recordedReactionBody = await client.body(at: 0)
        let reactionBody = try XCTUnwrap(recordedReactionBody)
        let reactionJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: reactionBody) as? [String: String]
        )
        XCTAssertEqual(reactionJSON, ["type": "LIKE"])
        let recordedCommentBody = await client.body(at: 2)
        let commentBody = try XCTUnwrap(recordedCommentBody)
        let commentJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: commentBody) as? [String: String]
        )
        XCTAssertEqual(commentJSON, ["body": "A measured take."])
        let recordedReportBody = await client.body(at: 3)
        let reportBody = try XCTUnwrap(recordedReportBody)
        let reportJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: reportBody) as? [String: Any]
        )
        XCTAssertEqual(reportJSON["reason"] as? String, "SPAM")
        XCTAssertFalse(reportJSON.keys.contains("details"))
    }

    func testOnlyCommentSubmissionMapsUnprocessableContentToSafeRejection() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: Data(), statusCode: 422, headers: [:])),
            .success(HTTPResponse(data: Data(), statusCode: 422, headers: [:]))
        ])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            accessTokenProvider: StaticAccessTokenProvider(token: "community-token")
        )

        do {
            _ = try await provider.createArticleComment(
                articleID: "article-remote",
                body: "A measured take."
            )
            XCTFail("A filtered comment must produce a safe rejection")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .contentRejected)
        }

        do {
            _ = try await provider.setArticleReaction(
                articleID: "article-remote",
                reaction: .like
            )
            XCTFail("Unrelated 422 responses must retain their HTTP meaning")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .invalidResponse(statusCode: 422))
        }
    }

    func testSubmittedCommentMustBelongToCallerAndCannotAlreadyBeRemoved() async throws {
        let notMine = Data(
            String(decoding: TestPayloads.articleCommentPending, as: UTF8.self)
                .replacingOccurrences(of: "\"isMine\": true", with: "\"isMine\": false")
                .utf8
        )
        let removed = Data(
            String(decoding: TestPayloads.articleCommentPending, as: UTF8.self)
                .replacingOccurrences(
                    of: "\"moderationState\": \"PENDING\"",
                    with: "\"moderationState\": \"REMOVED\""
                )
                .utf8
        )
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(data: notMine, statusCode: 201, headers: [:])),
            .success(HTTPResponse(data: removed, statusCode: 201, headers: [:]))
        ])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            accessTokenProvider: StaticAccessTokenProvider(token: "community-token")
        )

        for (body, field) in [("First", "data.isMine"), ("Second", "data.moderationState")] {
            do {
                _ = try await provider.createArticleComment(
                    articleID: "article-remote",
                    body: body
                )
                XCTFail("Invalid submission ownership/state must be rejected")
            } catch {
                XCTAssertEqual(
                    error as? SportsDataError,
                    .contractViolation(field: field)
                )
            }
        }
    }

    func testScopedCommunityReadUsesOnlyTheCapturedAccountToken() async throws {
        let client = SequencedHTTPClient(results: [
            .success(HTTPResponse(
                data: TestPayloads.articleReactionLike,
                statusCode: 200,
                headers: [:]
            ))
        ])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            accessTokenProvider: AccountBoundAccessTokenProvider(
                accountID: "account-one",
                token: "bound-token"
            )
        )

        let summary = try await provider.articleReaction(
            articleID: "article-remote",
            forAccountID: "account-one"
        )
        let authorization = await client.header(named: "Authorization", at: 0)
        XCTAssertEqual(summary.myReaction, .like)
        XCTAssertEqual(authorization, "Bearer bound-token")

        do {
            _ = try await provider.articleReaction(
                articleID: "article-remote",
                forAccountID: "account-two"
            )
            XCTFail("A stale account identity must fail before networking")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .unauthorized)
        }
        let requestCount = await client.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    func testCommunityRejectsInvalidInputsBeforeNetworking() async throws {
        let client = SequencedHTTPClient(results: [])
        let provider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            accessTokenProvider: StaticAccessTokenProvider(token: "community-token")
        )

        do {
            _ = try await provider.articleComments(
                articleID: "article-remote",
                cursor: "bad cursor",
                limit: 20
            )
            XCTFail("Whitespace cursors must be rejected")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .invalidQuery)
        }
        do {
            _ = try await provider.createArticleComment(articleID: "article-remote", body: "   ")
            XCTFail("Blank comments must be rejected")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .invalidQuery)
        }
        for body in [String(repeating: "a", count: 501), "bad\u{0000}comment"] {
            do {
                _ = try await provider.createArticleComment(
                    articleID: "article-remote",
                    body: body
                )
                XCTFail("Oversized or controlled comments must be rejected")
            } catch {
                XCTAssertEqual(error as? SportsDataError, .invalidQuery)
            }
        }
        do {
            try await provider.blockCommunityAuthor(authorID: "../author")
            XCTFail("Unsafe author IDs must be rejected")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .notFound)
        }
        let requestCount = await client.requestCount
        XCTAssertEqual(requestCount, 0)
    }
}

private actor RecordingSportsDataCache: SportsDataCaching {
    private(set) var storeCount = 0

    func payload(for key: String) -> CachedPayload? {
        nil
    }

    func store(_ payload: CachedPayload, for key: String) {
        storeCount += 1
    }
}

private actor SequencedHTTPClient: HTTPClient {
    private var results: [Result<HTTPResponse, SportsDataError>]
    private var requests: [URLRequest] = []

    init(results: [Result<HTTPResponse, SportsDataError>]) {
        self.results = results
    }

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        requests.append(request)
        guard !results.isEmpty else {
            throw SportsDataError.serverUnavailable
        }
        return try results.removeFirst().get()
    }

    func ifNoneMatchHeader(at index: Int) -> String? {
        guard requests.indices.contains(index) else { return nil }
        return requests[index].value(forHTTPHeaderField: "If-None-Match")
    }

    func url(at index: Int) -> URL? {
        guard requests.indices.contains(index) else { return nil }
        return requests[index].url
    }

    func method(at index: Int) -> String? {
        guard requests.indices.contains(index) else { return nil }
        return requests[index].httpMethod
    }

    func header(named name: String, at index: Int) -> String? {
        guard requests.indices.contains(index) else { return nil }
        return requests[index].value(forHTTPHeaderField: name)
    }

    func body(at index: Int) -> Data? {
        guard requests.indices.contains(index) else { return nil }
        return requests[index].httpBody
    }

    var requestCount: Int { requests.count }
}

private struct AccountBoundAccessTokenProvider: AccessTokenProviding {
    let accountID: String
    let token: String

    func accessToken() async -> String? { token }

    func accessToken(forAccountID accountID: String) async -> String? {
        accountID == self.accountID ? token : nil
    }
}

private enum TestPayloads {
    static let articleComments = Data(
        """
        {
          "data": [{
            "id": "comment-one",
            "articleId": "article-remote",
            "body": "A measured take.",
            "authorId": "author-one",
            "authorDisplayName": "Noura",
            "moderationState": "PUBLISHED",
            "isMine": false,
            "createdAt": "2026-08-05T12:00:00Z"
          }],
          "page": {"nextCursor": null, "hasMore": false}
        }
        """.utf8
    )

    static let articleReactionAnonymous = Data(
        """
        {"data":{"myReaction":null,"totals":{"LIKE":12,"INSIGHTFUL":4,"CELEBRATE":3}}}
        """.utf8
    )

    static let articleReactionLike = Data(
        """
        {"data":{"myReaction":"LIKE","totals":{"LIKE":13,"INSIGHTFUL":4,"CELEBRATE":3}}}
        """.utf8
    )

    static let articleCommentPending = Data(
        """
        {
          "data": {
            "id": "comment-pending",
            "articleId": "article-remote",
            "body": "A measured take.",
            "authorId": "author-current",
            "authorDisplayName": "Current User",
            "moderationState": "PENDING",
            "isMine": true,
            "createdAt": "2026-08-05T12:01:00Z"
          }
        }
        """.utf8
    )

    static let communityReportReceipt = Data(
        """
        {"data":{"reportId":"report-one","status":"RECEIVED","submittedAt":"2026-08-05T12:02:00Z"}}
        """.utf8
    )

    static let notificationPreferences = Data(
        """
        {
          "data": {
            "breakingNews": true,
            "lineup": true,
            "kickoff": true,
            "goal": true,
            "card": true,
            "yellowCard": true,
            "redCard": true,
            "substitution": true,
            "halfTime": true,
            "fullTime": true
          }
        }
        """.utf8
    )

    static let notificationPreferencesSubstitutionDisabled = Data(
        """
        {
          "data": {
            "breakingNews": true,
            "lineup": true,
            "kickoff": true,
            "goal": true,
            "card": true,
            "yellowCard": true,
            "redCard": true,
            "substitution": false,
            "halfTime": true,
            "fullTime": true
          }
        }
        """.utf8
    )

    static let zeroProgressWatchHistory = historyPayload(
        items: [
            historyItem(
                videoID: "video-zero",
                positionSeconds: 0,
                completed: false,
                updatedAt: "2026-08-05T12:00:00Z"
            )
        ]
    )

    static let nonDescendingWatchHistory = historyPayload(
        items: [
            historyItem(
                videoID: "video-older",
                positionSeconds: 10,
                completed: false,
                updatedAt: "2026-08-05T11:00:00Z"
            ),
            historyItem(
                videoID: "video-newer",
                positionSeconds: 20,
                completed: false,
                updatedAt: "2026-08-05T12:00:00Z"
            )
        ]
    )

    static let paginatedWatchHistoryFirst = historyPayload(
        items: [
            historyItem(
                videoID: "video-newer",
                positionSeconds: 20,
                completed: false,
                updatedAt: "2026-08-05T12:00:00Z"
            )
        ],
        nextCursor: "history-page-2",
        hasMore: true
    )

    static let paginatedWatchHistorySecond = historyPayload(
        items: [
            historyItem(
                videoID: "video-older",
                positionSeconds: 10,
                completed: false,
                updatedAt: "2026-08-05T11:00:00Z"
            )
        ]
    )

    static let watchHistory = Data(
        """
        {
          "data": [{
            "video": {
              "id": "video-remote",
              "type": "HIGHLIGHT",
              "title": {"ar": "ملخص المباراة", "en": "Match highlights"},
              "description": {"ar": "وصف", "en": "Description"},
              "durationSeconds": 301,
              "isPlayable": false,
              "availabilityReason": "REGION_BLOCKED"
            },
            "progress": {
              "videoId": "video-remote",
              "positionSeconds": 301,
              "completed": true,
              "updatedAt": "2026-08-05T12:00:00Z"
            }
          }],
          "page": {"nextCursor": null, "hasMore": false}
        }
        """.utf8
    )

    private static func historyPayload(
        items: [String],
        nextCursor: String? = nil,
        hasMore: Bool = false
    ) -> Data {
        let encodedCursor = nextCursor.map { "\"\($0)\"" } ?? "null"
        return Data(
            """
            {
              "data": [\(items.joined(separator: ","))],
              "page": {"nextCursor": \(encodedCursor), "hasMore": \(hasMore)}
            }
            """.utf8
        )
    }

    private static func historyItem(
        videoID: String,
        positionSeconds: Int,
        completed: Bool,
        updatedAt: String
    ) -> String {
        """
        {
          "video": {
            "id": "\(videoID)",
            "type": "HIGHLIGHT",
            "title": {"ar": "فيديو", "en": "Video"},
            "description": {"ar": "وصف", "en": "Description"},
            "durationSeconds": 301,
            "isPlayable": false,
            "availabilityReason": "REGION_BLOCKED"
          },
          "progress": {
            "videoId": "\(videoID)",
            "positionSeconds": \(positionSeconds),
            "completed": \(completed),
            "updatedAt": "\(updatedAt)"
          }
        }
        """
    }

    static let follows = Data(
        """
        {
          "data": [{
            "id": "follow-team-home",
            "type": "TEAM",
            "entityId": "team-home",
            "createdAt": "2026-08-05T12:00:00Z",
            "entity": {
              "type": "TEAM",
              "team": {
                "id": "team-home",
                "name": {"ar": "الفريق الأول", "en": "Home Team"},
                "monogram": "HOM",
                "accentColorHex": "006c75"
              }
            }
          }]
        }
        """.utf8
    )

    static let follow = Data(
        """
        {
          "data": {
            "id": "follow-team-home",
            "type": "TEAM",
            "entityId": "team-home",
            "createdAt": "2026-08-05T12:00:00Z",
            "entity": {
              "type": "TEAM",
              "team": {
                "id": "team-home",
                "name": {"ar": "الفريق الأول", "en": "Home Team"},
                "monogram": "HOM",
                "accentColorHex": "006c75"
              }
            }
          }
        }
        """.utf8
    )

    static let multiEntityFollows = Data(
        """
        {
          "data": [
            {
              "id": "follow-team-home",
              "type": "TEAM",
              "entityId": "team-home",
              "createdAt": "2026-08-05T12:00:00Z",
              "entity": {
                "type": "TEAM",
                "team": {
                  "id": "team-home",
                  "name": {"ar": "الفريق الأول", "en": "Home Team"},
                  "monogram": "HOM",
                  "accentColorHex": "006c75"
                }
              }
            },
            {
              "id": "follow-competition-league",
              "type": "COMPETITION",
              "entityId": "competition-league",
              "createdAt": "2026-08-05T14:00:00Z",
              "entity": {
                "type": "COMPETITION",
                "competition": {
                  "id": "competition-league",
                  "name": {"ar": "الدوري", "en": "League"},
                  "sport": "FOOTBALL"
                }
              }
            },
            {
              "id": "follow-player-nine",
              "type": "PLAYER",
              "entityId": "player-nine",
              "createdAt": "2026-08-05T13:00:00Z",
              "entity": {
                "type": "PLAYER",
                "player": {
                  "id": "player-nine",
                  "name": "Player Nine",
                  "position": "Forward"
                }
              }
            }
          ]
        }
        """.utf8
    )

    static let followWithMismatchedEntity = Data(
        """
        {
          "data": [{
            "id": "follow-team-home",
            "type": "TEAM",
            "entityId": "team-home",
            "createdAt": "2026-08-05T12:00:00Z",
            "entity": {
              "type": "PLAYER",
              "player": {
                "id": "player-9",
                "name": "Player Nine",
                "position": "Forward"
              }
            }
          }]
        }
        """.utf8
    )

    static let continueWatching = Data(
        """
        {
          "data": [{
            "video": {
              "id": "video-remote",
              "type": "HIGHLIGHT",
              "title": {"ar": "ملخص المباراة", "en": "Match highlights"},
              "description": {"ar": "وصف", "en": "Description"},
              "durationSeconds": 301,
              "isPlayable": false,
              "availabilityReason": "REGION_BLOCKED"
            },
            "progress": {
              "videoId": "video-remote",
              "positionSeconds": 120,
              "completed": false,
              "updatedAt": "2026-08-05T12:00:00Z"
            }
          }],
          "page": {"nextCursor": null, "hasMore": false}
        }
        """.utf8
    )

    static let watchProgress = Data(
        """
        {
          "data": {
            "videoId": "video-remote",
            "positionSeconds": 120,
            "completed": false,
            "updatedAt": "2026-08-05T12:00:00Z"
          }
        }
        """.utf8
    )

    static let updatedWatchProgress = Data(
        """
        {
          "data": {
            "videoId": "video-remote",
            "positionSeconds": 130,
            "completed": false,
            "updatedAt": "2026-08-05T12:01:00Z"
          }
        }
        """.utf8
    )

    static let videoFavoriteFalse = Data(
        """
        {
          "data": {
            "videoId": "video-remote",
            "isFavorite": false,
            "updatedAt": null
          }
        }
        """.utf8
    )

    static let videoFavoriteTrue = Data(
        """
        {
          "data": {
            "videoId": "video-remote",
            "isFavorite": true,
            "updatedAt": "2026-08-05T12:02:00Z"
          }
        }
        """.utf8
    )

    static let articleFavoriteFalse = Data(
        """
        {
          "data": {
            "articleId": "article-remote",
            "isFavorite": false,
            "updatedAt": null
          }
        }
        """.utf8
    )

    static let articleFavoriteTrue = Data(
        """
        {
          "data": {
            "articleId": "article-remote",
            "isFavorite": true,
            "updatedAt": "2026-08-05T12:02:00Z"
          }
        }
        """.utf8
    )

    static let articleFavoriteMismatchedID = Data(
        """
        {
          "data": {
            "articleId": "different-article",
            "isFavorite": true,
            "updatedAt": "2026-08-05T12:02:00Z"
          }
        }
        """.utf8
    )

    static let playbackSession = Data(
        """
        {
          "data": {
            "id": "playback-1",
            "hlsURL": "https://media.example.test/session/master.m3u8?token=short-lived",
            "fairPlayCertificateURL": null,
            "fairPlayLicenseURL": null,
            "expiresAt": "2026-08-05T12:10:00Z",
            "allowsAirPlay": true,
            "allowsPictureInPicture": true
          }
        }
        """.utf8
    )

    static let insecurePlaybackSession = Data(
        """
        {
          "data": {
            "id": "playback-insecure",
            "hlsURL": "http://media.example.test/master.m3u8",
            "fairPlayCertificateURL": null,
            "fairPlayLicenseURL": null,
            "expiresAt": "2026-08-05T12:10:00Z",
            "allowsAirPlay": false,
            "allowsPictureInPicture": false
          }
        }
        """.utf8
    )

    static let expiredPlaybackSession = Data(
        """
        {
          "data": {
            "id": "playback-expired",
            "hlsURL": "https://media.example.test/master.m3u8",
            "fairPlayCertificateURL": null,
            "fairPlayLicenseURL": null,
            "expiresAt": "2026-08-05T11:59:59Z",
            "allowsAirPlay": false,
            "allowsPictureInPicture": false
          }
        }
        """.utf8
    )

    static let unexpectedFairPlaySession = Data(
        """
        {
          "data": {
            "id": "playback-drm",
            "hlsURL": "https://media.example.test/master.m3u8",
            "fairPlayCertificateURL": "https://license.example.test/certificate",
            "fairPlayLicenseURL": "https://license.example.test/license",
            "expiresAt": "2026-08-05T12:10:00Z",
            "allowsAirPlay": false,
            "allowsPictureInPicture": false
          }
        }
        """.utf8
    )

    static let home = Data(
        """
        {
          "data": {
            "generatedAt": "2026-08-05T12:00:00Z",
            "featuredFixtures": [\(fixtureJSON)],
            "articles": [{
              "id": "article-1",
              "title": {"ar": "خبر عاجل", "en": "Breaking news"},
              "summary": {"ar": "ملخص", "en": "Summary"},
              "source": "SportsHub Desk",
              "publishedAt": "2026-08-05T11:00:00Z",
              "category": "BREAKING"
            }]
          }
        }
        """.utf8
    )

    static let fixtures = Data(
        """
        {
          "data": [\(fixtureJSON)],
          "page": {"nextCursor": null, "hasMore": false}
        }
        """.utf8
    )

    static func teamMatchSnapshots(ids: [String]) -> Data {
        let items = ids.map { id in
            """
            {
              "team": {
                "id": "\(id)",
                "name": {"ar": "فريق", "en": "Team \(id)"},
                "monogram": "TM",
                "accentColorHex": "006C75"
              },
              "previousFixture": null,
              "nextFixture": null
            }
            """
        }
        return Data(
            """
            {"data": [\(items.joined(separator: ","))]}
            """.utf8
        )
    }

    static func competitionFixturePage(
        competitionID: String = "competition-1",
        seasonID: String = "season-2025",
        fixtures: [(id: String, kickoff: String)],
        nextCursor: String? = nil,
        hasMore: Bool = false
    ) -> Data {
        let items = fixtures.map { item in
            fixtureJSON
                .replacingOccurrences(of: "\"fixture-1\"", with: "\"\(item.id)\"")
                .replacingOccurrences(of: "\"competition-1\"", with: "\"\(competitionID)\"")
                .replacingOccurrences(
                    of: "\"2026-08-05T12:00:00Z\"",
                    with: "\"\(item.kickoff)\""
                )
        }
        let encodedCursor = nextCursor.map { "\"\($0)\"" } ?? "null"
        return Data(
            """
            {
              "competitionId": "\(competitionID)",
              "seasonId": "\(seasonID)",
              "data": [\(items.joined(separator: ","))],
              "page": {"nextCursor": \(encodedCursor), "hasMore": \(hasMore)}
            }
            """.utf8
        )
    }

    static let teams = Data(
        """
        {
          "data": [{
            "id": "team-home",
            "name": {"ar": "الفريق الأول", "en": "Home Team"},
            "monogram": "HOM",
            "accentColorHex": "006c75"
          }],
          "page": {"nextCursor": null, "hasMore": false}
        }
        """.utf8
    )

    static let fixtureDetails = Data(
        """
        {
          "data": {
            "fixture": \(fixtureJSON),
            "events": [
              {
                "id": "event-goal",
                "revision": 1,
                "minute": 37,
                "addedTime": null,
                "type": "GOAL",
                "title": {"ar": "هدف", "en": "Goal"},
                "detail": {"ar": "تفاصيل", "en": "Details"},
                "isDeleted": false
              },
              {
                "id": "event-retracted",
                "revision": 2,
                "minute": 41,
                "type": "RED_CARD",
                "title": {"ar": "محذوف", "en": "Retracted"},
                "detail": {"ar": "محذوف", "en": "Retracted"},
                "isDeleted": true
              }
            ],
            "lineups": {
              "home": [{"id": "player-1", "number": 1, "name": "Keeper", "position": "GOALKEEPER"}],
              "away": [{"id": "player-2", "number": 9, "name": "Forward", "position": "FORWARD"}]
            },
            "statistics": [{
              "id": "possession",
              "type": "POSSESSION",
              "homeValue": 55,
              "awayValue": 45,
              "unit": "%"
            }],
            "source": {"name": "Licensed Data Partner"},
            "updatedAt": "2026-08-05T13:00:00Z"
          }
        }
        """.utf8
    )

    static let fixtureEventUpdates = Data(
        """
        {
          "data": [
            {
              "id": "event-goal",
              "revision": 4,
              "minute": 36,
              "addedTime": 1,
              "type": "GOAL",
              "title": {"ar": "هدف مصحح", "en": "Corrected goal"},
              "detail": {"ar": "تفاصيل مصححة", "en": "Corrected details"},
              "teamId": "team-home",
              "playerId": "player-9",
              "secondaryPlayerId": null,
              "isDeleted": false
            },
            {
              "id": "event-yellow",
              "revision": 5,
              "minute": 40,
              "addedTime": null,
              "type": "YELLOW_CARD",
              "title": {"ar": "بطاقة ملغاة", "en": "Retracted card"},
              "detail": {"ar": "تم الإلغاء", "en": "Retracted"},
              "teamId": "team-away",
              "playerId": "player-4",
              "secondaryPlayerId": null,
              "isDeleted": true
            }
          ],
          "fixture": {
            "id": "fixture-1",
            "competition": {
              "id": "competition-1",
              "name": {"ar": "الدوري", "en": "League"},
              "sport": "FOOTBALL"
            },
            "homeTeam": {
              "id": "team-home",
              "name": {"ar": "الفريق الأول", "en": "Home Team"},
              "monogram": "HOM",
              "accentColorHex": "006C75"
            },
            "awayTeam": {
              "id": "team-away",
              "name": {"ar": "الفريق الثاني", "en": "Away Team"},
              "monogram": "AWY",
              "accentColorHex": "9B5B00"
            },
            "kickoffAt": "2026-08-05T12:00:00Z",
            "state": "LIVE",
            "minute": 64,
            "score": {"home": 2, "away": 0},
            "venue": {"ar": "الملعب", "en": "Stadium"},
            "revision": 5
          },
          "fixtureRevision": 5,
          "updatedAt": "2026-08-05T13:02:00Z"
        }
        """.utf8
    )

    static let fixtureEventUpdatesOutOfOrder = Data(
        """
        {
          "data": [
            {
              "id": "event-five",
              "revision": 5,
              "minute": 50,
              "addedTime": null,
              "type": "VAR",
              "title": {"ar": "مراجعة", "en": "Review"},
              "detail": {"ar": "تفاصيل", "en": "Details"},
              "isDeleted": false
            },
            {
              "id": "event-four",
              "revision": 4,
              "minute": 49,
              "addedTime": null,
              "type": "YELLOW_CARD",
              "title": {"ar": "بطاقة", "en": "Card"},
              "detail": {"ar": "تفاصيل", "en": "Details"},
              "isDeleted": false
            }
          ],
          "fixture": {
            "id": "fixture-1",
            "competition": {
              "id": "competition-1",
              "name": {"ar": "الدوري", "en": "League"},
              "sport": "FOOTBALL"
            },
            "homeTeam": {
              "id": "team-home",
              "name": {"ar": "الفريق الأول", "en": "Home Team"},
              "monogram": "HOM",
              "accentColorHex": "006C75"
            },
            "awayTeam": {
              "id": "team-away",
              "name": {"ar": "الفريق الثاني", "en": "Away Team"},
              "monogram": "AWY",
              "accentColorHex": "9B5B00"
            },
            "kickoffAt": "2026-08-05T12:00:00Z",
            "state": "LIVE",
            "minute": 64,
            "score": {"home": 2, "away": 0},
            "venue": {"ar": "الملعب", "en": "Stadium"},
            "revision": 5
          },
          "fixtureRevision": 5,
          "updatedAt": "2026-08-05T13:02:00Z"
        }
        """.utf8
    )

    static let competitions = Data(
        """
        {
          "data": [{
            "id": "competition-remote",
            "name": {"ar": "الدوري", "en": "League"},
            "sport": "FOOTBALL"
          }],
          "page": {"nextCursor": null, "hasMore": false}
        }
        """.utf8
    )

    static let articles = Data(
        """
        {
          "data": [{
            "id": "article-remote",
            "title": {"ar": "خبر", "en": "News"},
            "summary": {"ar": "ملخص", "en": "Summary"},
            "source": "Licensed Desk",
            "publishedAt": "2026-08-05T12:00:00Z",
            "category": "ANALYSIS",
            "format": "VISUAL_BRIEF",
            "correctionStatus": "CORRECTED",
            "engagement": {"totalReactions": 202, "publishedComments": 3},
            "heroMedia": {
              "id": "hero-remote",
              "url": "https://media.example.test/articles/hero-remote.jpg?sig=demo",
              "contentType": "image/jpeg",
              "width": 1600,
              "height": 900,
              "altText": {"ar": "لاعب تجريبي في الملعب", "en": "A fictional player on the pitch"},
              "credit": {"ar": "استوديو الرياضة البعيد", "en": "Remote Sports Studio"}
            }
          }],
          "page": {"nextCursor": null, "hasMore": false}
        }
        """.utf8
    )

    static let articleDetails = Data(
        """
        {
          "data": {
            "id": "article-remote",
            "title": {"ar": "خبر", "en": "News"},
            "summary": {"ar": "ملخص", "en": "Summary"},
            "source": "Licensed Desk",
            "publishedAt": "2026-08-05T12:00:00Z",
            "category": "ANALYSIS",
            "format": "VISUAL_BRIEF",
            "correctionStatus": "CORRECTED",
            "engagement": {"totalReactions": 202, "publishedComments": 3},
            "heroMedia": {
              "id": "hero-remote",
              "url": "https://media.example.test/articles/hero-remote.jpg?sig=demo",
              "contentType": "image/jpeg",
              "width": 1600,
              "height": 900,
              "altText": {"ar": "لاعب تجريبي في الملعب", "en": "A fictional player on the pitch"},
              "credit": {"ar": "استوديو الرياضة البعيد", "en": "Remote Sports Studio"}
            },
            "body": {"ar": "نص الخبر", "en": "Article body"},
            "revision": 2,
            "visualBrief": {
              "title": {"ar": "أرقام المباراة", "en": "Match numbers"},
              "sourceNote": {"ar": "بيانات تجريبية", "en": "Demo data"},
              "sections": [{
                "id": "match-pulse",
                "kind": "METRIC_GRID",
                "title": {"ar": "نبض المباراة", "en": "Match pulse"},
                "items": [
                  {
                    "id": "metric-shots",
                    "value": {"ar": "١٤", "en": "14"},
                    "label": {"ar": "تسديدة", "en": "Shots"}
                  },
                  {
                    "id": "metric-possession",
                    "value": {"ar": "٥٨٪", "en": "58%"},
                    "label": {"ar": "استحواذ", "en": "Possession"}
                  }
                ]
              }, {
                "id": "set-pieces",
                "kind": "COMPARISON",
                "title": {"ar": "الكرات الثابتة", "en": "Set pieces"},
                "items": [
                  {
                    "id": "comparison-home",
                    "value": {"ar": "٦", "en": "6"},
                    "label": {"ar": "صقور الرياض", "en": "Riyadh Falcons"}
                  },
                  {
                    "id": "comparison-away",
                    "value": {"ar": "٤", "en": "4"},
                    "label": {"ar": "أمواج جدة", "en": "Jeddah Waves"}
                  }
                ]
              }]
            }
          }
        }
        """.utf8
    )

    static let articleDetailsMissingVisualBrief = Data(
        """
        {
          "data": {
            "id": "article-remote",
            "title": {"ar": "خبر", "en": "News"},
            "summary": {"ar": "ملخص", "en": "Summary"},
            "source": "Licensed Desk",
            "publishedAt": "2026-08-05T12:00:00Z",
            "category": "ANALYSIS",
            "format": "VISUAL_BRIEF",
            "correctionStatus": "ORIGINAL",
            "engagement": {"totalReactions": 202, "publishedComments": 3},
            "body": {"ar": "نص الخبر", "en": "Article body"},
            "revision": 1
          }
        }
        """.utf8
    )

    static let videos = Data(
        """
        {
          "data": [{
            "id": "video-remote",
            "type": "HIGHLIGHT",
            "title": {"ar": "ملخص المباراة", "en": "Match highlights"},
            "description": {"ar": "وصف", "en": "Description"},
            "poster": {
              "id": "poster-video-remote",
              "url": "https://media.example.test/videos/poster-video-remote.jpg?sig=demo",
              "contentType": "image/jpeg",
              "width": 1600,
              "height": 900,
              "altText": {"ar": "مقدم تجريبي", "en": "A fictional presenter"},
              "credit": {"ar": "استوديو الفيديو البعيد", "en": "Remote Video Studio"}
            },
            "durationSeconds": 301,
            "isPlayable": false,
            "availabilityReason": "REGION_BLOCKED"
          }],
          "page": {"nextCursor": null, "hasMore": false}
        }
        """.utf8
    )

    static let videoDiscovery = Data(
        """
        {
          "data": {
            "items": [
              {
                "video": {
                  "id": "video-original",
                  "type": "ORIGINAL",
                  "title": {"ar": "عمل أصلي", "en": "Original show"},
                  "description": {"ar": "وصف", "en": "Description"},
                  "durationSeconds": 1200,
                  "isPlayable": false,
                  "availabilityReason": "NOT_STARTED"
                },
                "sport": "FOOTBALL"
              },
              {
                "video": {
                  "id": "video-highlight",
                  "type": "HIGHLIGHT",
                  "title": {"ar": "ملخص", "en": "Highlights"},
                  "description": {"ar": "وصف", "en": "Description"},
                  "durationSeconds": 300,
                  "isPlayable": false,
                  "availabilityReason": "REGION_BLOCKED"
                },
                "sport": "FOOTBALL"
              },
              {
                "video": {
                  "id": "video-esports",
                  "type": "INTERVIEW",
                  "title": {"ar": "رياضات إلكترونية", "en": "Esports"},
                  "description": {"ar": "وصف", "en": "Description"},
                  "durationSeconds": 480,
                  "isPlayable": false,
                  "availabilityReason": "ENTITLEMENT_REQUIRED"
                },
                "sport": "ESPORTS"
              }
            ],
            "featuredVideoId": "video-original",
            "trendingVideoIds": ["video-esports", "video-highlight"]
          }
        }
        """.utf8
    )

    static func videoPage(
        videos: [(id: String, type: String)],
        nextCursor: String? = nil,
        hasMore: Bool = false
    ) -> Data {
        let items = videos.map { video in
            """
            {
              "id": "\(video.id)",
              "type": "\(video.type)",
              "title": {"ar": "عنوان \(video.id)", "en": "Title \(video.id)"},
              "description": {"ar": "وصف تجريبي", "en": "Demo description"},
              "durationSeconds": 300,
              "isPlayable": false,
              "availabilityReason": "ENTITLEMENT_REQUIRED"
            }
            """
        }
        let encodedCursor = nextCursor.map { "\"\($0)\"" } ?? "null"
        return Data(
            """
            {
              "data": [\(items.joined(separator: ","))],
              "page": {"nextCursor": \(encodedCursor), "hasMore": \(hasMore)}
            }
            """.utf8
        )
    }

    static let videoDetails = makeVideoDetails(responseID: "video-remote")
    static let mismatchedVideoDetails = makeVideoDetails(responseID: "another-video")

    static let videoPrograms = Data(
        """
        {
          "data": [
            {
              "id": "program-remote",
              "title": {"ar": "برنامج بعيد", "en": "Remote Program"},
              "description": {"ar": "وصف تحريري", "en": "Editorial description"},
              "sport": "ESPORTS",
              "featuredVideo": null
            },
            {
              "id": "program-second",
              "title": {"ar": "برنامج ثان", "en": "Second Program"},
              "description": {"ar": "وصف ثان", "en": "Second description"},
              "sport": "FOOTBALL",
              "featuredVideo": null
            }
          ],
          "page": {"nextCursor": null, "hasMore": false}
        }
        """.utf8
    )

    static let videoProgramDetails = makeVideoProgramDetails(
        responseID: "program-remote"
    )
    static let mismatchedVideoProgramDetails = makeVideoProgramDetails(
        responseID: "program-other"
    )

    private static func makeVideoProgramDetails(responseID: String) -> Data {
        Data(
            """
            {
              "data": {
                "program": {
                  "id": "\(responseID)",
                  "title": {"ar": "برنامج بعيد", "en": "Remote Program"},
                  "description": {"ar": "وصف تحريري", "en": "Editorial description"},
                  "sport": "ESPORTS",
                  "featuredVideo": null
                },
                "episodes": [
                  {
                    "video": {
                      "id": "episode-remote",
                      "type": "ORIGINAL",
                      "title": {"ar": "حلقة بعيدة", "en": "Remote Episode"},
                      "description": {"ar": "وصف", "en": "Description"},
                      "poster": null,
                      "durationSeconds": 300,
                      "isPlayable": false,
                      "availabilityReason": "REGION_BLOCKED"
                    },
                    "publishedAt": null
                  }
                ],
                "page": {"nextCursor": null, "hasMore": false}
              }
            }
            """.utf8
        )
    }

    private static func makeVideoDetails(responseID: String) -> Data {
        Data(
            """
        {
          "data": {
            "id": "\(responseID)",
            "type": "HIGHLIGHT",
            "title": {"ar": "ملخص المباراة", "en": "Match highlights"},
            "description": {"ar": "وصف", "en": "Description"},
            "poster": {
              "id": "poster-video-remote",
              "url": "https://media.example.test/videos/poster-video-remote.jpg?sig=demo",
              "contentType": "image/jpeg",
              "width": 1600,
              "height": 900,
              "altText": {"ar": "مقدم تجريبي", "en": "A fictional presenter"},
              "credit": {"ar": "استوديو الفيديو البعيد", "en": "Remote Video Studio"}
            },
            "durationSeconds": 301,
            "isPlayable": false,
            "availabilityReason": "REGION_BLOCKED",
            "publishedAt": "2026-08-05T13:00:00Z",
            "audioLanguages": ["ar", "en"],
            "subtitleLanguages": ["ar"],
            "publisher": {"ar": "مكتب الرياضة", "en": "Remote Sports Desk"},
            "program": {
              "id": "program-remote",
              "title": {"ar": "استوديو المباراة", "en": "Match Studio"}
            },
            "relatedVideos": [
              {
                "id": "video-related-one",
                "type": "REPLAY",
                "title": {"ar": "إعادة تجريبية", "en": "Demo replay"},
                "description": {"ar": "وصف تجريبي", "en": "Demo description"},
                "durationSeconds": 5400,
                "isPlayable": false,
                "availabilityReason": "REGION_BLOCKED"
              },
              {
                "id": "video-related-two",
                "type": "INTERVIEW",
                "title": {"ar": "مقابلة تجريبية", "en": "Demo interview"},
                "description": {"ar": "وصف تجريبي", "en": "Demo description"},
                "durationSeconds": 620,
                "isPlayable": false,
                "availabilityReason": "ENTITLEMENT_REQUIRED"
              }
            ]
          }
        }
        """.utf8
        )
    }

    static let search = Data(
        """
        {
          "data": [
            {
              "type": "ARTICLE",
              "entityId": "article-remote",
              "title": {"ar": "خبر الهلال", "en": "Al Hilal news"},
              "subtitle": {"ar": "تحليل", "en": "Analysis"}
            },
            {
              "type": "TEAM",
              "entityId": "team-hilal",
              "title": {"ar": "الهلال", "en": "Al Hilal"},
              "subtitle": null
            }
          ],
          "page": {"nextCursor": null, "hasMore": false}
        }
        """.utf8
    )

    static let teamDetails = Data(
        """
        {
          "data": {
            "team": \(teamJSON),
            "competitions": [\(competitionWithSeasonJSON)],
            "nextFixtures": [{
              "id": "team-next-1",
              "competition": \(competitionWithSeasonJSON),
              "homeTeam": \(teamJSON),
              "awayTeam": {
                "id": "team-away",
                "name": {"ar": "الفريق الثاني", "en": "Away Team"},
                "monogram": "AWY",
                "accentColorHex": "9B5B00"
              },
              "kickoffAt": "2026-08-08T12:00:00Z",
              "state": "SCHEDULED",
              "minute": null,
              "score": null,
              "venue": {"ar": "الملعب", "en": "Stadium"},
              "revision": 0
            }],
            "recentFixtures": []
          }
        }
        """.utf8
    )

    static let teamContent = Data(
        """
        {
          "data": {
            "teamId": "team-home",
            "articles": [{
              "id": "article-remote",
              "title": {"ar": "خبر", "en": "News"},
              "summary": {"ar": "ملخص", "en": "Summary"},
              "source": "Licensed Desk",
              "publishedAt": "2026-08-05T12:00:00Z",
              "category": "ANALYSIS",
              "format": "STORY",
              "correctionStatus": "ORIGINAL",
              "engagement": {"totalReactions": 8, "publishedComments": 1}
            }],
            "videos": [{
              "id": "video-remote",
              "type": "HIGHLIGHT",
              "title": {"ar": "ملخص المباراة", "en": "Match highlights"},
              "description": {"ar": "وصف", "en": "Description"},
              "durationSeconds": 301,
              "isPlayable": false,
              "availabilityReason": "REGION_BLOCKED"
            }]
          }
        }
        """.utf8
    )

    static let playerContent = Data(
        String(decoding: teamContent, as: UTF8.self)
            .replacingOccurrences(of: "\"teamId\"", with: "\"playerId\"")
            .replacingOccurrences(of: "\"team-home\"", with: "\"player-one\"")
            .utf8
    )

    static let competitionContent = Data(
        String(decoding: teamContent, as: UTF8.self)
            .replacingOccurrences(of: "\"teamId\"", with: "\"competitionId\"")
            .replacingOccurrences(
                of: "\"team-home\"",
                with: "\"competition-one\""
            )
            .utf8
    )

    static let fixtureContent = Data(
        """
        {
          "data": {
            "fixtureId": "fixture-1",
            "moments": [{
              "id": "moment-remote",
              "title": {"ar": "لحظة تجريبية", "en": "Demo moment"},
              "minute": 52,
              "video": {
                "id": "video-remote",
                "type": "HIGHLIGHT",
                "title": {"ar": "ملخص المباراة", "en": "Match highlights"},
                "description": {"ar": "وصف", "en": "Description"},
                "durationSeconds": 301,
                "isPlayable": false,
                "availabilityReason": "REGION_BLOCKED"
              }
            }],
            "articles": [{
              "id": "article-remote",
              "title": {"ar": "تقرير", "en": "Report"},
              "summary": {"ar": "ملخص", "en": "Summary"},
              "source": "Licensed Desk",
              "publishedAt": "2026-08-05T12:00:00Z",
              "category": "MATCH_REPORT",
              "format": "STORY",
              "correctionStatus": "ORIGINAL",
              "engagement": {"totalReactions": 5, "publishedComments": 0}
            }]
          }
        }
        """.utf8
    )

    static let squad = Data(
        """
        {
          "data": [{"id": "player-9", "name": "Demo Striker", "position": "Forward"}],
          "page": {"nextCursor": null, "hasMore": false}
        }
        """.utf8
    )

    static let players = squad

    static let duplicatePlayers = Data(
        """
        {
          "data": [
            {"id": "player-9", "name": "Demo Striker", "position": "Forward"},
            {"id": "player-9", "name": "Duplicate Striker", "position": "Forward"}
          ],
          "page": {"nextCursor": null, "hasMore": false}
        }
        """.utf8
    )

    static let playerDetails = Data(
        """
        {
          "data": {
            "player": {"id": "player-9", "name": "Demo Striker", "position": "Forward"},
            "currentTeam": \(teamJSON),
            "statistics": [{"name": "Goals", "value": 18}]
          }
        }
        """.utf8
    )

    static let transfers = Data(
        """
        {
          "data": [{
            "id": "transfer-1",
            "player": {"id": "player-9", "name": "Demo Striker", "position": "Forward"},
            "fromTeam": null,
            "toTeam": \(teamJSON),
            "transferDate": "2025-07-01",
            "status": "COMPLETED"
          }],
          "page": {"nextCursor": null, "hasMore": false}
        }
        """.utf8
    )

    static let seasonCalendar = Data(
        """
        {
          "data": {
            "rangeStart": "2026-07-01T00:00:00Z",
            "rangeEnd": "2027-06-30T23:59:59Z",
            "updatedAt": "2026-08-07T09:00:00Z",
            "sourceName": "Test calendar provider",
            "events": [
              {
                "id": "calendar-draw",
                "title": {"ar": "قرعة تجريبية", "en": "Test draw"},
                "detail": null,
                "startsAt": "2026-08-20T15:00:00Z",
                "endsAt": null,
                "kind": "DRAW",
                "competition": {
                  "id": "competition-calendar",
                  "name": {"ar": "بطولة التقويم", "en": "Calendar competition"},
                  "sport": "FOOTBALL"
                }
              },
              {
                "id": "calendar-window",
                "title": {"ar": "فترة تجريبية", "en": "Test window"},
                "detail": {"ar": "تفاصيل الفترة", "en": "Window detail"},
                "startsAt": "2026-09-01T00:00:00Z",
                "endsAt": "2026-09-30T23:59:59Z",
                "kind": "TRANSFER_WINDOW",
                "competition": null
              }
            ]
          }
        }
        """.utf8
    )

    static let seasonCalendarOutOfRange = Data(
        """
        {
          "data": {
            "rangeStart": "2026-07-01T00:00:00Z",
            "rangeEnd": "2027-06-30T23:59:59Z",
            "updatedAt": "2026-08-07T09:00:00Z",
            "sourceName": "Test calendar provider",
            "events": [{
              "id": "calendar-too-early",
              "title": {"ar": "موعد قديم", "en": "Too early"},
              "detail": null,
              "startsAt": "2026-06-30T23:59:59Z",
              "endsAt": null,
              "kind": "OTHER",
              "competition": null
            }]
          }
        }
        """.utf8
    )

    static let seasonCalendarMissingNullableField = Data(
        """
        {
          "data": {
            "rangeStart": "2026-07-01T00:00:00Z",
            "rangeEnd": "2027-06-30T23:59:59Z",
            "updatedAt": "2026-08-07T09:00:00Z",
            "sourceName": "Test calendar provider",
            "events": [{
              "id": "calendar-missing-detail",
              "title": {"ar": "موعد ناقص", "en": "Missing nullable field"},
              "startsAt": "2026-08-20T15:00:00Z",
              "endsAt": null,
              "kind": "OTHER",
              "competition": null
            }]
          }
        }
        """.utf8
    )

    static let standings = Data(
        """
        {
          "data": [{
            "groupName": {"ar": "الترتيب", "en": "Overall"},
            "rows": [{
              "rank": 1,
              "team": \(teamJSON),
              "played": 20,
              "won": 15,
              "drawn": 3,
              "lost": 2,
              "goalsFor": 40,
              "goalsAgainst": 20,
              "points": 48,
              "form": ["WIN", "DRAW", "WIN"]
            }]
          }]
        }
        """.utf8
    )

    static let fixtureStandings = Data(
        """
        {
          "data": {
            "fixtureId": "fixture-1",
            "competition": {
              "id": "competition-1",
              "name": {"ar": "الدوري", "en": "League"},
              "sport": "FOOTBALL"
            },
            "season": {
              "id": "season-2025",
              "name": {"ar": "موسم 2025", "en": "2025 season"},
              "startDate": "2025-08-01",
              "endDate": "2026-05-31",
              "isCurrent": true
            },
            "standings": [{
              "groupName": {"ar": "الترتيب", "en": "Overall"},
              "rows": [
                {
                  "rank": 1,
                  "team": (teamJSON),
                  "played": 20,
                  "won": 15,
                  "drawn": 3,
                  "lost": 2,
                  "goalsFor": 40,
                  "goalsAgainst": 20,
                  "points": 48,
                  "form": ["WIN", "DRAW", "WIN"]
                },
                {
                  "rank": 2,
                  "team": {
                    "id": "team-away",
                    "name": {"ar": "الفريق الثاني", "en": "Away Team"},
                    "monogram": "AWY",
                    "accentColorHex": "9B5B00"
                  },
                  "played": 20,
                  "won": 14,
                  "drawn": 3,
                  "lost": 3,
                  "goalsFor": 35,
                  "goalsAgainst": 22,
                  "points": 45,
                  "form": ["LOSS", "WIN", "WIN"]
                }
              ]
            }],
            "source": {"name": "Licensed Context Partner"},
            "updatedAt": "2026-08-05T13:00:00Z"
          }
        }
        """.utf8
    )

    static let fixtureHeadToHead = Data(
        """
        {
          "data": {
            "fixtureId": "fixture-1",
            "homeTeam": (teamJSON),
            "awayTeam": {
              "id": "team-away",
              "name": {"ar": "الفريق الثاني", "en": "Away Team"},
              "monogram": "AWY",
              "accentColorHex": "9B5B00"
            },
            "meetings": [{
              "id": "fixture-history-1",
              "competition": {
                "id": "competition-cup",
                "name": {"ar": "الكأس", "en": "Cup"},
                "sport": "FOOTBALL"
              },
              "homeTeam": {
                "id": "team-away",
                "name": {"ar": "الفريق الثاني", "en": "Away Team"},
                "monogram": "AWY",
                "accentColorHex": "9B5B00"
              },
              "awayTeam": (teamJSON),
              "kickoffAt": "2026-03-01T18:00:00Z",
              "state": "FINISHED",
              "minute": 90,
              "score": {"home": 1, "away": 2},
              "venue": {"ar": "ملعب الكأس", "en": "Cup Stadium"},
              "revision": 1
            }],
            "source": {"name": "Licensed Context Partner"},
            "updatedAt": "2026-08-05T13:00:00Z"
          }
        }
        """.utf8
    )

    static let leaders = Data(
        """
        {
          "data": [{
            "rank": 1,
            "player": {"id": "player-9", "name": "Demo Striker", "position": "Forward"},
            "team": \(teamJSON),
            "value": 18
          }],
          "page": {"nextCursor": null, "hasMore": false}
        }
        """.utf8
    )

    private static let teamJSON =
        """
        {
          "id": "team-home",
          "name": {"ar": "الفريق الأول", "en": "Home Team"},
          "monogram": "HOM",
          "accentColorHex": "006C75"
        }
        """

    private static let competitionWithSeasonJSON =
        """
        {
          "id": "competition-remote",
          "name": {"ar": "الدوري", "en": "League"},
          "sport": "FOOTBALL",
          "currentSeasonId": "season-2025",
          "seasons": [{
            "id": "season-2025",
            "name": {"ar": "موسم 2025", "en": "2025 season"},
            "startDate": "2025-08-01",
            "endDate": "2026-05-31",
            "isCurrent": true
          }]
        }
        """

    private static let fixtureJSON =
        """
        {
          "id": "fixture-1",
          "competition": {
            "id": "competition-1",
            "name": {"ar": "الدوري", "en": "League"},
            "sport": "FOOTBALL"
          },
          "homeTeam": {
            "id": "team-home",
            "name": {"ar": "الفريق الأول", "en": "Home Team"},
            "monogram": "HOM",
            "accentColorHex": "006C75"
          },
          "awayTeam": {
            "id": "team-away",
            "name": {"ar": "الفريق الثاني", "en": "Away Team"},
            "monogram": "AWY",
            "accentColorHex": "9B5B00"
          },
          "kickoffAt": "2026-08-05T12:00:00Z",
          "state": "LIVE",
          "minute": 62,
          "score": {"home": 1, "away": 0},
          "venue": {"ar": "الملعب", "en": "Stadium"},
          "broadcasts": [{
            "regionCode": "SA",
            "channel": {"ar": "الرياضة التجريبية الأولى", "en": "Demo Sports One"},
            "commentator": {"ar": "المعلق التجريبي", "en": "Demo commentator"},
            "audioLanguageCode": "ar"
          }],
          "revision": 3
        }
        """
}
