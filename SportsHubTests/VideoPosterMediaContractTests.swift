import Foundation
import UIKit
import XCTest
@testable import SportsHub

final class VideoPosterMediaContractTests: XCTestCase {
    func testValidPosterMapsExactEditorialMetadataWithoutGrantingPlayback() throws {
        let video = try decodeVideo(poster: validPosterJSON).domain(field: "video")
        let poster = try XCTUnwrap(video.poster)

        XCTAssertEqual(poster.id, "poster-one")
        XCTAssertEqual(
            poster.url.absoluteString,
            "https://media.example.test/videos/poster-one.jpg?sig=demo"
        )
        XCTAssertEqual(poster.contentType, .jpeg)
        XCTAssertEqual(poster.width, 1_600)
        XCTAssertEqual(poster.height, 900)
        XCTAssertEqual(poster.altText(in: .arabic), "مقدم تجريبي داخل الاستوديو")
        XCTAssertEqual(poster.altText(in: .english), "A fictional host in the studio")
        XCTAssertEqual(poster.credit(in: .english), "SportsHub Demo Studio")
        XCTAssertFalse(video.isPlayable)
        XCTAssertEqual(video.availabilityReason, .regionBlocked)
    }

    func testMissingOrNullPosterMigratesToOriginalVideoArtwork() throws {
        let missing = try decodeVideo(poster: nil).domain(field: "video")
        let null = try decodeVideo(poster: "\"poster\": null,").domain(field: "video")

        XCTAssertNil(missing.poster)
        XCTAssertNil(null.poster)
    }

    func testPosterRejectsUnsafeURLMimeDimensionsAndText() throws {
        let cases: [(String, String, String)] = [
            ("\"id\": \"poster-one\"", "\"id\": \"\"", "video.poster.id"),
            ("https://media.example.test/videos/poster-one.jpg?sig=demo", "http://media.example.test/videos/poster-one.jpg", "video.poster.url"),
            ("https://media.example.test/videos/poster-one.jpg?sig=demo", "https://media.example.test/", "video.poster.url"),
            ("https://media.example.test/videos/poster-one.jpg?sig=demo", "https://user:pass@media.example.test/videos/poster-one.jpg", "video.poster.url"),
            ("https://media.example.test/videos/poster-one.jpg?sig=demo", "https://media.example.test:8443/videos/poster-one.jpg", "video.poster.url"),
            ("https://media.example.test/videos/poster-one.jpg?sig=demo", "https://media.example.test/videos/poster-one.jpg#crop", "video.poster.url"),
            ("\"contentType\": \"image/jpeg\"", "\"contentType\": \"image/svg+xml\"", "video.poster.contentType"),
            ("\"width\": 1600", "\"width\": 639", "video.poster.width"),
            ("\"height\": 900", "\"height\": 359", "video.poster.height"),
            ("\"width\": 1600, \"height\": 900", "\"width\": 4096, \"height\": 4000", "video.poster.dimensions"),
            ("\"width\": 1600, \"height\": 900", "\"width\": 640, \"height\": 600", "video.poster.aspectRatio"),
            ("A fictional host in the studio", String(repeating: "a", count: 181), "video.poster.altText"),
            ("SportsHub Demo Studio", "", "video.poster.credit.en")
        ]

        for (original, replacement, field) in cases {
            let poster = validPosterJSON.replacingOccurrences(of: original, with: replacement)
            let dto = try decodeVideo(poster: poster)
            XCTAssertThrowsError(try dto.domain(field: "video"), field) {
                XCTAssertEqual(
                    $0 as? SportsDataError,
                    .contractViolation(field: field),
                    field
                )
            }
        }
    }

    func testPersonalVideoSnapshotOmitsPosterURLAndDecodesWithoutPoster() throws {
        let video = try decodeVideo(poster: validPosterJSON).domain(field: "video")
        XCTAssertNotNil(video.poster)

        let encoded = try JSONEncoder().encode(video)
        let encodedText = String(decoding: encoded, as: UTF8.self)
        XCTAssertFalse(encodedText.contains("poster"))
        XCTAssertFalse(encodedText.contains("media.example.test"))

        let decoded = try JSONDecoder().decode(SportsVideo.self, from: encoded)
        XCTAssertNil(decoded.poster)
        XCTAssertEqual(decoded.id, video.id)
        XCTAssertEqual(decoded.availabilityReason, video.availabilityReason)
    }

    func testPersonalStoreDropsPosterBeforeHoldingSnapshotInMemory() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }
        let video = try decodeVideo(poster: validPosterJSON).domain(field: "video")
        let store = FilePersonalVideoStateStore(rootDirectory: rootDirectory)
        let now = Date(timeIntervalSince1970: 1_786_089_600)

        try await store.recordVideo(video)
        let recordedVideo = try await store.video(id: video.id)
        XCTAssertNil(recordedVideo?.poster)

        _ = try await store.saveFavorite(video: video, updatedAt: now)
        let favoriteVideos = try await store.favoriteVideos()
        XCTAssertNil(favoriteVideos.first?.poster)

        _ = try await store.saveWatchProgress(
            video: video,
            positionSeconds: 45,
            completed: false,
            updatedAt: now
        )
        let continueWatching = try await store.continueWatching()
        XCTAssertNil(continueWatching.first?.video.poster)

        let storedData = try Data(
            contentsOf: rootDirectory.appendingPathComponent("guest-v1.json")
        )
        let storedText = String(decoding: storedData, as: UTF8.self)
        XCTAssertFalse(storedText.contains("media.example.test"))
        XCTAssertFalse(storedText.contains("\"poster\""))
    }

    @MainActor
    func testSharedDecoderVerifiesPosterBodyBeforeDownsampling() async throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: 640, height: 360),
            format: format
        )
        let pngData = renderer.pngData { context in
            context.cgContext.setFillColor(UIColor.systemTeal.cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 640, height: 360))
        }
        let poster = VideoPosterMedia(
            id: "poster-decoder",
            url: try XCTUnwrap(URL(string: "https://media.example.test/videos/poster.png")),
            contentType: .png,
            width: 640,
            height: 360,
            altArabic: "ملصق تجريبي",
            altEnglish: "Demo poster",
            creditArabic: "استوديو تجريبي",
            creditEnglish: "Demo Studio"
        )

        let decoded = await VideoPosterImageDecoder.shared.decode(
            pngData,
            media: poster,
            maximumPixelSize: 320
        )
        let image = try XCTUnwrap(decoded?.image.cgImage)
        XCTAssertLessThanOrEqual(max(image.width, image.height), 320)
    }

    private func decodeVideo(poster: String?) throws -> VideoDTO {
        let poster = poster ?? ""
        let data = Data(
            """
            {
              "id": "video-poster",
              "type": "HIGHLIGHT",
              "title": {"ar": "عنوان", "en": "Title"},
              "description": {"ar": "وصف", "en": "Description"},
              \(poster)
              "durationSeconds": 301,
              "isPlayable": false,
              "availabilityReason": "REGION_BLOCKED"
            }
            """.utf8
        )
        return try APIJSON.makeDecoder().decode(VideoDTO.self, from: data)
    }

    private var validPosterJSON: String {
        """
        "poster": {
          "id": "poster-one",
          "url": "https://media.example.test/videos/poster-one.jpg?sig=demo",
          "contentType": "image/jpeg",
          "width": 1600,
          "height": 900,
          "altText": {
            "ar": "مقدم تجريبي داخل الاستوديو",
            "en": "A fictional host in the studio"
          },
          "credit": {
            "ar": "استوديو سبورتس هب التجريبي",
            "en": "SportsHub Demo Studio"
          }
        },
        """
    }
}
