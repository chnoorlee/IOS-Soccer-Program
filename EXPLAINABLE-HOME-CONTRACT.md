# Explainable Home Aggregation Contract

Status: frozen for the current native iOS slice.

This slice turns explicit follows into useful Home entry points and a limited,
auditable fixture partition. The reference screenshots support an interest rail,
important matches and news cards. SportsHub keeps that product shape without
copying protected branding, artwork, editorial content or visual identity.

## 1. Product boundary and pre-mortem

- Slice risk: low to medium. Explicit shortcuts and fixture relationships are
  supported by the reference layout and existing models, but an unexplained
  "For you" label would overstate the available data.
- Main assumption: users get immediate value when every followed entity is
  reachable from Home and directly related fixtures are separated from public
  important matches.
- Smallest proving journey: follow one player and one competition; Home shows
  both shortcuts, labels competition fixtures with their relationship, and
  still calls the public article list "Latest news". A player-only follow must
  not create an inferred related fixture.
- Delayed deliberately: article personalization, player-to-fixture inference,
  popularity ranking, analytics-driven ordering and recommendation models.
  Those require provider-owned relationship metadata and product evidence.

## 2. Interest shortcuts

- Home renders `AppModel.orderedFollows` in canonical order. It does not derive
  followed entities from the current fixture payload, so a real follow cannot
  disappear merely because there is no current match.
- Until follows are synchronized for the current guest or account identity,
  Home hides interest snapshots and related-match claims behind a named loading
  state. Public important matches may remain visible during that synchronization.
- A valid entity snapshot opens its native team, player or competition detail.
  A legacy follow without a snapshot remains visible as unavailable and is not
  given a fabricated name or destination.
- `Edit interests` reopens the existing onboarding editor and preserves all
  current follows. It never silently follows or unfollows an entity.
- With zero follows, Home explains the empty state and offers the same explicit
  edit entry point.

## 3. Explainable fixture partition

- Provider fixture order is preserved.
- A fixture belongs to `From your follows` only when at least one explicit,
  locally provable relationship exists:
  - its home or away team ID is in the followed team IDs; or
  - its competition ID is in the followed competition IDs.
- Each related fixture states one of three reasons: followed team, followed
  competition, or both. The reason never relies on color alone.
- Player follows do not imply a fixture relationship because `Fixture` contains
  no player roster relationship.
- All non-related fixtures form the disjoint public `Important today` section.
  If no follows exist, every fixture remains in this public section. If follows
  exist but none match, Home shows an honest no-related-matches message before
  the unchanged public section.
- No fixture may be duplicated or omitted by the partition.

## 4. News semantics and ordering

- `HomeFeed.articles` remains provider-ordered public editorial content and is
  titled `Latest news`.
- Home must not use `For you`, `Recommended` or equivalent wording until the
  provider supplies an auditable article-to-entity relationship.
- Home section order is freshness, interests, related matches when follows
  exist, remaining public important matches, then latest news.

## 5. Accessibility, Dynamic Type and RTL

- Every actionable interest and fixture uses a native `NavigationLink` or
  `Button` with a minimum 44-by-44-point target and a named VoiceOver hint.
- Entity type, unavailable state and fixture relationship are available as
  text/semantics and never communicated by icon or color alone.
- Horizontal interest and fixture rails switch to vertical alternatives at
  accessibility Dynamic Type sizes; content is not hidden behind truncation.
- Arabic uses the app-wide RTL environment. Layout uses logical leading and
  trailing alignment, and every new user-facing string exists in both locales.

## 6. Acceptance evidence

- Pure unit tests prove team/competition reasons, player non-inference, stable
  ordering and a complete disjoint partition.
- UI test source covers player-plus-competition shortcuts and a relationship
  reason, plus the zero-follow public fallback and honest latest-news heading.
- Static verification requires the contract, aggregation source, tests, Home
  identifiers, localization parity and removal of the misleading `home.forYou`
  source reference.
- macOS/Xcode remains required to execute XCTest and verify rendered Arabic RTL,
  Dynamic Type, VoiceOver reading order and navigation on a real iOS runtime.
