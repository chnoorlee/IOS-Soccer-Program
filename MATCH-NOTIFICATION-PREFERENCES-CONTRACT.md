# Match notification preferences contract

> Frozen: 2026-08-08  
> Scope: account-wide event choices exposed by the existing notification settings card

## Evidence and product boundary

- Koora Break's current Saudi App Store description explicitly advertises
  immediate lineup, goal, red/yellow-card, substitution and result alerts.
- GOAT's current App Store description separately supports favorite-team,
  breaking-news, result and match notifications.
- The supplied GOAT screenshot shows notification-led match discovery, while the
  repository's authoritative fixture timeline already distinguishes
  `yellowCard`, `redCard` and `substitution` events.
- These public facts support a granular alert-selection task. They do not expose
  either reference product's private delivery rules, provider mapping, APNs
  credentials, deduplication algorithm or latency guarantees.

SportsHub therefore presents an original, native list of nine global choices:
breaking news, lineup, kickoff, goal, yellow card, red card, substitution,
half-time and full-time. The UI does not copy reference branding or layout.

## Preference and migration semantics

- `NotificationPreferenceType.allCases` is the canonical UI order and contains
  exactly the nine choices above.
- Each toggle changes exactly one field. The authenticated server response is
  authoritative after a mutation; a mismatch is a contract violation and the
  existing optimistic rollback path remains active.
- The old API field `card` remains a deprecated compatibility aggregate. On a
  new response it is `true` only when both `yellowCard` and `redCard` are true.
  A legacy PATCH of `card` sets both granular card fields to the supplied value.
- A new client accepts a rolling-deployment response that omits granular fields.
  Missing `yellowCard` and `redCard` inherit the legacy `card` value. Missing
  `substitution` is always `false`; migration must not silently broaden consent.
- When granular card fields are present they override `card`, even when the
  legacy aggregate disagrees.
- New-client PATCH requests send exactly one granular field and never send the
  deprecated aggregate.

## Audience, permission and delivery boundary

- Choices are account-wide event categories. They apply only after the existing
  exact team/competition follow matcher makes a fixture eligible; player follows
  do not imply match eligibility.
- Opening settings or following an entity never requests iOS permission. Only
  the explicit Enable alerts action may request it.
- Preferences and device bindings remain authenticated, private, `no-store`
  resources. APNs tokens are not returned, logged or treated as user identity.
- The source model does not claim a notification was delivered. Production
  delivery still requires licensed event ingestion, stable provider event IDs,
  revision-aware correction handling, per-account deduplication and rate limits,
  APNs credentials, observability and device tests.
- A suggested server deduplication identity is account + fixture + canonical
  event ID + revision + notification category. This is an integration
  requirement, not a currently validated backend implementation.

## Accessibility, RTL and layout

- The shared card keeps a single vertical native `Toggle` per category with a
  localized Arabic/English label, a stable identifier and a minimum 44-point row.
- Native toggle state supplies the accessibility value; category meaning is not
  conveyed by color or icon alone.
- The vertical order survives Arabic RTL, long labels and accessibility Dynamic
  Type without placing competing controls on one row.
- Loading, permission-denied, account-required, registration and synchronization
  failures retain their existing visible text, focus and retry behavior.

## Acceptance evidence

- Pure tests prove the legacy migration, granular-over-legacy precedence, the
  exact nine-category order and one-field-only mutation behavior.
- DTO tests prove a granular PATCH serializes exactly one key.
- Remote-provider tests prove authenticated, `no-store`, idempotent PATCH behavior
  for substitution and authoritative response validation.
- Static verification requires the nine model cases, all six new granular API
  markers, the localized labels and the migration tests.
- Swift compilation, XCTest, simulator rendering, Arabic RTL, Dynamic Type,
  VoiceOver, APNs registration and actual notification receipt remain macOS/
  Xcode/real-device gates.

## Sources

- [Koora Break App Store](https://apps.apple.com/sa/app/id6456176348)
- [Koora Break Apple lookup](https://itunes.apple.com/lookup?id=6456176348&country=sa&entity=software)
- [GOAT App Store](https://apps.apple.com/sa/app/id6748277536)
- [GOAT Apple lookup](https://itunes.apple.com/lookup?id=6748277536&country=sa&entity=software)
