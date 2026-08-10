import Foundation
import StoreKit

actor StoreKitSubscriptionStoreClient: SubscriptionStoreClient {
    private var productsByID: [String: Product] = [:]

    func loadOffers(productIDs: [String]) async throws -> [SubscriptionOffer] {
        let products = try await Product.products(for: productIDs)
        guard Set(products.map(\.id)).count == products.count else {
            throw SubscriptionClientError.invalidProduct
        }
        let byID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        guard products.count == productIDs.count,
              Set(byID.keys) == Set(productIDs) else {
            throw SubscriptionClientError.productUnavailable
        }

        var offers: [SubscriptionOffer] = []
        for productID in productIDs {
            guard let product = byID[productID],
                  product.type == .autoRenewable,
                  let subscription = product.subscription else {
                throw SubscriptionClientError.invalidProduct
            }
            offers.append(SubscriptionOffer(
                id: product.id,
                displayName: product.displayName,
                description: product.description,
                displayPrice: product.displayPrice,
                period: try Self.period(from: subscription.subscriptionPeriod),
                subscriptionGroupID: subscription.subscriptionGroupID
            ))
        }
        productsByID = byID
        return offers
    }

    func entitlementRecords(
        productIDs: Set<String>
    ) async -> [SubscriptionTransactionRecord] {
        var records: [SubscriptionTransactionRecord] = []
        for await result in Transaction.currentEntitlements {
            let record = Self.record(from: result)
            if productIDs.contains(record.productID) {
                records.append(record)
            }
        }
        return records
    }

    func purchase(productID: String) async throws -> SubscriptionPurchaseOutcome {
        let product: Product
        if let existing = productsByID[productID] {
            product = existing
        } else {
            let products = try await Product.products(for: [productID])
            guard products.count == 1,
                  let loaded = products.first,
                  loaded.id == productID else {
                throw SubscriptionClientError.productUnavailable
            }
            product = loaded
            productsByID[productID] = loaded
        }
        guard product.type == .autoRenewable, product.subscription != nil else {
            throw SubscriptionClientError.invalidProduct
        }

        let result = try await product.purchase()
        switch result {
        case let .success(verification):
            guard case let .verified(transaction) = verification else {
                throw SubscriptionClientError.verificationFailed
            }
            guard transaction.productID == productID else {
                throw SubscriptionClientError.transactionMismatch
            }
            let record = Self.record(transaction: transaction, isVerified: true)
            await transaction.finish()
            return .purchased(record)
        case .pending:
            return .pending
        case .userCancelled:
            return .userCancelled
        @unknown default:
            throw SubscriptionClientError.verificationFailed
        }
    }

    func sync() async throws {
        try await AppStore.sync()
    }

    func transactionUpdates(productIDs: Set<String>) async -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    guard !Task.isCancelled else { break }
                    switch result {
                    case let .verified(transaction):
                        guard productIDs.contains(transaction.productID) else { continue }
                        await transaction.finish()
                        continuation.yield(())
                    case let .unverified(transaction, _):
                        guard productIDs.contains(transaction.productID) else { continue }
                        continuation.yield(())
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private static func period(
        from value: Product.SubscriptionPeriod
    ) throws -> SubscriptionPeriod {
        let unit: SubscriptionPeriod.Unit
        switch value.unit {
        case .day: unit = .day
        case .week: unit = .week
        case .month: unit = .month
        case .year: unit = .year
        @unknown default: throw SubscriptionClientError.invalidProduct
        }
        return SubscriptionPeriod(value: value.value, unit: unit)
    }

    private static func record(
        from result: VerificationResult<Transaction>
    ) -> SubscriptionTransactionRecord {
        switch result {
        case let .verified(transaction):
            return record(transaction: transaction, isVerified: true)
        case let .unverified(transaction, _):
            return record(transaction: transaction, isVerified: false)
        }
    }

    private static func record(
        transaction: Transaction,
        isVerified: Bool
    ) -> SubscriptionTransactionRecord {
        SubscriptionTransactionRecord(
            productID: transaction.productID,
            purchaseDate: transaction.purchaseDate,
            expirationDate: transaction.expirationDate,
            revocationDate: transaction.revocationDate,
            isUpgraded: transaction.isUpgraded,
            isVerified: isVerified
        )
    }
}
