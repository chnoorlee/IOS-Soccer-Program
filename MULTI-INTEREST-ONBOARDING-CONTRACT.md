# Multi-Interest Onboarding Contract

Status: frozen for the current native iOS slice.

This slice extends first launch from team-only selection to the three interest
types supported by the follow contract: teams, players and competitions. The
GOAT App Store evidence explicitly presents a grouped club, league and player
selection step with a visible skip action. SportsHub keeps that product shape
without copying protected branding, artwork or content.

## 1. Product boundary and pre-mortem

- Slice risk: medium. The product value is supported by the reference layout
  and the existing follow model, but asking for too much input before the first
  feed can increase abandonment.
- Main assumption: users will select at least one recognizable interest when
  the choice is short, grouped and reversible.
- Smallest proving journey: launch in English, select one player and one
  competition, continue, and find both in Following; separately launch again,
  skip with no interests, and reach the app without fabricated personalization.
- The onboarding is not a recommendation engine. Catalog order comes from the
  provider and the client does not infer article relevance or claim that a feed
  is personalized merely because a follow exists.
- Delayed deliberately: popularity ranking, search within large onboarding
  catalogs, social-import suggestions and server experiments. Those require
  product analytics and a real content/entity relationship model.

## 2. Completion, skip and later editing

- `Continue` completes onboarding only when at least one team, player or
  competition is followed and no follow mutation is in flight.
- `Skip for now` is an explicit, always-visible action. It may complete with no
  follows and must not create, delete or silently seed an interest.
- Choosing an item performs the same authoritative follow mutation used by its
  detail page. A failed mutation rolls back through `AppModel`; onboarding does
  not maintain a second selection source of truth.
- Profile exposes `Edit interests`. It reopens the same onboarding surface and
  preserves current follows. Finishing or skipping the edit returns to the app;
  neither action clears existing interests.
- Language choice remains immediately reversible and persists independently of
  onboarding completion.

## 3. Catalog and loading contract

- The client loads teams, players and competitions as three public catalog
  resources. `GET /players?limit=100` uses the existing bounded player-page DTO;
  it has the same public cache and controlled demo-fallback policy as teams and
  competitions.
- Catalog sections have independent loading, success and failure states. One
  failed resource never hides already loaded sections or blocks `Skip for now`.
- Each failed section exposes a named retry that reloads only that resource.
- Empty success is distinct from failure and is explained honestly. The client
  does not synthesize licensed clubs, players or competitions.
- Existing follows synchronize before catalog selection state is interpreted.
  A catalog item is selected only from `AppModel`'s compound follow collection.

## 4. Layout and interaction

- The page keeps a compact hero and language choice, followed by clearly headed
  team, player and competition sections in that semantic order.
- At normal Dynamic Type sizes, interests use a compact three-column grid with
  a circular identity mark and a text label. Accessibility sizes switch to one
  column so names and state never depend on truncation.
- Team marks use `TeamBadge`; player and competition marks use distinct system
  symbols. Selection is communicated by text/VoiceOver state, a checkmark and
  an outline, never by color alone.
- Every item and footer action has a minimum 44-by-44-point activation area.
  A busy item remains identifiable and exposes an updating state.

## 5. Accessibility, RTL and localization

- Section headings are programmatic headers. Each interest button announces
  its display name, entity type and selected/not-selected state.
- Arabic uses the app-wide RTL environment; English remains complete. Layout
  uses logical leading/trailing alignment and no directional hard-coding.
- Loading, empty and error text exists in both locales. Error retries are native
  buttons and failed sections receive VoiceOver focus after the state change.
- Language controls reflow vertically at accessibility Dynamic Type sizes.

## 6. Acceptance evidence

- AppModel tests cover team-only, player-only and competition-only completion,
  no-selection refusal, explicit skip and edit-state preservation.
- Mock and Remote provider tests cover the player catalog, bounded query,
  decoding, cache behavior and malformed response rejection.
- UI test source covers a player-plus-competition first launch and a zero-follow
  skip journey, while existing team-first journeys remain compatible.
- Static verification checks all three visible section identifiers, per-type
  controls, skip/edit entry points, localization parity and API schema wiring.
- macOS/Xcode remains required to execute XCTest and verify rendered Arabic RTL,
  Dynamic Type, VoiceOver focus and the generated Xcode project.
