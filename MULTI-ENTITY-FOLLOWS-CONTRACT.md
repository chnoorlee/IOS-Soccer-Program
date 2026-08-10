# Multi-Entity Follows Contract

Status: frozen for the current native iOS slice.

This slice makes the already-declared `TEAM`, `PLAYER` and `COMPETITION`
follow types visible and manageable throughout the client. It extends the
existing Following hub; it does not infer content relationships, request
notification permission automatically or claim per-entity notification rules
that the current API cannot store.

## 1. Product boundary and pre-mortem

- Slice risk: medium. The public API already models all three types, but the
  current client discards non-team follows and its optimistic mutation key is
  only a raw team ID.
- Main product assumption: a user who follows a team, player or competition
  expects that object to remain visible and removable in Following. Public
  GOAT evidence and this project's frozen PRD both name those three object
  types; no evidence yet supports automatic content recommendations.
- Likeliest failure: a late response from a previous signed-in identity, or two
  object types sharing the same raw ID, corrupts the active identity's state.
- Smallest proving journey: follow one team, one player and one competition;
  verify all three appear newest-first; remove one; then change identity while
  a synchronization is suspended and verify the old response cannot reappear.
- Delayed deliberately: per-object notification matrices and feed ranking.
  They require a server-side rule model and content-to-entity relationships.

## 2. Identity and ordering

- A follow target is the compound key `(type, entityId)`. Identical raw IDs in
  different types are independent targets.
- Signed-out or unavailable-account use is routed to the device guest store. A
  valid account session uses authenticated `/me` resources. An expired or
  unreadable account session fails closed.
- Synchronization replaces the complete in-memory follow collection only after
  the response passes identity and contract checks. A response started for an
  older identity is ignored and followed by synchronization for the current
  identity.
- The canonical order is `createdAt` descending. Equal timestamps use follow
  type raw value ascending, then `entityId` ascending. The same order is used
  by the provider, AppModel and Following UI.
- One mutation may be in flight per compound target. Different targets may be
  changed independently. A failed mutation restores the exact prior record,
  including its timestamp and presentation snapshot.
- Account follow reads and writes are authorized with a token resolved for the
  expected account ID. A missing or mismatched scoped token fails before the
  HTTP request. A response is committed only while both its identity and its
  mutation operation ID are still current, including sign-out/sign-in races.

## 3. Presentation snapshot

- Every new follow records a typed snapshot containing exactly one `Team`,
  `PlayerProfile` or `Competition`. Its type and entity ID must match the
  enclosing follow.
- Authenticated list/create responses include a typed `entity` snapshot. The
  server remains authoritative; client-supplied display metadata is never sent
  in the create request.
- Guest storage persists the snapshot so Following remains usable offline.
  Repeating a follow is idempotent: it may refresh the snapshot but preserves
  the original `createdAt`.
- Existing guest records without a snapshot remain valid. Known legacy team
  records are enriched from one team-catalog load when available. If metadata
  is still missing or withdrawn, Following shows an unavailable typed row with
  the stable ID and an unfollow control; it never silently hides the follow.
- A mismatched type, ID, duplicate compound target, duplicate follow ID, more
  than 500 records, or timestamp over five minutes in the future is a contract
  violation. No partial response is applied.

## 4. Visible behavior

- Team, player and competition detail headers expose the same follow/following
  control and per-target progress state.
- Following contains one mixed "followed interests" section ordered by the
  canonical follow order. Each resolved card navigates to its matching detail
  screen and exposes a separate unfollow button.
- Saved articles and saved videos remain independent sections. A failure in
  either must not hide follows, and a follow synchronization failure must not
  erase the last valid in-memory follow collection.
- The combined empty state is shown only after article and video sections load
  successfully and the canonical follow collection is empty.

## 5. Notification semantics

- Follows define the entities that may form a notification audience.
  Notification preferences define globally enabled event categories.
- Following an entity does not request system notification permission, register
  APNs, or enable a disabled preference.
- Removing a follow removes that entity from the audience but does not alter
  global notification preferences.
- The client must not present per-entity notification switches until an
  authenticated API can persist and return those rules.

## 6. Accessibility and localization

- Controls have at least a 44-by-44-point activation area and never rely on
  color or icon shape alone.
- VoiceOver labels identify the action and object type; mutation progress is
  exposed as disabled/busy state, and navigation links include destination
  hints.
- Cards support Dynamic Type without forcing a horizontal text layout at
  accessibility sizes. Arabic is RTL-first; English remains complete.
- Unavailable rows announce both the object type and stable ID so the user can
  make an informed removal decision.

## 7. Acceptance evidence

- Store tests cover schema migration, typed snapshot persistence, idempotent
  refresh/removal, offline reopening and legacy records without snapshots.
- Mock and remote provider tests cover all three types, exact snapshot matching,
  request privacy, create-body minimization and malformed-response rejection.
- AppModel tests cover compound-key independence, canonical ordering, exact
  rollback, guest clearing and late previous-identity responses.
- Static verification checks all three visible detail controls, mixed Following
  cards, bilingual keys, the API schema and accessibility identifiers.
- macOS/Xcode remains required to execute XCTest and verify the rendered RTL,
  Dynamic Type and VoiceOver journeys on a simulator or device.
