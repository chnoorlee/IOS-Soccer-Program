import Foundation
import XCTest
@testable import SportsHub

@MainActor
final class PremiumSubscriptionContractTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_788_000_000)

    func testConfigurationFailsClosedUntilBothProductsAndLegalLinksAreValid() {
        XCTAssertEqual(configuration().state, .ready)
        XCTAssertEqual(
            configuration(monthly: nil, annual: nil, privacy: nil, terms: nil).state,
            .unconfigured
        )
        XCTAssertEqual(configuration(monthly: "bad product/id").state, .invalid)
        XCTAssertEqual(configuration(annual: "monthly").state, .invalid)
        XCTAssertEqual(configuration(privacy: "http://publisher.com/privacy").state, .invalid)
        XCTAssertEqual(configuration(terms: "https://user:pass@publisher.com/terms").state, .invalid)
        XCTAssertEqual(configuration(privacy: "https://example.invalid/privacy").state, .invalid)
    }

    func testOffersRequireExactMonthlyAndAnnualPeriodsInOneGroup() throws {
        let valid = offers()

        XCTAssertEqual(try configuration().validatedOffers(valid).map(\.id), [
            "monthly",
            "annual"
        ])
        XCTAssertThrowsError(try configuration().validatedOffers([
            valid[0],
            offer(id: "annual", period: SubscriptionPeriod(value: 12, unit: .month))
        ]))
        XCTAssertThrowsError(try configuration().validatedOffers([
            valid[0],
            offer(
                id: "annual",
                period: SubscriptionPeriod(value: 1, unit: .year),
                group: "other-group"
            )
        ]))
        XCTAssertThrowsError(try configuration().validatedOffers([
            offer(id: "monthly", period: SubscriptionPeriod(value: 1, unit: .month), group: ""),
            offer(id: "annual", period: SubscriptionPeriod(value: 1, unit: .year), group: "")
        ]))
    }

    func testEntitlementRejectsExpiredRevokedUpgradedAndUnverifiedRecords() {
        let records = [
            record(id: "monthly", expires: now.addingTimeInterval(-1)),
            record(id: "monthly", expires: now.addingTimeInterval(100), revoked: now),
            record(id: "annual", expires: now.addingTimeInterval(200), upgraded: true),
            record(id: "annual", expires: now.addingTimeInterval(300), verified: false)
        ]

        let snapshot = PremiumEntitlementPolicy.evaluate(
            records,
            configuredProductIDs: ["monthly", "annual"],
            now: now
        )

        XCTAssertNil(snapshot.entitlement)
        XCTAssertTrue(snapshot.hasVerificationFailure)
    }

    func testLatestVerifiedExpirationWinsWithStableTieBreakers() {
        let snapshot = PremiumEntitlementPolicy.evaluate(
            [
                record(
                    id: "monthly",
                    purchased: now.addingTimeInterval(-300),
                    expires: now.addingTimeInterval(500)
                ),
                record(
                    id: "annual",
                    purchased: now.addingTimeInterval(-200),
                    expires: now.addingTimeInterval(500)
                )
            ],
            configuredProductIDs: ["monthly", "annual"],
            now: now
        )

        XCTAssertEqual(snapshot.entitlement?.productID, "annual")
    }

    func testAdvertisingGateRequiresEnabledAdsAndNoPremiumEntitlement() {
        let entitlement = PremiumEntitlement(
            productID: "monthly",
            purchaseDate: now,
            expirationDate: now.addingTimeInterval(100)
        )

        XCTAssertFalse(PremiumEntitlementPolicy.shouldShowAdvertising(
            advertisingEnabled: false,
            entitlement: nil
        ))
        XCTAssertTrue(PremiumEntitlementPolicy.shouldShowAdvertising(
            advertisingEnabled: true,
            entitlement: nil
        ))
        XCTAssertFalse(PremiumEntitlementPolicy.shouldShowAdvertising(
            advertisingEnabled: true,
            entitlement: entitlement
        ))
    }

    func testModelKeepsAdvertisingOffWhenSubscriptionReleaseGateIsIncomplete() {
        let model = PremiumSubscriptionModel(
            configuration: configuration(
                monthly: nil,
                annual: nil,
                privacy: nil,
                terms: nil,
                advertisingEnabled: true
            ),
            client: UnavailableSubscriptionStoreClient()
        )

        XCTAssertFalse(model.shouldShowAdvertising)
    }

    func testModelLoadsDynamicOffersPurchasesAndRestoresVerifiedOwnership() async {
        let purchasedRecord = record(
            id: "monthly",
            expires: now.addingTimeInterval(2_592_000)
        )
        let client = TestSubscriptionStoreClient(
            offers: offers(),
            purchaseRecord: purchasedRecord
        )
        let evaluationDate = now
        let model = PremiumSubscriptionModel(
            configuration: configuration(advertisingEnabled: true),
            client: client,
            now: { evaluationDate }
        )

        XCTAssertFalse(model.shouldShowAdvertising)
        await model.start()
        XCTAssertEqual(model.offers.map(\.id), ["monthly", "annual"])
        XCTAssertTrue(model.shouldShowAdvertising)

        await model.purchase(offerID: "monthly")
        XCTAssertEqual(model.actionResult, .purchased)
        XCTAssertEqual(model.activeEntitlement?.productID, "monthly")
        XCTAssertFalse(model.shouldShowAdvertising)

        await model.restore()
        XCTAssertEqual(model.actionResult, .restored)
        let syncCount = await client.syncCount()
        XCTAssertEqual(syncCount, 1)
    }

    func testUnverifiedRecordNeverActivatesPremiumAndKeepsVerificationError() async {
        let client = TestSubscriptionStoreClient(
            offers: offers(),
            records: [record(
                id: "annual",
                expires: now.addingTimeInterval(31_536_000),
                verified: false
            )]
        )
        let evaluationDate = now
        let model = PremiumSubscriptionModel(
            configuration: configuration(advertisingEnabled: true),
            client: client,
            now: { evaluationDate }
        )

        await model.refresh()

        XCTAssertNil(model.activeEntitlement)
        XCTAssertTrue(model.hasVerificationFailure)
        XCTAssertEqual(model.error, .verificationFailed)
        XCTAssertFalse(model.shouldShowAdvertising)
    }

    private func configuration(
        monthly: String? = "monthly",
        annual: String? = "annual",
        privacy: String? = "https://publisher.com/privacy",
        terms: String? = "https://publisher.com/terms",
        advertisingEnabled: Bool = false
    ) -> PremiumSubscriptionConfiguration {
        PremiumSubscriptionConfiguration(
            monthlyProductID: monthly,
            annualProductID: annual,
            privacyPolicyURL: privacy,
            termsOfUseURL: terms,
            advertisingEnabled: advertisingEnabled
        )
    }

    private func offers() -> [SubscriptionOffer] {
        [
            offer(id: "monthly", period: SubscriptionPeriod(value: 1, unit: .month)),
            offer(id: "annual", period: SubscriptionPeriod(value: 1, unit: .year))
        ]
    }

    private func offer(
        id: String,
        period: SubscriptionPeriod,
        group: String = "premium-group"
    ) -> SubscriptionOffer {
        SubscriptionOffer(
            id: id,
            displayName: "StoreKit \(id)",
            description: "StoreKit description",
            displayPrice: "SAR 1.00",
            period: period,
            subscriptionGroupID: group
        )
    }

    private func record(
        id: String,
        purchased: Date? = nil,
        expires: Date,
        revoked: Date? = nil,
        upgraded: Bool = false,
        verified: Bool = true
    ) -> SubscriptionTransactionRecord {
        SubscriptionTransactionRecord(
            productID: id,
            purchaseDate: purchased ?? now.addingTimeInterval(-100),
            expirationDate: expires,
            revocationDate: revoked,
            isUpgraded: upgraded,
            isVerified: verified
        )
    }
}

private actor TestSubscriptionStoreClient: SubscriptionStoreClient {
    private let offers: [SubscriptionOffer]
    private var records: [SubscriptionTransactionRecord]
    private let purchaseRecord: SubscriptionTransactionRecord?
    private var synchronizationCount = 0

    init(
        offers: [SubscriptionOffer],
        records: [SubscriptionTransactionRecord] = [],
        purchaseRecord: SubscriptionTransactionRecord? = nil
    ) {
        self.offers = offers
        self.records = records
        self.purchaseRecord = purchaseRecord
    }

    func loadOffers(productIDs: [String]) async throws -> [SubscriptionOffer] {
        offers
    }

    func entitlementRecords(
        productIDs: Set<String>
    ) async -> [SubscriptionTransactionRecord] {
        records.filter { productIDs.contains($0.productID) }
    }

    func purchase(productID: String) async throws -> SubscriptionPurchaseOutcome {
        guard let purchaseRecord, purchaseRecord.productID == productID else {
            throw SubscriptionClientError.transactionMismatch
        }
        records = [purchaseRecord]
        return .purchased(purchaseRecord)
    }

    func sync() async throws {
        synchronizationCount += 1
    }

    func transactionUpdates(productIDs: Set<String>) async -> AsyncStream<Void> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func syncCount() -> Int {
        synchronizationCount
    }
}
