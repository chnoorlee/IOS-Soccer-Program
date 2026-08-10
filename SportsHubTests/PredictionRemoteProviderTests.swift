import Foundation
import XCTest
@testable import SportsHub

final class PredictionRemoteProviderTests: XCTestCase {
    func testPublicGamesMapAndRevalidateWithETag() async throws {
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        let client = PredictionHTTPClient(results: [
            .success(HTTPResponse(
                data: PredictionPayloads.gameList,
                statusCode: 200,
                headers: ["ETag": "\"predictions-v1\""]
            )),
            .success(HTTPResponse(data: Data(), statusCode: 304, headers: [:]))
        ])
        let freshness = PublicContentFreshnessStore()
        let provider = try makeProvider(client: client, freshness: freshness, now: now)

        let first = try await provider.predictionGames()
        let second = try await provider.predictionGames()
        let firstPath = await client.path(at: 0)
        let firstCacheControl = await client.header("Cache-Control", at: 0)
        let ifNoneMatch = await client.header("If-None-Match", at: 1)
        let status = await freshness.status(for: .predictionGames)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.map(\.id), ["prediction-1"])
        XCTAssertEqual(firstPath, "/v1/prediction-games")
        XCTAssertEqual(firstCacheControl, "no-cache")
        XCTAssertEqual(ifNoneMatch, "\"predictions-v1\"")
        XCTAssertEqual(
            status,
            .revalidated(storedAt: now, checkedAt: now)
        )
    }

    func testAuthenticatedEntryReadAndSaveAreNoStoreAndUseExactRankings() async throws {
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        let client = PredictionHTTPClient(results: [
            .success(HTTPResponse(
                data: PredictionPayloads.gameList,
                statusCode: 200,
                headers: [:]
            )),
            .success(HTTPResponse(
                data: PredictionPayloads.entryResponse,
                statusCode: 200,
                headers: [:]
            )),
            .success(HTTPResponse(
                data: PredictionPayloads.entryResponse,
                statusCode: 200,
                headers: [:]
            ))
        ])
        let provider = try makeScopedProvider(
            client: client,
            accountID: "account-1",
            token: "test-token",
            now: now
        )
        let games = try await provider.predictionGames()
        let game = try XCTUnwrap(games.first)
        let loadedEntry = try await provider.predictionEntry(
            for: game,
            forAccountID: "account-1"
        )
        let entry = try XCTUnwrap(loadedEntry)

        let saved = try await provider.savePredictionEntry(
            for: game,
            rankings: entry.rankings,
            forAccountID: "account-1"
        )
        let entryPath = await client.path(at: 1)
        let entryMethod = await client.method(at: 1)
        let entryAuthorization = await client.header("Authorization", at: 1)
        let entryCacheControl = await client.header("Cache-Control", at: 1)
        let saveMethod = await client.method(at: 2)
        let saveAuthorization = await client.header("Authorization", at: 2)
        let saveCacheControl = await client.header("Cache-Control", at: 2)
        let saveContentType = await client.header("Content-Type", at: 2)
        let idempotencyKey = await client.header("Idempotency-Key", at: 2)
        let requestBody = await client.body(at: 2)
        let body = try XCTUnwrap(requestBody)

        XCTAssertEqual(saved, entry)
        XCTAssertEqual(
            entryPath,
            "/v1/prediction-games/prediction-1/entries/me"
        )
        XCTAssertEqual(entryMethod, "GET")
        XCTAssertEqual(entryAuthorization, "Bearer test-token")
        XCTAssertEqual(entryCacheControl, "no-store")
        XCTAssertEqual(saveMethod, "PUT")
        XCTAssertEqual(saveAuthorization, "Bearer test-token")
        XCTAssertEqual(saveCacheControl, "no-store")
        XCTAssertEqual(saveContentType, "application/json")
        XCTAssertNotNil(idempotencyKey)

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        let rankings = try XCTUnwrap(object["rankings"] as? [[String: Any]])
        XCTAssertEqual(rankings.first?["groupId"] as? String, "group-a")
        XCTAssertEqual(
            rankings.first?["orderedTeamIds"] as? [String],
            ["team-two", "team-one", "team-three", "team-four"]
        )
    }

    func testMissingEntryReturnsNilWithoutCaching() async throws {
        let client = PredictionHTTPClient(results: [
            .success(HTTPResponse(data: Data(), statusCode: 404, headers: [:]))
        ])
        let provider = try makeProvider(client: client, token: "test-token")
        let game = try XCTUnwrap(MockSportsData.predictionGames.first)

        let entry = try await provider.predictionEntry(for: game)
        let method = await client.method(at: 0)
        let cacheControl = await client.header("Cache-Control", at: 0)

        XCTAssertNil(entry)
        XCTAssertEqual(method, "GET")
        XCTAssertEqual(cacheControl, "no-store")
    }

    func testMissingTokenRejectsPrivateReadBeforeNetworking() async throws {
        let client = PredictionHTTPClient(results: [])
        let provider = try makeProvider(client: client)
        let game = try XCTUnwrap(MockSportsData.predictionGames.first)

        do {
            _ = try await provider.predictionEntry(for: game)
            XCTFail("Expected authentication to be required")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .unauthorized)
        }
        let requestCount = await client.requestCount
        XCTAssertEqual(requestCount, 0)
    }

    func testExpectedAccountMismatchRejectsSaveBeforeNetworking() async throws {
        let client = PredictionHTTPClient(results: [])
        let provider = try makeScopedProvider(
            client: client,
            accountID: "account-1",
            token: "test-token"
        )
        let game = try XCTUnwrap(MockSportsData.predictionGames.first)
        let rankings = game.groups.map {
            PredictionGroupRanking(
                groupID: $0.id,
                orderedTeamIDs: $0.teams.map(\.id)
            )
        }

        do {
            _ = try await provider.savePredictionEntry(
                for: game,
                rankings: rankings,
                forAccountID: "account-2"
            )
            XCTFail("Expected the account-bound token lookup to fail")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .unauthorized)
        }
        let requestCount = await client.requestCount
        XCTAssertEqual(requestCount, 0)
    }

    func testSaveRejectsAResponseThatDoesNotEchoSubmittedOrder() async throws {
        let client = PredictionHTTPClient(results: [
            .success(HTTPResponse(
                data: PredictionPayloads.entryResponse,
                statusCode: 200,
                headers: [:]
            ))
        ])
        let provider = try makeProvider(
            client: client,
            token: "test-token",
            now: Date(timeIntervalSince1970: 1_788_000_000)
        )
        let game = try APIJSON.makeDecoder()
            .decode(PredictionGameListResponseDTO.self, from: PredictionPayloads.gameList)
            .domain()[0]
        let submitted = game.groups.map {
            PredictionGroupRanking(
                groupID: $0.id,
                orderedTeamIDs: $0.teams.map(\.id)
            )
        }

        do {
            _ = try await provider.savePredictionEntry(for: game, rankings: submitted)
            XCTFail("Expected the mismatched response to be rejected")
        } catch let error as SportsDataError {
            guard case .contractViolation = error else {
                return XCTFail("Expected a contract violation, received \(error)")
            }
        }
    }

    private func makeProvider(
        client: PredictionHTTPClient,
        token: String? = nil,
        freshness: any PublicContentFreshnessReporting = NoopPublicContentFreshnessReporter(),
        now: Date = Date(timeIntervalSince1970: 1_788_000_000)
    ) throws -> RemoteSportsDataProvider {
        try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            accessTokenProvider: StaticAccessTokenProvider(token: token),
            freshnessReporter: freshness,
            now: { now }
        )
    }

    private func makeScopedProvider(
        client: PredictionHTTPClient,
        accountID: String,
        token: String,
        now: Date = Date(timeIntervalSince1970: 1_788_000_000)
    ) throws -> RemoteSportsDataProvider {
        try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            accessTokenProvider: PredictionAccountAccessTokenProvider(
                accountID: accountID,
                token: token
            ),
            now: { now }
        )
    }
}

private struct PredictionAccountAccessTokenProvider: AccessTokenProviding {
    let accountID: String
    let token: String

    func accessToken() async -> String? { token }

    func accessToken(forAccountID accountID: String) async -> String? {
        accountID == self.accountID ? token : nil
    }
}

private actor PredictionHTTPClient: HTTPClient {
    private var results: [Result<HTTPResponse, SportsDataError>]
    private var requests: [URLRequest] = []

    init(results: [Result<HTTPResponse, SportsDataError>]) {
        self.results = results
    }

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        requests.append(request)
        guard !results.isEmpty else { throw SportsDataError.serverUnavailable }
        return try results.removeFirst().get()
    }

    var requestCount: Int { requests.count }

    func path(at index: Int) -> String? {
        requests.indices.contains(index) ? requests[index].url?.path : nil
    }

    func method(at index: Int) -> String? {
        requests.indices.contains(index) ? requests[index].httpMethod : nil
    }

    func header(_ name: String, at index: Int) -> String? {
        guard requests.indices.contains(index) else { return nil }
        return requests[index].value(forHTTPHeaderField: name)
    }

    func body(at index: Int) -> Data? {
        requests.indices.contains(index) ? requests[index].httpBody : nil
    }
}
