import SwiftUI
import UIKit

struct SubscriptionView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var subscriptionStore: PremiumSubscriptionModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var actionFocused: Bool
    @AccessibilityFocusState private var errorFocused: Bool

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                seasonPass
                ownershipCard
                benefitSection
                offerSection
                actionSection
                legalSection
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle("premium.title")
        .accessibilityIdentifier("premium.screen")
        .task { await subscriptionStore.start() }
        .refreshable { await subscriptionStore.refresh() }
        .onChange(of: subscriptionStore.actionResult) { _, newValue in
            if newValue != nil {
                moveFocus(toError: false)
            }
        }
        .onChange(of: subscriptionStore.error) { _, newValue in
            if newValue != nil {
                moveFocus(toError: true)
            }
        }
    }

    private var seasonPass: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Label("premium.passEyebrow", systemImage: "sparkles")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white)

                Text("premium.passTitle")
                    .font(.system(.largeTitle, design: .rounded).weight(.black))
                    .fixedSize(horizontal: false, vertical: true)

                Text("premium.passBody")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.84))
                    .fixedSize(horizontal: false, vertical: true)

                if subscriptionStore.configuration.isPreview {
                    Label("premium.previewBoundary", systemImage: "testtube.2")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)

            VStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { _ in
                    Circle()
                        .fill(AppTheme.background)
                        .frame(width: 12, height: 12)
                }
            }
            .padding(.vertical, 14)
            .accessibilityHidden(true)
        }
        .background(AppTheme.ink)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("premium.pass")
    }

    private var ownershipCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(ownershipTitleKey, systemImage: ownershipSystemImage)
                .font(.headline)
                .foregroundStyle(ownershipColor)
            Text(ownershipBodyKey)
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            if let entitlement = subscriptionStore.activeEntitlement {
                LabeledContent("premium.expiresLabel") {
                    Text(
                        entitlement.expirationDate,
                        format: .dateTime
                            .day()
                            .month(.wide)
                            .year()
                            .locale(appModel.language.locale)
                    )
                    .monospacedDigit()
                }
                .font(.subheadline.weight(.semibold))
            }

            Divider()

            Label(advertisingStateKey, systemImage: advertisingSystemImage)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .sportsCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("premium.ownership")
    }

    private var benefitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("premium.benefitsTitle")
                .font(.title3.weight(.black))
                .accessibilityAddTraits(.isHeader)

            benefitRow(
                icon: "rectangle.slash.fill",
                title: "premium.benefit.adFreeTitle",
                body: "premium.benefit.adFreeBody"
            )
            benefitRow(
                icon: "heart.fill",
                title: "premium.benefit.supportTitle",
                body: "premium.benefit.supportBody"
            )
            benefitRow(
                icon: "play.slash.fill",
                title: "premium.benefit.rightsTitle",
                body: "premium.benefit.rightsBody"
            )
        }
    }

    @ViewBuilder
    private var offerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("premium.offersTitle")
                .font(.title3.weight(.black))
                .accessibilityAddTraits(.isHeader)

            switch subscriptionStore.configuration.state {
            case .unconfigured:
                configurationBoundary(
                    title: "premium.unconfiguredTitle",
                    body: "premium.unconfiguredBody"
                )
            case .invalid:
                configurationBoundary(
                    title: "premium.invalidConfigurationTitle",
                    body: "premium.invalidConfigurationBody"
                )
            case .ready:
                if subscriptionStore.isPremiumActive {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("premium.activeOfferTitle", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(AppTheme.accent)
                        Text("premium.activeOfferBody")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sportsCard()
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("premium.activeOfferBoundary")
                } else if subscriptionStore.isLoading && subscriptionStore.offers.isEmpty {
                    ProgressView("premium.loadingProducts")
                        .frame(maxWidth: .infinity, minHeight: 88)
                        .accessibilityIdentifier("premium.loading")
                } else if subscriptionStore.offers.isEmpty {
                    configurationBoundary(
                        title: "premium.productsUnavailableTitle",
                        body: "premium.productsUnavailableBody"
                    )
                    Button("premium.retryProducts") {
                        Task { await subscriptionStore.refresh() }
                    }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("premium.retry")
                } else {
                    ForEach(subscriptionStore.offers) { offer in
                        offerCard(offer)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let actionResult = subscriptionStore.actionResult {
                HStack(alignment: .top, spacing: 10) {
                    Label(
                        LocalizedStringKey(actionResult.localizationKey),
                        systemImage: actionResult == .pending
                            ? "clock.badge.questionmark"
                            : "checkmark.seal.fill"
                    )
                    .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 0)
                    Button("action.dismiss") {
                        subscriptionStore.dismissActionResult()
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
                .padding(12)
                .background(AppTheme.accent.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityElement(children: .contain)
                .accessibilityFocused($actionFocused)
                .accessibilityIdentifier("premium.actionResult")
            }

            if let error = subscriptionStore.error {
                HStack(alignment: .top, spacing: 10) {
                    Label(
                        LocalizedStringKey(error.localizationKey),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.live)
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("action.dismiss") {
                        subscriptionStore.dismissError()
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
                .padding(12)
                .background(AppTheme.live.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityElement(children: .contain)
                .accessibilityFocused($errorFocused)
                .accessibilityIdentifier("premium.error")
            }

            if subscriptionStore.configuration.canQueryEntitlements {
                Button {
                    Task { await subscriptionStore.restore() }
                } label: {
                    Label("premium.restore", systemImage: "arrow.clockwise.circle.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .disabled(subscriptionStore.isBusy)
                .accessibilityHint(Text("premium.restoreHint"))
                .accessibilityIdentifier("premium.restore")
            }

            if subscriptionStore.isPremiumActive {
                Button {
                    manageSubscriptions()
                } label: {
                    Label("premium.manage", systemImage: "person.crop.circle.badge.gearshape")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .disabled(subscriptionStore.isBusy)
                .accessibilityHint(Text("premium.manageHint"))
                .accessibilityIdentifier("premium.manage")
            }
        }
    }

    @ViewBuilder
    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("premium.renewalNotice")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            if subscriptionStore.configuration.isPreview {
                Text("premium.previewLegalNotice")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.warm)
            } else {
                if let privacyURL = subscriptionStore.configuration.privacyPolicyURL {
                    Link("premium.privacyPolicy", destination: privacyURL)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("premium.privacy")
                }
                if let termsURL = subscriptionStore.configuration.termsOfUseURL {
                    Link("premium.termsOfUse", destination: termsURL)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("premium.terms")
                }
            }
        }
    }

    private func offerCard(_ offer: SubscriptionOffer) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            offerHeader(offer)

            Text(verbatim: offer.description)
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await subscriptionStore.purchase(offerID: offer.id) }
            } label: {
                HStack(spacing: 10) {
                    if subscriptionStore.busyOfferID == offer.id {
                        ProgressView()
                            .tint(.white)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: "apple.logo")
                            .accessibilityHidden(true)
                    }
                    Text("premium.subscribePrice \(offer.displayPrice)")
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.forward")
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 14)
                .background(AppTheme.ink)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(subscriptionStore.isBusy)
            .accessibilityHint(Text("premium.purchaseHint"))
            .accessibilityIdentifier("premium.offer.\(offer.id)")
        }
        .sportsCard()
    }

    @ViewBuilder
    private func offerHeader(_ offer: SubscriptionOffer) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                offerName(offer)
                offerPeriod(offer)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                offerName(offer)
                Spacer(minLength: 0)
                offerPeriod(offer)
            }
        }
    }

    private func offerName(_ offer: SubscriptionOffer) -> some View {
        Text(verbatim: offer.displayName)
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func offerPeriod(_ offer: SubscriptionOffer) -> some View {
        Text(periodLabel(offer.period))
            .font(.caption.weight(.bold))
            .foregroundStyle(AppTheme.warm)
    }

    private func benefitRow(
        icon: String,
        title: LocalizedStringKey,
        body: LocalizedStringKey
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                Text(body)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func configurationBoundary(
        title: LocalizedStringKey,
        body: LocalizedStringKey
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "lock.trianglebadge.exclamationmark.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.warm)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sportsCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("premium.configurationBoundary")
    }

    private var ownershipTitleKey: LocalizedStringKey {
        if subscriptionStore.configuration.canQueryEntitlements,
           !subscriptionStore.hasCheckedEntitlement {
            return "premium.checkingTitle"
        }
        return subscriptionStore.isPremiumActive
            ? "premium.activeTitle"
            : "premium.freeTitle"
    }

    private var ownershipBodyKey: LocalizedStringKey {
        if subscriptionStore.configuration.canQueryEntitlements,
           !subscriptionStore.hasCheckedEntitlement {
            return "premium.checkingBody"
        }
        return subscriptionStore.isPremiumActive
            ? "premium.activeBody"
            : "premium.freeBody"
    }

    private var ownershipSystemImage: String {
        if subscriptionStore.configuration.canQueryEntitlements,
           !subscriptionStore.hasCheckedEntitlement {
            return "hourglass"
        }
        return subscriptionStore.isPremiumActive
            ? "checkmark.seal.fill"
            : "person.crop.circle"
    }

    private var ownershipColor: Color {
        subscriptionStore.isPremiumActive ? AppTheme.accent : AppTheme.ink
    }

    private var advertisingStateKey: LocalizedStringKey {
        if !subscriptionStore.configuration.advertisingEnabled {
            return "premium.adsDisabledBuild"
        }
        if subscriptionStore.configuration.state != .ready {
            return "premium.adsConfigurationLocked"
        }
        if !subscriptionStore.hasCheckedEntitlement {
            return "premium.adsChecking"
        }
        if subscriptionStore.hasVerificationFailure {
            return "premium.adsVerificationHeld"
        }
        return subscriptionStore.shouldShowAdvertising
            ? "premium.adsEligible"
            : "premium.adsSuppressed"
    }

    private var advertisingSystemImage: String {
        if subscriptionStore.configuration.advertisingEnabled,
           subscriptionStore.configuration.state != .ready {
            return "lock.fill"
        }
        if subscriptionStore.configuration.advertisingEnabled,
           !subscriptionStore.hasCheckedEntitlement {
            return "hourglass"
        }
        if subscriptionStore.configuration.advertisingEnabled,
           subscriptionStore.hasVerificationFailure {
            return "shield.slash.fill"
        }
        return subscriptionStore.shouldShowAdvertising
            ? "rectangle.badge.person.crop"
            : "rectangle.slash.fill"
    }

    private func periodLabel(_ period: SubscriptionPeriod) -> LocalizedStringKey {
        switch period.unit {
        case .day: "premium.period.day \(period.value)"
        case .week: "premium.period.week \(period.value)"
        case .month: "premium.period.month \(period.value)"
        case .year: "premium.period.year \(period.value)"
        }
    }

    private func manageSubscriptions() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            subscriptionStore.reportManagementUnavailable()
            return
        }
        Task { await subscriptionStore.manageSubscriptions(in: scene) }
    }

    private func moveFocus(toError: Bool) {
        actionFocused = false
        errorFocused = false
        Task { @MainActor in
            await Task.yield()
            if toError {
                errorFocused = true
            } else {
                actionFocused = true
            }
        }
    }
}
