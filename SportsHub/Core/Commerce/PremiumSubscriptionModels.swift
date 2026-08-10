import Foundation

enum PremiumSubscriptionConfigurationState: Equatable, Sendable {
    case unconfigured
    case invalid
    case ready
}

struct PremiumSubscriptionConfiguration: Equatable, Sendable {
    let monthlyProductID: String?
    let annualProductID: String?
    let privacyPolicyURL: URL?
    let termsOfUseURL: URL?
    let advertisingEnabled: Bool
    let isPreview: Bool

    private let hasInvalidProductID: Bool
    private let hasInvalidLegalURL: Bool
    private let hasAnyRawConfiguration: Bool

    init(
        monthlyProductID: String?,
        annualProductID: String?,
        privacyPolicyURL: String?,
        termsOfUseURL: String?,
        advertisingEnabled: Bool
    ) {
        self.init(
            monthlyProductID: monthlyProductID,
            annualProductID: annualProductID,
            privacyPolicyURL: privacyPolicyURL,
            termsOfUseURL: termsOfUseURL,
            advertisingEnabled: advertisingEnabled,
            previewMode: false
        )
    }

    private init(
        monthlyProductID: String?,
        annualProductID: String?,
        privacyPolicyURL: String?,
        termsOfUseURL: String?,
        advertisingEnabled: Bool,
        previewMode: Bool
    ) {
        let monthly = Self.normalized(monthlyProductID)
        let annual = Self.normalized(annualProductID)
        let privacy = Self.normalized(privacyPolicyURL)
        let terms = Self.normalized(termsOfUseURL)

        let validatedMonthly = monthly.flatMap {
            Self.isValidProductID($0) ? $0 : nil
        }
        let validatedAnnual = annual.flatMap {
            Self.isValidProductID($0) ? $0 : nil
        }
        let validatedPrivacy = privacy.flatMap {
            Self.validatedLegalURL($0, allowsInvalidHost: previewMode)
        }
        let validatedTerms = terms.flatMap {
            Self.validatedLegalURL($0, allowsInvalidHost: previewMode)
        }

        self.monthlyProductID = validatedMonthly
        self.annualProductID = validatedAnnual
        self.privacyPolicyURL = validatedPrivacy
        self.termsOfUseURL = validatedTerms
        self.advertisingEnabled = advertisingEnabled
        self.isPreview = previewMode
        hasInvalidProductID = (monthly != nil && validatedMonthly == nil)
            || (annual != nil && validatedAnnual == nil)
        hasInvalidLegalURL = (privacy != nil && validatedPrivacy == nil)
            || (terms != nil && validatedTerms == nil)
        hasAnyRawConfiguration = monthly != nil || annual != nil || privacy != nil || terms != nil
    }

    var state: PremiumSubscriptionConfigurationState {
        if !hasAnyRawConfiguration {
            return .unconfigured
        }
        guard !hasInvalidProductID,
              !hasInvalidLegalURL,
              let monthlyProductID,
              let annualProductID,
              monthlyProductID != annualProductID,
              privacyPolicyURL != nil,
              termsOfUseURL != nil else {
            return .invalid
        }
        return .ready
    }

    var productIDs: [String] {
        [monthlyProductID, annualProductID].compactMap { $0 }
    }

    var canQueryEntitlements: Bool {
        !productIDs.isEmpty
    }

    func validatedOffers(_ offers: [SubscriptionOffer]) throws -> [SubscriptionOffer] {
        guard state == .ready,
              offers.count == 2,
              Set(offers.map(\.id)) == Set(productIDs),
              Set(offers.map(\.subscriptionGroupID)).count == 1,
              let monthlyProductID,
              let annualProductID,
              let monthly = offers.first(where: { $0.id == monthlyProductID }),
              let annual = offers.first(where: { $0.id == annualProductID }),
              !monthly.subscriptionGroupID.isEmpty,
              monthly.period == SubscriptionPeriod(value: 1, unit: .month),
              annual.period == SubscriptionPeriod(value: 1, unit: .year) else {
            throw SubscriptionClientError.invalidProduct
        }
        let byID = Dictionary(uniqueKeysWithValues: offers.map { ($0.id, $0) })
        return productIDs.compactMap { byID[$0] }
    }

    static func from(bundle: Bundle) -> PremiumSubscriptionConfiguration {
        PremiumSubscriptionConfiguration(
            monthlyProductID: string(
                for: "SportsPremiumMonthlyProductID",
                in: bundle
            ),
            annualProductID: string(
                for: "SportsPremiumAnnualProductID",
                in: bundle
            ),
            privacyPolicyURL: string(
                for: "SportsPremiumPrivacyURL",
                in: bundle
            ),
            termsOfUseURL: string(
                for: "SportsPremiumTermsURL",
                in: bundle
            ),
            advertisingEnabled: boolean(
                for: "SportsAdvertisingEnabled",
                in: bundle
            )
        )
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func isValidProductID(_ value: String) -> Bool {
        let allowed = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"
        )
        return (1...128).contains(value.count)
            && value.unicodeScalars.allSatisfy(allowed.contains)
    }

    private static func validatedLegalURL(
        _ value: String,
        allowsInvalidHost: Bool
    ) -> URL? {
        guard value.count <= 2_048,
              let url = URL(string: value),
              url.scheme?.lowercased() == "https",
              let host = url.host,
              !host.isEmpty,
              url.user == nil,
              url.password == nil,
              url.fragment == nil else {
            return nil
        }
        let normalizedHost = host.lowercased()
        guard allowsInvalidHost
            || (normalizedHost != "invalid" && !normalizedHost.hasSuffix(".invalid")) else {
            return nil
        }
        return url
    }

    private static func string(for key: String, in bundle: Bundle) -> String? {
        bundle.object(forInfoDictionaryKey: key) as? String
    }

    private static func boolean(for key: String, in bundle: Bundle) -> Bool {
        if let value = bundle.object(forInfoDictionaryKey: key) as? Bool {
            return value
        }
        if let value = bundle.object(forInfoDictionaryKey: key) as? String {
            return ["1", "true", "yes"].contains(value.lowercased())
        }
        return false
    }
}

#if DEBUG
extension PremiumSubscriptionConfiguration {
    static let preview = PremiumSubscriptionConfiguration(
        monthlyProductID: "com.example.sportshub.preview.monthly",
        annualProductID: "com.example.sportshub.preview.annual",
        privacyPolicyURL: "https:" + "//example.invalid/privacy",
        termsOfUseURL: "https:" + "//example.invalid/terms",
        advertisingEnabled: true,
        previewMode: true
    )
}
#endif

struct SubscriptionPeriod: Equatable, Hashable, Sendable {
    enum Unit: String, Equatable, Hashable, Sendable {
        case day
        case week
        case month
        case year
    }

    let value: Int
    let unit: Unit
}

struct SubscriptionOffer: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let displayName: String
    let description: String
    let displayPrice: String
    let period: SubscriptionPeriod
    let subscriptionGroupID: String
}

struct SubscriptionTransactionRecord: Equatable, Hashable, Sendable {
    let productID: String
    let purchaseDate: Date
    let expirationDate: Date?
    let revocationDate: Date?
    let isUpgraded: Bool
    let isVerified: Bool
}

struct PremiumEntitlement: Equatable, Hashable, Sendable {
    let productID: String
    let purchaseDate: Date
    let expirationDate: Date
}

struct SubscriptionEntitlementSnapshot: Equatable, Sendable {
    let entitlement: PremiumEntitlement?
    let hasVerificationFailure: Bool
}

enum PremiumEntitlementPolicy {
    static func evaluate(
        _ records: [SubscriptionTransactionRecord],
        configuredProductIDs: Set<String>,
        now: Date
    ) -> SubscriptionEntitlementSnapshot {
        let relevant = records.filter { configuredProductIDs.contains($0.productID) }
        let hasVerificationFailure = relevant.contains { !$0.isVerified }
        let active = relevant.compactMap { record -> PremiumEntitlement? in
            guard record.isVerified,
                  record.revocationDate == nil,
                  !record.isUpgraded,
                  let expirationDate = record.expirationDate,
                  expirationDate > now else {
                return nil
            }
            return PremiumEntitlement(
                productID: record.productID,
                purchaseDate: record.purchaseDate,
                expirationDate: expirationDate
            )
        }
        .sorted { lhs, rhs in
            if lhs.expirationDate != rhs.expirationDate {
                return lhs.expirationDate > rhs.expirationDate
            }
            if lhs.purchaseDate != rhs.purchaseDate {
                return lhs.purchaseDate > rhs.purchaseDate
            }
            return lhs.productID < rhs.productID
        }
        .first
        return SubscriptionEntitlementSnapshot(
            entitlement: active,
            hasVerificationFailure: hasVerificationFailure
        )
    }

    static func shouldShowAdvertising(
        advertisingEnabled: Bool,
        entitlement: PremiumEntitlement?
    ) -> Bool {
        advertisingEnabled && entitlement == nil
    }
}

enum SubscriptionPurchaseOutcome: Equatable, Sendable {
    case purchased(SubscriptionTransactionRecord)
    case pending
    case userCancelled
}

enum PremiumSubscriptionActionResult: Equatable, Sendable {
    case purchased
    case pending
    case restored
    case nothingToRestore

    var localizationKey: String {
        switch self {
        case .purchased: "premium.action.purchased"
        case .pending: "premium.action.pending"
        case .restored: "premium.action.restored"
        case .nothingToRestore: "premium.action.nothingToRestore"
        }
    }
}

enum PremiumSubscriptionError: Error, Equatable, Sendable {
    case configurationIncomplete
    case productsUnavailable
    case invalidProducts
    case verificationFailed
    case purchaseFailed
    case restoreFailed
    case managementUnavailable

    var localizationKey: String {
        switch self {
        case .configurationIncomplete: "premium.error.configuration"
        case .productsUnavailable: "premium.error.products"
        case .invalidProducts: "premium.error.invalidProducts"
        case .verificationFailed: "premium.error.verification"
        case .purchaseFailed: "premium.error.purchase"
        case .restoreFailed: "premium.error.restore"
        case .managementUnavailable: "premium.error.management"
        }
    }
}

enum SubscriptionClientError: Error, Equatable, Sendable {
    case productUnavailable
    case invalidProduct
    case verificationFailed
    case transactionMismatch
}

protocol SubscriptionStoreClient: Sendable {
    func loadOffers(productIDs: [String]) async throws -> [SubscriptionOffer]
    func entitlementRecords(
        productIDs: Set<String>
    ) async -> [SubscriptionTransactionRecord]
    func purchase(productID: String) async throws -> SubscriptionPurchaseOutcome
    func sync() async throws
    func transactionUpdates(productIDs: Set<String>) async -> AsyncStream<Void>
}

actor UnavailableSubscriptionStoreClient: SubscriptionStoreClient {
    func loadOffers(productIDs: [String]) async throws -> [SubscriptionOffer] {
        throw SubscriptionClientError.productUnavailable
    }

    func entitlementRecords(
        productIDs: Set<String>
    ) async -> [SubscriptionTransactionRecord] {
        []
    }

    func purchase(productID: String) async throws -> SubscriptionPurchaseOutcome {
        throw SubscriptionClientError.productUnavailable
    }

    func sync() async throws {
        throw SubscriptionClientError.productUnavailable
    }

    func transactionUpdates(productIDs: Set<String>) async -> AsyncStream<Void> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}

#if DEBUG
actor PreviewSubscriptionStoreClient: SubscriptionStoreClient {
    private let now: @Sendable () -> Date
    private var records: [SubscriptionTransactionRecord] = []

    init(now: @escaping @Sendable () -> Date = Date.init) {
        self.now = now
    }

    func loadOffers(productIDs: [String]) async throws -> [SubscriptionOffer] {
        let offers = [
            SubscriptionOffer(
                id: "com.example.sportshub.preview.monthly",
                displayName: "Preview monthly pass",
                description: "Fictional StoreKit preview offer for UI testing only.",
                displayPrice: "SAR 4.99",
                period: SubscriptionPeriod(value: 1, unit: .month),
                subscriptionGroupID: "preview-season-pass"
            ),
            SubscriptionOffer(
                id: "com.example.sportshub.preview.annual",
                displayName: "Preview annual pass",
                description: "Fictional StoreKit preview offer for UI testing only.",
                displayPrice: "SAR 39.99",
                period: SubscriptionPeriod(value: 1, unit: .year),
                subscriptionGroupID: "preview-season-pass"
            )
        ]
        let byID = Dictionary(uniqueKeysWithValues: offers.map { ($0.id, $0) })
        guard productIDs.allSatisfy({ byID[$0] != nil }) else {
            throw SubscriptionClientError.productUnavailable
        }
        return productIDs.compactMap { byID[$0] }
    }

    func entitlementRecords(
        productIDs: Set<String>
    ) async -> [SubscriptionTransactionRecord] {
        records.filter { productIDs.contains($0.productID) }
    }

    func purchase(productID: String) async throws -> SubscriptionPurchaseOutcome {
        guard PremiumSubscriptionConfiguration.preview.productIDs.contains(productID) else {
            throw SubscriptionClientError.transactionMismatch
        }
        let purchaseDate = now()
        let isAnnual = PremiumSubscriptionConfiguration.preview.annualProductID
            .map { $0 == productID } ?? false
        let duration = TimeInterval((isAnnual ? 365 : 30) * 24 * 60 * 60)
        let record = SubscriptionTransactionRecord(
            productID: productID,
            purchaseDate: purchaseDate,
            expirationDate: purchaseDate.addingTimeInterval(duration),
            revocationDate: nil,
            isUpgraded: false,
            isVerified: true
        )
        records = [record]
        return .purchased(record)
    }

    func sync() async throws {}

    func transactionUpdates(productIDs: Set<String>) async -> AsyncStream<Void> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
#endif
