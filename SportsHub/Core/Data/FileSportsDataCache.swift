import CryptoKit
import Foundation

actor FileSportsDataCache: SportsDataCaching, SportsDataCacheManaging {
    private struct CacheFile {
        let url: URL
        let byteCount: Int64
        let storedAt: Date
    }

    private let rootDirectory: URL
    private let policy: SportsDataCachePolicy

    init(
        rootDirectory: URL? = nil,
        policy: SportsDataCachePolicy = .standard
    ) {
        if let rootDirectory {
            self.rootDirectory = rootDirectory
        } else {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            self.rootDirectory = (caches ?? FileManager.default.temporaryDirectory)
                .appendingPathComponent("SportsHubAPI", isDirectory: true)
        }
        self.policy = policy
    }

    func payload(for key: String) -> CachedPayload? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CachedPayload.self, from: data)
    }

    func store(_ payload: CachedPayload, for key: String) throws {
        do {
            try FileManager.default.createDirectory(
                at: rootDirectory,
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(payload)
            let url = fileURL(for: key)
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes(
                [.modificationDate: payload.storedAt],
                ofItemAtPath: url.path
            )
            try pruneIfNeeded()
        } catch {
            throw SportsDataError.localStorageUnavailable
        }
    }

    func cacheSummary() throws -> SportsDataCacheSummary {
        do {
            let files = try cacheFiles()
            return SportsDataCacheSummary(
                entryCount: files.count,
                byteCount: files.reduce(Int64(0)) { $0 + $1.byteCount },
                newestStoredAt: files.map(\.storedAt).max(),
                maximumByteCount: policy.maximumByteCount
            )
        } catch let error as SportsDataError {
            throw error
        } catch {
            throw SportsDataError.localStorageUnavailable
        }
    }

    func clearCache() throws {
        do {
            guard FileManager.default.fileExists(atPath: rootDirectory.path) else { return }
            try FileManager.default.removeItem(at: rootDirectory)
        } catch {
            throw SportsDataError.localStorageUnavailable
        }
    }

    private func fileURL(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return rootDirectory.appendingPathComponent("\(digest).json", isDirectory: false)
    }

    private func cacheFiles() throws -> [CacheFile] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: rootDirectory.path) else { return [] }
        let resourceKeys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .contentModificationDateKey
        ]
        let rootValues = try rootDirectory.resourceValues(forKeys: resourceKeys)
        guard rootValues.isDirectory == true,
              rootValues.isSymbolicLink != true else {
            throw SportsDataError.localStorageUnavailable
        }
        return try cacheFiles(in: rootDirectory, resourceKeys: resourceKeys)
    }

    private func cacheFiles(
        in directory: URL,
        resourceKeys: Set<URLResourceKey>
    ) throws -> [CacheFile] {
        let fileManager = FileManager.default
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: []
        )

        var files: [CacheFile] = []
        for url in urls {
            let values = try url.resourceValues(forKeys: resourceKeys)
            guard values.isSymbolicLink != true else { continue }
            if values.isDirectory == true {
                files.append(contentsOf: try cacheFiles(in: url, resourceKeys: resourceKeys))
                continue
            }
            guard values.isRegularFile == true else { continue }
            files.append(
                CacheFile(
                    url: url,
                    byteCount: Int64(values.fileSize ?? 0),
                    storedAt: values.contentModificationDate ?? .distantPast
                )
            )
        }
        return files
    }

    private func pruneIfNeeded() throws {
        var files = try cacheFiles().sorted { $0.storedAt < $1.storedAt }
        var byteCount = files.reduce(Int64(0)) { $0 + $1.byteCount }
        while files.count > policy.maximumEntryCount
            || byteCount > policy.maximumByteCount {
            guard !files.isEmpty else { return }
            let oldest = files.removeFirst()
            try FileManager.default.removeItem(at: oldest.url)
            byteCount -= oldest.byteCount
        }
    }
}
