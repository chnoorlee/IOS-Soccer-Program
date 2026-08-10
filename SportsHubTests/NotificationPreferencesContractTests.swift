import Foundation
import XCTest
@testable import SportsHub

final class NotificationPreferencesContractTests: XCTestCase {
    func testLegacyCardPreferenceMigratesWithoutOptingIntoSubstitutions() throws {
        let response = try decodeResponse(
            """
            {
              "data": {
                "breakingNews": true,
                "lineup": true,
                "kickoff": true,
                "goal": true,
                "card": false,
                "halfTime": true,
                "fullTime": true
              }
            }
            """
        )

        let preferences = response.data.domain()

        XCTAssertFalse(preferences.yellowCard)
        XCTAssertFalse(preferences.redCard)
        XCTAssertFalse(preferences.substitution)
    }

    func testGranularCardPreferencesOverrideLegacyAggregate() throws {
        let response = try decodeResponse(
            """
            {
              "data": {
                "breakingNews": true,
                "lineup": true,
                "kickoff": true,
                "goal": true,
                "card": false,
                "yellowCard": true,
                "redCard": false,
                "substitution": true,
                "halfTime": true,
                "fullTime": true
              }
            }
            """
        )

        let preferences = response.data.domain()

        XCTAssertTrue(preferences.yellowCard)
        XCTAssertFalse(preferences.redCard)
        XCTAssertTrue(preferences.substitution)
    }

    func testEveryPreferenceMutationChangesOnlyItsOwnCategory() {
        let expectedTypes: [NotificationPreferenceType] = [
            .breakingNews,
            .lineup,
            .kickoff,
            .goal,
            .yellowCard,
            .redCard,
            .substitution,
            .halfTime,
            .fullTime
        ]
        XCTAssertEqual(NotificationPreferenceType.allCases, expectedTypes)

        for selectedType in expectedTypes {
            let updated = NotificationPreferences.allEnabled.setting(selectedType, enabled: false)
            for candidateType in expectedTypes {
                XCTAssertEqual(
                    updated[candidateType],
                    candidateType != selectedType,
                    "Only \(selectedType.rawValue) may change"
                )
            }
        }
    }

    func testGranularPatchEncodesExactlyOneField() throws {
        let patch = NotificationPreferencesPatchDTO(type: .substitution, enabled: false)
        let data = try JSONEncoder().encode(patch)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(object.count, 1)
        XCTAssertEqual(object["substitution"] as? Bool, false)
    }

    private func decodeResponse(_ json: String) throws -> NotificationPreferencesResponseDTO {
        try JSONDecoder().decode(
            NotificationPreferencesResponseDTO.self,
            from: Data(json.utf8)
        )
    }
}
