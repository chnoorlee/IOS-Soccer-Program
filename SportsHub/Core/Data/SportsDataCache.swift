import Foundation

struct CachedPayload: Codable, Sendable {
    let data: Data
    let storedAt: Date
    let etag: String?
}

protocol SportsDataCaching: Sendable {
    func payload(for key: String) async -> CachedPayload?
    func store(_ payload: CachedPayload, for key: String) async throws
}

struct SportsDataCachePolicy: Equatable, Sendable {
    static let standard = SportsDataCachePolicy(
        maximumByteCount: 50 * 1_024 * 1_024,
        maximumEntryCount: 200
    )

    let maximumByteCount: Int64
    let maximumEntryCount: Int

    init(maximumByteCount: Int64, maximumEntryCount: Int) {
        self.maximumByteCount = max(0, maximumByteCount)
        self.maximumEntryCount = max(0, maximumEntryCount)
    }
}

struct SportsDataCacheSummary: Equatable, Sendable {
    let entryCount: Int
    let byteCount: Int64
    let newestStoredAt: Date?
    let maximumByteCount: Int64

    static func empty(
        maximumByteCount: Int64 = SportsDataCachePolicy.standard.maximumByteCount
    ) -> SportsDataCacheSummary {
        SportsDataCacheSummary(
            entryCount: 0,
            byteCount: 0,
            newestStoredAt: nil,
            maximumByteCount: maximumByteCount
        )
    }

    var isEmpty: Bool {
        entryCount == 0 && byteCount == 0
    }
}

protocol SportsDataCacheManaging: Sendable {
    func cacheSummary() async throws -> SportsDataCacheSummary
    func clearCache() async throws
}

actor MemorySportsDataCache: SportsDataCaching, SportsDataCacheManaging {
    private var payloads: [String: CachedPayload]
    private let policy: SportsDataCachePolicy

    init(
        initialPayloads: [String: CachedPayload] = [:],
        policy: SportsDataCachePolicy = .standard
    ) {
        payloads = initialPayloads
        self.policy = policy
    }

    func payload(for key: String) -> CachedPayload? {
        payloads[key]
    }

    func store(_ payload: CachedPayload, for key: String) {
        payloads[key] = payload
        pruneIfNeeded()
    }

    func cacheSummary() -> SportsDataCacheSummary {
        let byteCount = payloads.values.reduce(Int64(0)) { result, payload in
            let encodedCount = (try? JSONEncoder().encode(payload).count) ?? payload.data.count
            return result + Int64(encodedCount)
        }
        return SportsDataCacheSummary(
            entryCount: payloads.count,
            byteCount: byteCount,
            newestStoredAt: payloads.values.map(\.storedAt).max(),
            maximumByteCount: policy.maximumByteCount
        )
    }

    func clearCache() {
        payloads.removeAll()
    }

    private func pruneIfNeeded() {
        while payloads.count > policy.maximumEntryCount
            || cacheSummary().byteCount > policy.maximumByteCount {
            guard let oldestKey = payloads.min(by: {
                $0.value.storedAt < $1.value.storedAt
            })?.key else {
                return
            }
            payloads.removeValue(forKey: oldestKey)
        }
    }
}
