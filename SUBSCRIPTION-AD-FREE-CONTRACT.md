# SportsHub Subscription and Ad-Free Contract

Status: frozen implementation contract for the next native iOS slice (2026-08-07).

## 1. Evidence and scope

- The Saudi App Store description for Jdwal 3.4.7 explicitly offers monthly and annual subscriptions that support the app and remove ads.
- Apple StoreKit documentation defines `Product.purchase`, `Transaction.currentEntitlements`, `AppStore.sync`, and the system subscription-management sheet as the native purchase and ownership sources.
- SportsHub currently contains no advertising SDK or advertising placements. The checked-in product configuration must remain honest about that state.

This slice adds StoreKit 2 subscription ownership, purchase, restore, management, and one central advertising-eligibility gate. It does not add ads, trials, introductory offers, server receipts, family sharing claims, promotional pricing, or paid sports-content access.

## 2. Product promise

The subscription has exactly two client-visible benefits:

1. support the independent product; and
2. suppress SportsHub-controlled advertising placements whenever advertising is separately enabled.

It never grants live-stream, broadcast, article, competition, notification, or account entitlement. Every media item continues through its existing rights-filtered playback session.

The UI must say when the current build has no ads. It must not claim that a purchase removed ads that were never enabled.

## 3. Products and pricing

- Production configuration names one monthly and one annual auto-renewable product ID.
- Both products must be returned by StoreKit, belong to the same subscription group, and have exact one-month and one-year periods respectively.
- Display name, description, localized price, storefront currency, and subscription period come from StoreKit. They are never copied from Jdwal or hard-coded from its public US-dollar examples.
- Missing, duplicate, malformed, wrong-period, wrong-type, or cross-group products disable purchasing and show a recoverable configuration/product state.
- Purchase controls require valid publisher-owned HTTPS privacy-policy and terms-of-use URLs.

## 4. Entitlement rules

Only a locally verified StoreKit transaction for one of the configured product IDs may activate premium.

The entitlement is rejected when:

- StoreKit verification fails;
- the product ID is not configured;
- the transaction is revoked or upgraded;
- its expiration is missing or not later than the evaluation time.

When more than one verified transaction is active, the transaction with the latest expiration wins, with purchase date and product ID as stable tie-breakers. Unverified records never activate premium and produce a visible verification error.

The app reads `Transaction.currentEntitlements` at startup/entry and listens for StoreKit transaction updates. Verified purchases are finished only after their product ID and transaction are accepted.

## 5. Purchase, restore, and management

- A purchase begins only after the user taps the exact StoreKit-loaded offer.
- `pending` remains non-premium and is described as awaiting App Store approval.
- `userCancelled` makes no ownership claim and produces no error.
- Restore is an explicit 44-point action that calls `AppStore.sync`; the app never triggers an App Store sign-in prompt at launch.
- After restore, the app distinguishes restored ownership from “no active purchases found.”
- Active users can open Apple’s system subscription-management sheet. The client never implements cancellation itself.
- Concurrent purchase, restore, manage, and refresh commits are serialized or protected by operation identity.

## 6. Configuration and release gates

Checked-in defaults:

```yaml
SPORTS_PREMIUM_MONTHLY_PRODUCT_ID: ""
SPORTS_PREMIUM_ANNUAL_PRODUCT_ID: ""
SPORTS_PREMIUM_PRIVACY_URL: ""
SPORTS_PREMIUM_TERMS_URL: ""
SPORTS_ADVERTISING_ENABLED: false
```

Purchasing is enabled only when both distinct product IDs and both valid publisher HTTPS legal URLs are present. Advertising eligibility is true only when that full subscription release configuration is ready, the initial entitlement query resolves without a verification failure, advertising is enabled, and no active verified premium entitlement exists.

The Debug-only UI-test preview uses named fictional offers and may never compile into Release behavior as a production substitute.

## 7. Layout and accessibility

- Profile exposes a stable Premium entry regardless of configuration, so unavailable setup is visible rather than silently missing.
- The Arabic-first screen uses an original “season pass” ticket: ownership at the top, StoreKit offers in the middle, restore/manage/legal actions at the bottom.
- All controls have at least a 44-point target and remain vertical at accessibility Dynamic Type sizes.
- Ownership, pending, failure, preview, and no-ads states use text and symbols, never color alone.
- Purchase/restore results move VoiceOver focus to a coherent status message.
- Product display names, descriptions, and prices are treated as storefront-localized content and are never used as localization keys.

## 8. Failure and privacy

- StoreKit failures map to bounded localized states; raw errors, transaction identifiers, receipts, Apple IDs, and storefront account data are never logged or displayed.
- No transaction or receipt is sent to the SportsHub backend in this slice.
- Product loading failure never clears an already verified active entitlement.
- Subscription ownership is independent of SportsHub sign-in and guest personalization.

## 9. Deferred work

- Real App Store Connect subscription group, products, review screenshot, pricing, availability, and sandbox/TestFlight evidence.
- Publisher privacy policy and terms URLs.
- Any advertising SDK, consent flow, App Privacy declarations, child-directed treatment, frequency caps, or ad-server integration.
- Server-side App Store Server API/Notifications V2 reconciliation, refund handling metrics, offer codes, trials, win-back offers, and grace-period messaging.
- Real-device StoreKit sheet, Ask to Buy, billing retry, refund, revocation, upgrade/downgrade, RTL, Dynamic Type, and VoiceOver validation.
