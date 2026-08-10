import Foundation
import UIKit
import XCTest
@testable import SportsHub

final class ArticleHeroMediaContractTests: XCTestCase {
    func testValidHeroMediaMapsExactEditorialMetadata() throws {
        let article = try decodeArticle(heroMedia: validHeroMediaJSON).domain(field: "article")
        let media = try XCTUnwrap(article.heroMedia)

        XCTAssertEqual(media.id, "hero-one")
        XCTAssertEqual(media.url.absoluteString, "https://media.example.test/articles/hero-one.jpg?sig=demo")
        XCTAssertEqual(media.contentType, .jpeg)
        XCTAssertEqual(media.width, 1_600)
        XCTAssertEqual(media.height, 900)
        XCTAssertEqual(media.altText(in: .arabic), "لاعب تجريبي يركض بالكرة")
        XCTAssertEqual(media.altText(in: .english), "A fictional player running with the ball")
        XCTAssertEqual(media.credit(in: .english), "SportsHub Demo Studio")
    }

    func testMissingOrNullHeroMediaMigratesToOriginalCover() throws {
        let missing = try decodeArticle(heroMedia: nil).domain(field: "article")
        let null = try decodeArticle(heroMedia: "\"heroMedia\": null,").domain(field: "article")

        XCTAssertNil(missing.heroMedia)
        XCTAssertNil(null.heroMedia)
    }

    func testHeroMediaRejectsUnsafeURLMimeDimensionsAndText() throws {
        let cases: [(String, String, String)] = [
            ("\"id\": \"hero-one\"", "\"id\": \"\"", "article.heroMedia.id"),
            ("https://media.example.test/articles/hero-one.jpg?sig=demo", "http://media.example.test/articles/hero-one.jpg", "article.heroMedia.url"),
            ("https://media.example.test/articles/hero-one.jpg?sig=demo", "https://media.example.test/", "article.heroMedia.url"),
            ("https://media.example.test/articles/hero-one.jpg?sig=demo", "https://media.example.test/articles/\(String(repeating: "a", count: 2_100))", "article.heroMedia.url"),
            ("https://media.example.test/articles/hero-one.jpg?sig=demo", "https://user:pass@media.example.test/articles/hero-one.jpg", "article.heroMedia.url"),
            ("https://media.example.test/articles/hero-one.jpg?sig=demo", "https://media.example.test:8443/articles/hero-one.jpg", "article.heroMedia.url"),
            ("https://media.example.test/articles/hero-one.jpg?sig=demo", "https://media.example.test/articles/hero-one.jpg#crop", "article.heroMedia.url"),
            ("\"contentType\": \"image/jpeg\"", "\"contentType\": \"image/svg+xml\"", "article.heroMedia.contentType"),
            ("\"width\": 1600", "\"width\": 639", "article.heroMedia.width"),
            ("\"height\": 900", "\"height\": 359", "article.heroMedia.height"),
            ("\"width\": 1600, \"height\": 900", "\"width\": 4096, \"height\": 4000", "article.heroMedia.dimensions"),
            ("\"width\": 1600, \"height\": 900", "\"width\": 640, \"height\": 600", "article.heroMedia.aspectRatio"),
            ("A fictional player running with the ball", String(repeating: "a", count: 181), "article.heroMedia.altText"),
            ("SportsHub Demo Studio", "", "article.heroMedia.credit.en")
        ]

        for (original, replacement, field) in cases {
            let heroMedia = validHeroMediaJSON.replacingOccurrences(of: original, with: replacement)
            let dto = try decodeArticle(heroMedia: heroMedia)
            XCTAssertThrowsError(try dto.domain(field: "article"), field) {
                XCTAssertEqual(
                    $0 as? SportsDataError,
                    .contractViolation(field: field),
                    field
                )
            }
        }
    }

    func testSavedArticleSnapshotOmitsMediaURLAndDecodesWithoutMedia() throws {
        let media = try XCTUnwrap(
            try decodeArticle(heroMedia: validHeroMediaJSON)
                .domain(field: "article")
                .heroMedia
        )
        let article = Article(
            id: "saved-hero",
            titleArabic: "عنوان",
            titleEnglish: "Title",
            summaryArabic: "ملخص",
            summaryEnglish: "Summary",
            source: "Desk",
            publishedAt: Date(timeIntervalSince1970: 0),
            categoryKey: "category.analysis",
            isCorrected: false,
            heroMedia: media
        )

        let encoded = try JSONEncoder().encode(article)
        let encodedText = String(decoding: encoded, as: UTF8.self)
        XCTAssertFalse(encodedText.contains("heroMedia"))
        XCTAssertFalse(encodedText.contains("media.example.test"))

        let decoded = try JSONDecoder().decode(Article.self, from: encoded)
        XCTAssertNil(decoded.heroMedia)
        XCTAssertEqual(decoded.id, article.id)
    }

    func testMediaHostConfigurationRequiresExactExternalHost() throws {
        let policy = ArticleMediaConfiguration(allowedHosts: [" MEDIA.EXAMPLE.TEST "])
        let exact = try XCTUnwrap(
            URL(string: "https://media.example.test/articles/hero.jpg?sig=value")
        )
        let suffixAttack = try XCTUnwrap(
            URL(string: "https://media.example.test.attacker.test/articles/hero.jpg")
        )
        let subdomain = try XCTUnwrap(
            URL(string: "https://images.media.example.test/articles/hero.jpg")
        )
        let credential = try XCTUnwrap(
            URL(string: "https://user@media.example.test/articles/hero.jpg")
        )

        XCTAssertTrue(policy.permits(exact))
        XCTAssertFalse(policy.permits(suffixAttack))
        XCTAssertFalse(policy.permits(subdomain))
        XCTAssertFalse(policy.permits(credential))
        XCTAssertFalse(
            ArticleMediaConfiguration(allowedHosts: [String]()).permits(exact)
        )
        XCTAssertTrue(
            ArticleMediaConfiguration(allowedHosts: ["*.example.test"]).allowedHosts.isEmpty
        )
        XCTAssertTrue(
            ArticleMediaConfiguration(allowedHosts: ["127.0.0.1"]).allowedHosts.isEmpty
        )
    }

    func testImageResponseValidatorFailsClosedOnStatusMimeAndByteLimits() throws {
        let data = Data([0xFF, 0xD8, 0xFF])
        XCTAssertNoThrow(
            try ArticleHeroImageResponseValidator.validate(
                statusCode: 200,
                mimeType: "image/jpeg",
                expectedContentType: .jpeg,
                expectedContentLength: Int64(data.count),
                data: data
            )
        )

        XCTAssertThrowsError(
            try ArticleHeroImageResponseValidator.validate(
                statusCode: 200,
                mimeType: "image/jpeg",
                expectedContentType: .jpeg,
                expectedContentLength: -2,
                data: data
            )
        ) { XCTAssertEqual($0 as? ArticleHeroImageLoadError, .invalidResponse) }
        XCTAssertNoThrow(
            try ArticleHeroImageResponseValidator.validate(
                statusCode: 200,
                mimeType: "image/jpeg",
                expectedContentType: .jpeg,
                expectedContentLength: -1,
                data: data
            )
        )

        XCTAssertThrowsError(
            try ArticleHeroImageResponseValidator.validate(
                statusCode: 302,
                mimeType: "image/jpeg",
                expectedContentType: .jpeg,
                expectedContentLength: Int64(data.count),
                data: data
            )
        ) { XCTAssertEqual($0 as? ArticleHeroImageLoadError, .unexpectedStatus(302)) }

        XCTAssertThrowsError(
            try ArticleHeroImageResponseValidator.validate(
                statusCode: 200,
                mimeType: "image/png",
                expectedContentType: .jpeg,
                expectedContentLength: Int64(data.count),
                data: data
            )
        ) { XCTAssertEqual($0 as? ArticleHeroImageLoadError, .unexpectedContentType) }

        XCTAssertThrowsError(
            try ArticleHeroImageResponseValidator.validate(
                statusCode: 200,
                mimeType: "image/jpeg",
                expectedContentType: .jpeg,
                expectedContentLength: Int64(ArticleHeroMedia.maximumByteCount + 1),
                data: data
            )
        ) { XCTAssertEqual($0 as? ArticleHeroImageLoadError, .responseTooLarge) }

        XCTAssertThrowsError(
            try ArticleHeroImageResponseValidator.validate(
                statusCode: 200,
                mimeType: "image/jpeg",
                expectedContentType: .jpeg,
                expectedContentLength: -1,
                data: Data(
                    repeating: 0xFF,
                    count: ArticleHeroMedia.maximumByteCount + 1
                )
            )
        ) { XCTAssertEqual($0 as? ArticleHeroImageLoadError, .responseTooLarge) }

        XCTAssertThrowsError(
            try ArticleHeroImageResponseValidator.validate(
                statusCode: 200,
                mimeType: "image/jpeg",
                expectedContentType: .jpeg,
                expectedContentLength: 0,
                data: Data()
            )
        ) { XCTAssertEqual($0 as? ArticleHeroImageLoadError, .invalidImage) }
    }

    func testRedirectDelegateRejectsFollowUpRequest() throws {
        let originalURL = try XCTUnwrap(
            URL(string: "https://media.example.test/articles/original.jpg")
        )
        let redirectedURL = try XCTUnwrap(
            URL(string: "https://other.example.test/articles/redirected.jpg")
        )
        let session = URLSession(configuration: .ephemeral)
        let task = session.dataTask(with: originalURL)
        let response = try XCTUnwrap(
            HTTPURLResponse(
                url: originalURL,
                statusCode: 302,
                httpVersion: "HTTP/1.1",
                headerFields: ["Location": redirectedURL.absoluteString]
            )
        )
        let completion = expectation(description: "redirect rejected")
        var proposedRequest: URLRequest?

        ArticleMediaNoRedirectDelegate().urlSession(
            session,
            task: task,
            willPerformHTTPRedirection: response,
            newRequest: URLRequest(url: redirectedURL)
        ) { request in
            proposedRequest = request
            completion.fulfill()
        }

        wait(for: [completion], timeout: 1)
        XCTAssertNil(proposedRequest)
        session.invalidateAndCancel()
    }

    @MainActor
    func testDecoderVerifiesBodyTypeAndDimensionsBeforeDownsampling() async throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: 640, height: 360),
            format: format
        )
        let pngData = renderer.pngData { context in
            context.cgContext.setFillColor(UIColor.systemBlue.cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 640, height: 360))
        }
        let media = ArticleHeroMedia(
            id: "decoder-fixture",
            url: try XCTUnwrap(
                URL(string: "https://media.example.test/articles/decoder.png")
            ),
            contentType: .png,
            width: 640,
            height: 360,
            altArabic: "صورة تجريبية",
            altEnglish: "Fixture image",
            creditArabic: "استوديو تجريبي",
            creditEnglish: "Fixture Studio"
        )

        let decoded = await ArticleHeroImageDecoder.shared.decode(
            pngData,
            media: media,
            maximumPixelSize: 320
        )
        let image = try XCTUnwrap(decoded?.image.cgImage)
        XCTAssertLessThanOrEqual(max(image.width, image.height), 320)

        let wrongType = ArticleHeroMedia(
            id: media.id,
            url: media.url,
            contentType: .jpeg,
            width: media.width,
            height: media.height,
            altArabic: media.altArabic,
            altEnglish: media.altEnglish,
            creditArabic: media.creditArabic,
            creditEnglish: media.creditEnglish
        )
        let wrongTypeResult = await ArticleHeroImageDecoder.shared.decode(
            pngData,
            media: wrongType,
            maximumPixelSize: 320
        )
        XCTAssertNil(wrongTypeResult)

        let wrongDimensions = ArticleHeroMedia(
            id: media.id,
            url: media.url,
            contentType: media.contentType,
            width: 800,
            height: 450,
            altArabic: media.altArabic,
            altEnglish: media.altEnglish,
            creditArabic: media.creditArabic,
            creditEnglish: media.creditEnglish
        )
        let wrongDimensionResult = await ArticleHeroImageDecoder.shared.decode(
            pngData,
            media: wrongDimensions,
            maximumPixelSize: 320
        )
        XCTAssertNil(wrongDimensionResult)
    }

    private func decodeArticle(heroMedia: String?) throws -> ArticleDTO {
        let heroMedia = heroMedia ?? ""
        let data = Data(
            """
            {
              "id": "article-hero",
              "title": {"ar": "عنوان", "en": "Title"},
              "summary": {"ar": "ملخص", "en": "Summary"},
              "source": "Licensed Desk",
              "publishedAt": "2026-08-08T10:00:00Z",
              "category": "ANALYSIS",
              "format": "STORY",
              "correctionStatus": "ORIGINAL",
              (heroMedia)
              "engagement": {"totalReactions": 2, "publishedComments": 1}
            }
            """.utf8
        )
        return try APIJSON.makeDecoder().decode(ArticleDTO.self, from: data)
    }

    private var validHeroMediaJSON: String {
        """
        "heroMedia": {
          "id": "hero-one",
          "url": "https://media.example.test/articles/hero-one.jpg?sig=demo",
          "contentType": "image/jpeg",
          "width": 1600,
          "height": 900,
          "altText": {
            "ar": "لاعب تجريبي يركض بالكرة",
            "en": "A fictional player running with the ball"
          },
          "credit": {
            "ar": "استوديو سبورتس هب التجريبي",
            "en": "SportsHub Demo Studio"
          }
        },
        """
    }
}
