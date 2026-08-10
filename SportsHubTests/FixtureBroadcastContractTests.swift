import Foundation
import XCTest
@testable import SportsHub

final class FixtureBroadcastContractTests: XCTestCase {
    func testWireListingsPreserveProviderOrderAndLocalizedMetadata() throws {
        let dto = try APIJSON.makeDecoder().decode(
            FixtureDTO.self,
            from: Data(
                fixtureJSON(
                    broadcasts: [arabicBroadcast, englishBroadcast, noCommentaryBroadcast]
                ).utf8
            )
        )

        let fixture = try dto.domain(field: "fixture")

        XCTAssertEqual(fixture.broadcasts.map(\.channelEnglish), [
            "Demo Stadium Channel",
            "Demo World Sports",
            "Demo Free Radio"
        ])
        XCTAssertEqual(fixture.broadcasts[0].regionCode, "SA")
        XCTAssertEqual(fixture.broadcasts[0].commentatorArabic, "المعلق التجريبي سامر")
        XCTAssertEqual(fixture.broadcasts[0].audioLanguageCode, "ar")
        XCTAssertEqual(fixture.broadcasts[1].audioLanguageCode, "en-GB")
        XCTAssertNil(fixture.broadcasts[2].commentatorEnglish)
        XCTAssertNil(fixture.broadcasts[2].audioLanguageCode)
    }

    func testMissingWireArrayAndLegacyDomainSnapshotDecodeAsEmpty() throws {
        let dto = try APIJSON.makeDecoder().decode(
            FixtureDTO.self,
            from: Data(fixtureJSON(broadcasts: nil).utf8)
        )
        XCTAssertTrue(try dto.domain(field: "fixture").broadcasts.isEmpty)

        let fixture = makeDomainFixture(broadcasts: [domainBroadcast])
        let encoded = try JSONEncoder().encode(fixture)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "broadcasts")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(Fixture.self, from: legacyData)
        let reencoded = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded))
                as? [String: Any]
        )

        XCTAssertTrue(decoded.broadcasts.isEmpty)
        XCTAssertNotNil(reencoded["broadcasts"])
    }

    func testWireContractRejectsInvalidRegionAndLanguageTags() throws {
        assertContractViolation(
            fixtureJSON(broadcasts: [
                arabicBroadcast.replacingOccurrences(of: "\"SA\"", with: "\"sa\"")
            ])
        )
        assertContractViolation(
            fixtureJSON(broadcasts: [
                arabicBroadcast.replacingOccurrences(
                    of: "\"audioLanguageCode\":\"ar\"",
                    with: "\"audioLanguageCode\":\"AR\""
                )
            ])
        )
        assertContractViolation(
            fixtureJSON(broadcasts: [
                arabicBroadcast.replacingOccurrences(
                    of: "\"audioLanguageCode\":\"ar\"",
                    with: "\"audioLanguageCode\":\"ar-sa\""
                )
            ])
        )
        assertContractViolation(
            fixtureJSON(broadcasts: [
                arabicBroadcast.replacingOccurrences(of: "\"SA\"", with: "\" SA \"")
            ])
        )
        assertContractViolation(
            fixtureJSON(broadcasts: [
                arabicBroadcast.replacingOccurrences(
                    of: "\"audioLanguageCode\":\"ar\"",
                    with: "\"audioLanguageCode\":\" ar \""
                )
            ])
        )
    }

    func testWireContractRejectsBroadcastTextBoundsAndControlCharacters() {
        let oversizedChannel = String(repeating: "A", count: 101)
        assertContractViolation(
            fixtureJSON(broadcasts: [
                arabicBroadcast.replacingOccurrences(
                    of: "Demo Stadium Channel",
                    with: oversizedChannel
                )
            ])
        )
        assertContractViolation(
            fixtureJSON(broadcasts: [
                arabicBroadcast.replacingOccurrences(
                    of: "Demo Stadium Channel",
                    with: "Demo\\u0007Stadium Channel"
                )
            ])
        )
    }

    func testWireContractRejectsDuplicatesOverflowAndCancelledListings() throws {
        let caseVariant = arabicBroadcast.replacingOccurrences(
            of: "Demo Stadium Channel",
            with: "demo stadium channel"
        )
        assertContractViolation(fixtureJSON(broadcasts: [arabicBroadcast, caseVariant]))
        assertContractViolation(
            fixtureJSON(broadcasts: Array(repeating: arabicBroadcast, count: 13))
        )
        assertContractViolation(
            fixtureJSON(state: "CANCELLED", broadcasts: [arabicBroadcast])
        )
        assertContractViolation(
            fixtureJSON(state: "POSTPONED", broadcasts: [arabicBroadcast])
        )
    }

    func testDomainDisplayNamesRespectSelectedLanguageAndKnownCodes() {
        XCTAssertEqual(domainBroadcast.channel(in: .arabic), "قناة الملعب التجريبية")
        XCTAssertEqual(domainBroadcast.channel(in: .english), "Demo Stadium Channel")
        XCTAssertEqual(domainBroadcast.commentator(in: .english), "Demo commentator Samir")
        XCTAssertFalse(domainBroadcast.regionName(in: .arabic).isEmpty)
        XCTAssertFalse(domainBroadcast.audioLanguageName(in: .english)?.isEmpty ?? true)
    }

    private func assertContractViolation(
        _ payload: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            let dto = try APIJSON.makeDecoder().decode(
                FixtureDTO.self,
                from: Data(payload.utf8)
            )
            _ = try dto.domain(field: "fixture")
            XCTFail("Expected an invalid broadcast contract", file: file, line: line)
        } catch let error as SportsDataError {
            guard case .contractViolation = error else {
                return XCTFail("Expected contract violation, received \(error)", file: file, line: line)
            }
        } catch {
            XCTFail("Expected SportsDataError, received \(error)", file: file, line: line)
        }
    }

    private func fixtureJSON(
        state: String = "SCHEDULED",
        broadcasts: [String]?
    ) -> String {
        let broadcastProperty = broadcasts.map {
            ",\"broadcasts\":[\($0.joined(separator: ","))]"
        } ?? ""
        return """
        {
          "id":"fixture-broadcast",
          "competition":{"id":"competition-1","name":{"ar":"الدوري","en":"League"},"sport":"FOOTBALL"},
          "homeTeam":{"id":"team-home","name":{"ar":"الأول","en":"Home"},"monogram":"HOM"},
          "awayTeam":{"id":"team-away","name":{"ar":"الثاني","en":"Away"},"monogram":"AWY"},
          "kickoffAt":"2026-08-07T18:00:00Z",
          "state":"\(state)",
          "minute":null,
          "score":null,
          "venue":{"ar":"الملعب","en":"Stadium"},
          "revision":0\(broadcastProperty)
        }
        """
    }

    private var arabicBroadcast: String {
        """
        {"regionCode":"SA","channel":{"ar":"قناة الملعب التجريبية","en":"Demo Stadium Channel"},"commentator":{"ar":"المعلق التجريبي سامر","en":"Demo commentator Samir"},"audioLanguageCode":"ar"}
        """
    }

    private var englishBroadcast: String {
        """
        {"regionCode":"SA","channel":{"ar":"الرياضة العالمية التجريبية","en":"Demo World Sports"},"commentator":{"ar":"تعليق إنجليزي تجريبي","en":"Demo English commentary"},"audioLanguageCode":"en-GB"}
        """
    }

    private var noCommentaryBroadcast: String {
        """
        {"regionCode":"AE","channel":{"ar":"إذاعة تجريبية مجانية","en":"Demo Free Radio"},"commentator":null,"audioLanguageCode":null}
        """
    }

    private var domainBroadcast: FixtureBroadcast {
        FixtureBroadcast(
            regionCode: "SA",
            channelArabic: "قناة الملعب التجريبية",
            channelEnglish: "Demo Stadium Channel",
            commentatorArabic: "المعلق التجريبي سامر",
            commentatorEnglish: "Demo commentator Samir",
            audioLanguageCode: "ar"
        )
    }

    private func makeDomainFixture(broadcasts: [FixtureBroadcast]) -> Fixture {
        Fixture(
            id: "fixture-broadcast",
            competition: Competition(
                id: "competition-1",
                nameArabic: "الدوري",
                nameEnglish: "League",
                currentSeasonID: nil,
                seasons: []
            ),
            homeTeam: Team(
                id: "team-home",
                nameArabic: "الأول",
                nameEnglish: "Home",
                monogram: "HOM",
                colorHex: "057385"
            ),
            awayTeam: Team(
                id: "team-away",
                nameArabic: "الثاني",
                nameEnglish: "Away",
                monogram: "AWY",
                colorHex: "A1660D"
            ),
            kickoff: Date(timeIntervalSince1970: 1_788_000_000),
            state: .upcoming,
            minute: nil,
            homeScore: nil,
            awayScore: nil,
            venueArabic: "الملعب",
            venueEnglish: "Stadium",
            broadcasts: broadcasts,
            revision: 0
        )
    }
}
