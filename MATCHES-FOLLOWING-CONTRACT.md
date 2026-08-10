# Followed matches contract

Date: 2026-08-07

## Evidence and product boundary

The supplied Jdwal screenshot exposes an `All / Fav / Top` match scope. The
existing SportsHub follow model can prove team and competition relationships,
so this slice implements `All / Following` with the app's own labels and visual
system. It deliberately omits `Top`: neither the reference evidence nor the
provider contract defines a popularity score, editorial rank, or deterministic
ordering rule that the client could reproduce honestly.

## Relationship identity

- A fixture is followed only when its home-team ID or away-team ID is explicitly
  followed, or its competition ID is explicitly followed.
- The reason is exactly one of followed team, followed competition, or both.
- Player follows never imply a fixture relationship because `Fixture` has no
  roster or player-participation field.
- The same shared matcher supplies Home and Matches so the two surfaces cannot
  silently disagree about why a fixture is related.
- Matching uses stable provider IDs only. Entity snapshots and localized names
  are display data and never participate in identity comparison.

## Identity synchronization

- Matches does not expose follow-derived results until follows have synchronized
  for the current guest or signed-in identity.
- On authentication-state change, an in-flight follow request is invalidated,
  follow readiness is cleared immediately, and the scope returns to `All` before
  the replacement identity is synchronized. Old-account follows must never be
  shown for the new identity, even transiently.
- A regular follow mutation updates the current `Following` result without
  resetting the user's date, status, scope, or competition selection.
- A failed synchronization never fabricates a relationship or presents an empty
  response as proof that the identity follows nothing. `All` remains a public
  fixture view; `Following` stays disabled behind a named error and retry until
  the current identity completes a guarded successful synchronization.

## Filter and ordering semantics

1. The selected local date determines the provider request.
2. `All / Live` filters that date payload by fixture state.
3. `All / Following` either preserves the status result or retains only fixtures
   with a provable shared follow reason.
4. The optional competition ID filters that result.
5. Remaining fixtures are grouped by competition.
6. Search consumes only those currently visible fixtures.

Filtering preserves relative provider order. Group order follows each
competition's first payload appearance, and fixtures preserve provider order
inside their group, matching the existing discovery contract. Competition
options still come from the full selected-date payload, so status and scope
changes do not reorder or shrink the rail. A valid selected competition remains
selected even when the current status/scope combination is empty. Scope changes
never alter the selected date, status, or competition.

## Empty and explanation semantics

- Existing public date, live, and live-in-competition empty states remain
  unchanged in `All`.
- If `Following` is selected but the current identity follows no team or
  competition, the UI explains that player follows do not populate matches and
  invites the user to follow a team or competition elsewhere in the app.
- If matchable interests exist but no fixture survives the current date/status
  filters, the UI reports no followed matches for the active filters.
- If a competition is selected, that message explicitly names the competition
  context without inventing an unavailable fixture.
- Every visible fixture in `Following` states its relationship reason in text
  and VoiceOver semantics. The explanation is also retained in scoped search
  results and never relies on icon or color alone.

## Accessibility, Dynamic Type, RTL and interaction

- Scope choices are native buttons in fixed `All`, then `Following` logical
  order, with visible selection, selected traits, localized labels/hints, stable
  identifiers, and a minimum 44-point target.
- The control reflows vertically at accessibility Dynamic Type sizes. Arabic
  relies on SwiftUI's logical leading/trailing mirroring; fixture data is never
  manually reversed.
- While the current identity's follows are synchronizing, `All` remains usable,
  `Following` is disabled, and its localized hint explains why.
- A synchronization error receives VoiceOver focus, keeps `All` usable, and
  exposes a localized native retry action with a 44-point target.
- Reason labels are readable text, expose stable identifiers, and are grouped
  with their fixture links in a predictable VoiceOver order.

## Acceptance evidence

- Pure tests cover team, competition, both, and player-only relationships;
  stable ordering; status/scope/competition composition; stable competition
  options; public compatibility; and every followed empty reason.
- Source-level identity tests require immediate stale-follow invalidation and a
  request-ID guard before readiness is restored.
- A UI journey follows the onboarding team, opens Matches, selects `Following`,
  sees only related original fixture IDs with a textual reason, then composes it
  with `Live`.
- Windows checks verify contract/source/test markers, localization parity, Swift
  AST, project structure, and OpenAPI references. Xcode compilation, XCTest,
  simulator identity transitions, VoiceOver, Dynamic Type, and Arabic RTL remain
  explicit macOS gates.
