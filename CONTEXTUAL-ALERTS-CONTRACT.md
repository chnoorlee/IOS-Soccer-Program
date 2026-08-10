# Contextual alert entry contract

Date: 2026-08-07

## Evidence, pre-mortem and boundary

The supplied Jdwal material visibly supports favorite teams and a bell beside a
competition favorite control. The frozen SportsHub PRD also requires reminder
entry points from match context. Neither source proves a separately persisted
favorite for one fixture, and the current API stores only followed entities plus
globally enabled notification event categories.

- Risk verdict: medium. A contextual bell could falsely imply a per-object
  notification switch that the server cannot persist.
- Main assumption: users can understand the existing two-part rule when it is
  explained at the point of use: follows determine the eligible audience, while
  event-category choices apply globally.
- Smallest proving journey: open a followed team and a related match, see why
  each is eligible, then reach the same account/permission/global preferences
  card without granting permission automatically.
- Delayed deliberately: fixture favorites, per-fixture reminders, per-entity
  event matrices, local scheduled alerts, and any promise of notification
  delivery before an authenticated push backend is operating.

## Audience semantics

- An entity detail is eligible only when its exact compound `(type, entityId)`
  exists in the current identity's canonical follows. Equal raw IDs in different
  entity types never match.
- A fixture is eligible only when the shared `FixtureFollowMatcher` proves that
  its home team, away team, competition, or a team plus competition is followed.
  Player follows never imply fixture eligibility.
- Eligible fixture context states its exact team / competition / both reason.
- An ineligible entity offers one explicit follow action. An ineligible fixture
  offers the home team, away team, and competition as three explicit choices.
  Choosing one uses the existing follow mutation and does not enable alerts,
  request permission, or mutate notification categories.
- An optimistic pending follow shows a named audience-confirmation state and
  cannot expose notification controls or claim eligibility. Successful follow
  mutation recomputes eligibility from `AppModel.orderedFollows`; failed
  mutation keeps the context ineligible and uses the existing follow
  rollback/error behavior.

## Notification, permission and identity semantics

- The contextual sheet reuses the existing `NotificationSettingsCard`; there is
  one notification preferences model and no shadow local settings store.
- Notification event choices remain global across every followed team, player,
  and competition. The sheet says this directly and never labels a toggle as
  belonging to the displayed entity or fixture.
- Opening the sheet never requests iOS notification permission. Permission is
  requested only through the existing explicit `Enable alerts` action.
- Guest mode keeps its existing honest account-required boundary. Source code,
  Mock data, or a visible bell must not claim that real remote alerts are active.
- Settings refresh is identity-scoped by `NotificationSettingsModel`; follow
  eligibility is read from the current `AppModel` identity. Authentication
  changes must clear prior settings through those existing guarded models.
- Synchronization, permission, registration, and preference failures retain the
  existing named errors, retry/dismiss actions, rollback, and no-token-saved
  boundary.

## Entry points and layout

- Team, player, and competition detail headers expose a full-width native
  `Alert settings` button beside the existing follow control.
- Match center exposes a native toolbar bell after the authoritative fixture is
  loaded. Match-list cards remain one unambiguous navigation target; no nested
  button is inserted into a fixture link.
- Every entry opens the same native sheet with the contextual title, entity type
  or fixture teams, eligibility explanation, global-scope explanation, and then
  either follow choices or the shared settings card.
- Closing the sheet uses a localized native toolbar button. The underlying
  detail navigation and filters are unchanged.

## Accessibility, Dynamic Type and RTL

- All bell and follow actions have localized labels/hints, stable identifiers,
  native roles, disabled/busy semantics from existing controls, and at least a
  44-by-44-point target.
- Eligibility and global scope use text plus icons and never color/icon alone.
  State changes remain visible through normal SwiftUI re-rendering; mutation and
  notification errors keep their existing VoiceOver focus behavior.
- Follow choices are vertical, so long Arabic labels and accessibility Dynamic
  Type do not compete horizontally. Logical leading/trailing layout mirrors for
  RTL without reversing entity data.
- The sheet title and content order are context, eligibility, global rule,
  explicit action, then settings; VoiceOver receives the same logical order.

## Acceptance evidence

- Pure tests cover exact compound entity identity, every entity type, fixture
  team/competition/both reasons, player-only non-inference, and ineligible input.
- Source checks require all four entry points, shared settings reuse, explicit
  global-scope copy, three fixture follow choices, and no automatic permission
  request from the contextual component.
- A UI journey proves a followed onboarding team is eligible, opens the shared
  sheet, exposes the guest account boundary, and opens a related match from the
  same identity with an explainable alert reason.
- Windows checks verify contract/source/test markers, localization parity, Swift
  AST, project structure, and OpenAPI integrity. Swift type checking, XCTest,
  sheet presentation, identity races, iOS permission UI, APNs delivery, Arabic
  RTL, Dynamic Type, and VoiceOver remain explicit macOS/device gates.
