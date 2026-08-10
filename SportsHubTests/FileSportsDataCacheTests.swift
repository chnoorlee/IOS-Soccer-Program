import Foundation
import XCTest
@testable import SportsHub

final class FileSportsDataCacheTests: XCTestCase {
    func testSummaryReportsDiskEntriesBytesAndNewestStoredDate() async throws {
        let root = makeRootDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = FileSportsDataCache(rootDirectory: root)
        let older = Date(timeIntervalSince1970: 1_788_000_000)
        let newer = older.addingTimeInterval(120)

        try await cache.store(
            CachedPayload(data: Data("older".utf8), storedAt: older, etag: "old"),
            for: "https://example.test/older"
        )
        try await cache.store(
            CachedPayload(data: Data("newer-payload".utf8), storedAt: newer, etag: "new"),
            for: "https://example.test/newer"
        )

        let summary = try await cache.cacheSummary()

        XCTAssertEqual(summary.entryCount, 2)
        XCTAssertGreaterThan(summary.byteCount, 0)
        XCTAssertEqual(
            try XCTUnwrap(summary.newestStoredAt).timeIntervalSince1970,
            newer.timeIntervalSince1970,
            accuracy: 1
        )
        XCTAssertEqual(summary.maximumByteCount, SportsDataCachePolicy.standard.maximumByteCount)
    }

    func testCorruptFileRemainsVisibleAndClearRemovesOnlyDedicatedRoot() async throws {
        let parent = makeRootDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }
        let root = parent.appendingPathComponent("SportsHubAPI", isDirectory: true)
        let sibling = parent.appendingPathComponent("keep.txt", isDirectory: false)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("keep".utf8).write(to: sibling)
        try Data("not-json".utf8).write(
            to: root.appendingPathComponent("corrupt.json", isDirectory: false)
        )
        let cache = FileSportsDataCache(rootDirectory: root)

        let before = try await cache.cacheSummary()
        try await cache.clearCache()
        let after = try await cache.cacheSummary()

        XCTAssertEqual(before.entryCount, 1)
        XCTAssertEqual(before.byteCount, Int64(Data("not-json".utf8).count))
        XCTAssertTrue(after.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sibling.path))
    }

    func testSummaryRejectsASymbolicLinkAsTheManagedRoot() async throws {
        let parent = makeRootDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }
        let destination = parent.appendingPathComponent("destination", isDirectory: true)
        let linkedRoot = parent.appendingPathComponent("SportsHubAPI", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: linkedRoot,
            withDestinationURL: destination
        )
        let cache = FileSportsDataCache(rootDirectory: linkedRoot)

        do {
            _ = try await cache.cacheSummary()
            XCTFail("A symbolic-link cache root must fail closed")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .localStorageUnavailable)
        }
    }

    func testEntryPolicyPrunesOldestPayload() async throws {
        let root = makeRootDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let policy = SportsDataCachePolicy(
            maximumByteCount: 1_000_000,
            maximumEntryCount: 2
        )
        let cache = FileSportsDataCache(rootDirectory: root, policy: policy)
        let date = Date(timeIntervalSince1970: 1_788_000_000)

        for index in 0..<3 {
            try await cache.store(
                CachedPayload(
                    data: Data("payload-\(index)".utf8),
                    storedAt: date.addingTimeInterval(TimeInterval(index)),
                    etag: nil
                ),
                for: "key-\(index)"
            )
        }

        let oldestPayload = await cache.payload(for: "key-0")
        let middlePayload = await cache.payload(for: "key-1")
        let newestPayload = await cache.payload(for: "key-2")
        let summary = try await cache.cacheSummary()
        XCTAssertNil(oldestPayload)
        XCTAssertNotNil(middlePayload)
        XCTAssertNotNil(newestPayload)
        XCTAssertEqual(summary.entryCount, 2)
    }

    func testBytePolicyCanEvictAnOversizedPayload() async throws {
        let root = makeRootDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let policy = SportsDataCachePolicy(maximumByteCount: 1, maximumEntryCount: 10)
        let cache = FileSportsDataCache(rootDirectory: root, policy: policy)

        try await cache.store(
            CachedPayload(
                data: Data(repeating: 1, count: 64),
                storedAt: Date(timeIntervalSince1970: 1_788_000_000),
                etag: nil
            ),
            for: "oversized"
        )

        let payload = await cache.payload(for: "oversized")
        let summary = try await cache.cacheSummary()
        XCTAssertNil(payload)
        XCTAssertTrue(summary.isEmpty)
    }

    private func makeRootDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubCacheTests-\(UUID().uuidString)", isDirectory: true)
    }
}
