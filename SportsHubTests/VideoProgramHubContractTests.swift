import Foundation
import XCTest
@testable import SportsHub

final class VideoProgramHubContractTests: XCTestCase {
    func testListMapsProviderOrderSportAndExplicitFeaturedVideo() throws {
        let payload = try listPayload(programs: [
            programObject(id: "program-one", sport: "FOOTBALL", featuredVideo: NSNull()),
            programObject(
                id: "program-two",
                sport: "ESPORTS",
                featuredVideo: videoObject(id: "episode-featured")
            )
        ])

        let page = try decoder.decode(VideoProgramListResponseDTO.self, from: payload).domain()

        XCTAssertEqual(page.programs.map(\.id), ["program-one", "program-two"])
        XCTAssertEqual(page.programs.map(\.sport), [.football, .esports])
        XCTAssertNil(page.programs[0].featuredVideo)
        XCTAssertEqual(page.programs[1].featuredVideo?.id, "episode-featured")
        XCTAssertFalse(try XCTUnwrap(page.programs[1].featuredVideo).isPlayable)
        XCTAssertFalse(page.hasMore)
        XCTAssertNil(page.nextCursor)
    }

    func testFeaturedVideoAndPublishedDateMustBeExplicitObjectOrNull() throws {
        var missingFeatured = programObject(
            id: "program-one",
            sport: "FOOTBALL",
            featuredVideo: NSNull()
        )
        missingFeatured.removeValue(forKey: "featuredVideo")
        XCTAssertThrowsError(
            try decoder.decode(
                VideoProgramListResponseDTO.self,
                from: listPayload(programs: [missingFeatured])
            )
        ) { error in
            guard case DecodingError.keyNotFound = error else {
                return XCTFail("Expected missing featuredVideo to fail decoding")
            }
        }

        var missingPublishedAt = episodeObject(id: "episode-one", publishedAt: NSNull())
        missingPublishedAt.removeValue(forKey: "publishedAt")
        XCTAssertThrowsError(
            try decoder.decode(
                VideoProgramDetailResponseDTO.self,
                from: detailPayload(episodes: [missingPublishedAt])
            )
        ) { error in
            guard case DecodingError.keyNotFound = error else {
                return XCTFail("Expected missing publishedAt to fail decoding")
            }
        }

        let explicitNull = try decoder.decode(
            VideoProgramDetailResponseDTO.self,
            from: detailPayload(episodes: [episodeObject(id: "episode-one", publishedAt: NSNull())])
        ).domain(expectedProgramID: "program-one")
        XCTAssertNil(explicitNull.episodes.first?.publishedAt)
    }

    func testTextBoundariesAndControlCharactersFailClosed() throws {
        var tooLong = programObject(
            id: "program-one",
            sport: "FOOTBALL",
            featuredVideo: NSNull()
        )
        tooLong["description"] = [
            "ar": String(repeating: "س", count: 501),
            "en": String(repeating: "a", count: 501)
        ]
        assertListContractViolation(programs: [tooLong], field: "data[0].description")

        var controlCharacter = programObject(
            id: "program-one",
            sport: "FOOTBALL",
            featuredVideo: NSNull()
        )
        controlCharacter["title"] = ["ar": "عنوان\u{0007}", "en": "Title"]
        assertListContractViolation(programs: [controlCharacter], field: "data[0].title")

        let unsafeID = programObject(
            id: "program/another-resource",
            sport: "FOOTBALL",
            featuredVideo: NSNull()
        )
        assertListContractViolation(programs: [unsafeID], field: "data[0].id")
    }

    func testDuplicateIdentifiersAndInvalidPagingFailClosed() throws {
        let duplicate = programObject(
            id: "program-one",
            sport: "FOOTBALL",
            featuredVideo: NSNull()
        )
        assertListContractViolation(
            programs: [duplicate, duplicate],
            field: "data.id"
        )

        let valid = [duplicate]
        assertListContractViolation(
            programs: valid,
            page: ["nextCursor": "cursor-with space", "hasMore": true],
            field: "page.nextCursor"
        )
        assertListContractViolation(
            programs: [],
            page: ["nextCursor": "cursor", "hasMore": true],
            field: "page.nextCursor"
        )
        assertListContractViolation(
            programs: valid,
            page: ["nextCursor": "cursor", "hasMore": false],
            field: "page.nextCursor"
        )
    }

    func testDetailRejectsProgramMismatchAndDuplicateEpisodes() throws {
        let mismatchDTO = try decoder.decode(
            VideoProgramDetailResponseDTO.self,
            from: detailPayload(episodes: [])
        )
        XCTAssertThrowsError(try mismatchDTO.domain(expectedProgramID: "another-program")) {
            XCTAssertEqual(
                $0 as? SportsDataError,
                .contractViolation(field: "data.program.id")
            )
        }

        let episode = episodeObject(id: "episode-one", publishedAt: NSNull())
        let duplicateDTO = try decoder.decode(
            VideoProgramDetailResponseDTO.self,
            from: detailPayload(episodes: [episode, episode])
        )
        XCTAssertThrowsError(try duplicateDTO.domain(expectedProgramID: "program-one")) {
            XCTAssertEqual(
                $0 as? SportsDataError,
                .contractViolation(field: "data.episodes.id")
            )
        }
    }

    func testCrossPageProgramAndEpisodeDuplicatesFailClosed() throws {
        let program = VideoProgramSummary(
            program: VideoProgram(
                id: "program-one",
                titleArabic: "برنامج",
                titleEnglish: "Program"
            ),
            descriptionArabic: "وصف",
            descriptionEnglish: "Description",
            sport: .football,
            featuredVideo: nil
        )
        let page = VideoProgramPage(programs: [program], nextCursor: nil, hasMore: false)
        XCTAssertThrowsError(try page.appending(to: [program])) {
            XCTAssertEqual(
                $0 as? SportsDataError,
                .contractViolation(field: "data.id")
            )
        }

        let video = SportsVideo(
            id: "episode-one",
            type: .original,
            titleArabic: "حلقة",
            titleEnglish: "Episode",
            descriptionArabic: "وصف",
            descriptionEnglish: "Description",
            durationSeconds: 60,
            isPlayable: false,
            availabilityReason: .notStarted
        )
        let episode = VideoProgramEpisode(video: video, publishedAt: nil)
        let details = VideoProgramDetailsPage(
            program: program,
            episodes: [episode],
            nextCursor: nil,
            hasMore: false
        )
        XCTAssertThrowsError(try details.appendingEpisodes(to: [episode])) {
            XCTAssertEqual(
                $0 as? SportsDataError,
                .contractViolation(field: "data.episodes.id")
            )
        }
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func assertListContractViolation(
        programs: [[String: Any]],
        page: [String: Any] = ["nextCursor": NSNull(), "hasMore": false],
        field: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try decoder.decode(
                VideoProgramListResponseDTO.self,
                from: listPayload(programs: programs, page: page)
            ).domain(),
            file: file,
            line: line
        ) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: field),
                file: file,
                line: line
            )
        }
    }

    private func listPayload(
        programs: [[String: Any]],
        page: [String: Any] = ["nextCursor": NSNull(), "hasMore": false]
    ) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["data": programs, "page": page])
    }

    private func detailPayload(episodes: [[String: Any]]) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "data": [
                "program": programObject(
                    id: "program-one",
                    sport: "FOOTBALL",
                    featuredVideo: NSNull()
                ),
                "episodes": episodes,
                "page": ["nextCursor": NSNull(), "hasMore": false]
            ]
        ])
    }

    private func programObject(
        id: String,
        sport: String,
        featuredVideo: Any
    ) -> [String: Any] {
        [
            "id": id,
            "title": ["ar": "عنوان \(id)", "en": "Title \(id)"],
            "description": ["ar": "وصف تحريري", "en": "Editorial description"],
            "sport": sport,
            "featuredVideo": featuredVideo
        ]
    }

    private func episodeObject(id: String, publishedAt: Any) -> [String: Any] {
        ["video": videoObject(id: id), "publishedAt": publishedAt]
    }

    private func videoObject(id: String) -> [String: Any] {
        [
            "id": id,
            "type": "ORIGINAL",
            "title": ["ar": "عنوان الحلقة", "en": "Episode title"],
            "description": ["ar": "وصف", "en": "Description"],
            "poster": NSNull(),
            "durationSeconds": 300,
            "isPlayable": false,
            "availabilityReason": "NOT_STARTED"
        ]
    }
}
