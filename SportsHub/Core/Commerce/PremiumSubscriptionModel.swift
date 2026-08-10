import Combine
import Foundation
import StoreKit
import UIKit

@MainActor
final class PremiumSubscriptionModel: ObservableObject {
    @Published private(set) var offers: [SubscriptionOffer] = []
    @Published private(set) var activeEntitlement: PremiumEntitlement?
    @Published private(set) var hasCheckedEntitlement = false
    @Published private(set) var hasVerificationFailure = false
    @Published private(set) var isLoading = false
    @Published private(set) var busyOfferID: String?
    @Published private(set) var error: PremiumSubscriptionError?
    @Published private(set) var actionResult: PremiumSubscriptionActionResult?

    let configuration: PremiumSubscriptionConfiguration

    private enum BusyOperation {
        case purchase
        case restore
        case manage
    }

    private let client: any SubscriptionStoreClient
    private let now: @Sendable () -> Date
    @Published private var busyOperation: BusyOperation?
    private var refreshID: UUID?
    private var entitlementRefreshID: UUID?
    private var didStart = false
    private var updatesTask: Task<Void, Never>?
    private var expirationTask: Task<Void, Never>?

    init(
        configuration: PremiumSubscriptionConfiguration,
        client: any SubscriptionStoreClient,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.configuration = configuration
        self.client = client
        self.now = now
    }

    deinit {
        updatesTask?.cancel()
        expirationTask?.cancel()
    }

    var isBusy: Bool {
        busyOperation != nil
    }

    var isPremiumActive: Bool {
        activeEntitlement != nil
    }

    var shouldShowAdvertising: Bool {
        guard configuration.state == .ready,
              hasCheckedEntitlement,
              !hasVerificationFailure else {
            return false
        }
        return PremiumEntitlementPolicy.shouldShowAdvertising(
            advertisingEnabled: configuration.advertisingEnabled,
            entitlement: activeEntitlement
        )
    }

    static func unavailable() -> PremiumSubscriptionModel {
        PremiumSubscriptionModel(
            configuration: PremiumSubscriptionConfiguration(
                monthlyProductID: nil,
                annualProductID: nil,
                privacyPolicyURL: nil,
                termsOfUseURL: nil,
                advertisingEnabled: false
            ),
            client: UnavailableSubscriptionStoreClient()
        )
    }

    func start() async {
        guard !didStart else { return }
        didStart = true
        guard configuration.canQueryEntitlements else {
            hasCheckedEntitlement = true
            return
        }

        let stream = await client.transactionUpdates(
            productIDs: Set(configuration.productIDs)
        )
        updatesTask = Task { @MainActor [weak self] in
            for await _ in stream {
                guard !Task.isCancelled, let self else { break }
                await self.refreshEntitlement()
            }
        }
        await refresh()
    }

    func refresh() async {
        guard configuration.canQueryEntitlements, busyOperation == nil else { return }
        let operationID = UUID()
        refreshID = operationID
        isLoading = true
        error = nil
        defer {
            if refreshID == operationID {
                isLoading = false
            }
        }

        let entitlementOperationID = UUID()
        entitlementRefreshID = entitlementOperationID
        let records = await client.entitlementRecords(
            productIDs: Set(configuration.productIDs)
        )
        guard refreshID == operationID, !Task.isCancelled else { return }
        if entitlementRefreshID == entitlementOperationID {
            applyEntitlement(records)
        }

        guard configuration.state == .ready else {
            offers = []
            if error != .verificationFailed {
                error = .configurationIncomplete
            }
            return
        }

        do {
            let loadedOffers = try await client.loadOffers(
                productIDs: configuration.productIDs
            )
            let validatedOffers = try configuration.validatedOffers(loadedOffers)
            guard refreshID == operationID, !Task.isCancelled else { return }
            offers = validatedOffers
            if error != .verificationFailed {
                error = nil
            }
        } catch let clientError as SubscriptionClientError {
            guard refreshID == operationID, !Task.isCancelled else { return }
            offers = []
            if error != .verificationFailed {
                error = clientError == .invalidProduct
                    ? .invalidProducts
                    : .productsUnavailable
            }
        } catch {
            guard refreshID == operationID, !Task.isCancelled else { return }
            offers = []
            if error != .verificationFailed {
                error = .productsUnavailable
            }
        }
    }

    func refreshEntitlementStatus() async {
        await refreshEntitlement()
    }

    func purchase(offerID: String) async {
        guard configuration.state == .ready,
              busyOperation == nil,
              offers.contains(where: { $0.id == offerID }) else {
            error = .configurationIncomplete
            return
        }
        busyOperation = .purchase
        invalidateFullRefresh()
        entitlementRefreshID = nil
        busyOfferID = offerID
        error = nil
        actionResult = nil
        defer {
            busyOfferID = nil
            busyOperation = nil
        }

        do {
            let outcome = try await client.purchase(productID: offerID)
            switch outcome {
            case let .purchased(record):
                let snapshot = PremiumEntitlementPolicy.evaluate(
                    [record],
                    configuredProductIDs: Set(configuration.productIDs),
                    now: now()
                )
                guard let entitlement = snapshot.entitlement,
                      !snapshot.hasVerificationFailure else {
                    hasVerificationFailure = true
                    error = .verificationFailed
                    return
                }
                activeEntitlement = entitlement
                hasVerificationFailure = false
                actionResult = .purchased
            case .pending:
                actionResult = .pending
            case .userCancelled:
                break
            }
        } catch let clientError as SubscriptionClientError {
            if clientError == .verificationFailed
                || clientError == .transactionMismatch {
                hasVerificationFailure = true
                error = .verificationFailed
            } else {
                error = .purchaseFailed
            }
        } catch {
            error = .purchaseFailed
        }
    }

    func restore() async {
        guard configuration.canQueryEntitlements, busyOperation == nil else {
            error = .configurationIncomplete
            return
        }
        busyOperation = .restore
        invalidateFullRefresh()
        entitlementRefreshID = nil
        error = nil
        actionResult = nil
        defer { busyOperation = nil }

        do {
            try await client.sync()
            await refreshEntitlement()
            actionResult = activeEntitlement == nil ? .nothingToRestore : .restored
        } catch {
            error = .restoreFailed
        }
    }

    func manageSubscriptions(in scene: UIWindowScene) async {
        guard activeEntitlement != nil, busyOperation == nil else {
            error = .managementUnavailable
            return
        }
        busyOperation = .manage
        invalidateFullRefresh()
        entitlementRefreshID = nil
        error = nil
        actionResult = nil
        defer { busyOperation = nil }
        do {
            try await AppStore.showManageSubscriptions(in: scene)
            await refreshEntitlement()
        } catch {
            error = .managementUnavailable
        }
    }

    func dismissError() {
        error = nil
    }

    func dismissActionResult() {
        actionResult = nil
    }

    func reportManagementUnavailable() {
        error = .managementUnavailable
    }

    private func refreshEntitlement() async {
        guard configuration.canQueryEntitlements else { return }
        let operationID = UUID()
        entitlementRefreshID = operationID
        let records = await client.entitlementRecords(
            productIDs: Set(configuration.productIDs)
        )
        guard entitlementRefreshID == operationID, !Task.isCancelled else { return }
        applyEntitlement(records)
    }

    private func invalidateFullRefresh() {
        refreshID = nil
        isLoading = false
    }

    private func applyEntitlement(_ records: [SubscriptionTransactionRecord]) {
        let snapshot = PremiumEntitlementPolicy.evaluate(
            records,
            configuredProductIDs: Set(configuration.productIDs),
            now: now()
        )
        activeEntitlement = snapshot.entitlement
        hasCheckedEntitlement = true
        hasVerificationFailure = snapshot.hasVerificationFailure
        if snapshot.hasVerificationFailure {
            error = .verificationFailed
        } else if error == .verificationFailed {
            error = nil
        }
        scheduleExpirationCheckpoint()
    }

    private func scheduleExpirationCheckpoint() {
        expirationTask?.cancel()
        guard let expirationDate = activeEntitlement?.expirationDate else {
            expirationTask = nil
            return
        }
        let secondsUntilCheckpoint = min(
            max(expirationDate.timeIntervalSince(now()), 0),
            24 * 60 * 60
        )
        let nanoseconds = UInt64(secondsUntilCheckpoint * 1_000_000_000)
        expirationTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled, let self else { return }
            if let entitlement = self.activeEntitlement,
               entitlement.expirationDate <= self.now() {
                self.activeEntitlement = nil
                self.hasCheckedEntitlement = false
            }
            await self.refreshEntitlement()
        }
    }
}
