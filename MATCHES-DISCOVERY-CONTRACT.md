# Matches discovery contract

Date: 2026-08-07

## Evidence and scope

The current GOAT App Store screenshots show a five-day date rail, a live control,
and fixtures grouped by competition. Jdwal's supplied screenshot also supports a
date-based, competition-grouped match list. This slice implements those general
information-architecture patterns with SportsHub's own visual system and data.

The provider already returns fixtures for one selected local date. The client
must not invent popularity, featured competitions, rounds, related stories, or
competition logos when those fields are absent from the payload.

## Filter order

1. The selected date determines the provider request.
2. The status filter is applied to that date's payload. `live` includes both
   `.live` and `.halfTime`; `all` preserves every state.
3. An optional competition ID further filters the status result.
4. Remaining fixtures are grouped by competition ID.

Changing one filter must not silently change either of the other filters.

## Competition identity and ordering

- Available competitions come from the full payload for the selected date, not
  from the status-filtered subset. This keeps the competition rail stable when
  switching between All and Live.
- A competition appears once, in the order of its first fixture in the payload.
- The first payload snapshot for an ID supplies the group label.
- Groups use that same first-appearance order.
- Fixtures retain provider order inside each group.
- A selected competition remains selected even when it has no fixture in the
  current status. The UI shows a contextual empty result instead of changing the
  user's filter.
- When a refreshed date payload no longer contains the selected competition ID,
  the selection normalizes to All competitions before the payload is committed.

## Empty semantics

The presentation distinguishes three reachable empty outcomes:

- no fixtures for the selected date;
- no live fixtures for the selected date;
- no live fixtures for the selected competition on the selected date.

There is deliberately no separate "no fixtures for this competition" state in
All mode: a competition option only exists when at least one fixture for it is
present in that date payload. An unavailable persisted selection normalizes to
All competitions.

## Layout and accessibility

- The date rail exposes five dates: two days before through two days after today.
- Relative labels are used for yesterday, today, and tomorrow; every option also
  exposes its concrete date.
- Status and competition controls are native buttons with a visible checkmark,
  selected accessibility trait, localized hint, and at least a 44-point target.
- At accessibility Dynamic Type sizes, horizontal control rails reflow vertically.
- Competition and fixture order follows logical leading order, so SwiftUI mirrors
  it for Arabic RTL without manually reversing data.
- Every competition group and fixture link has a stable accessibility identifier.

## Acceptance checks

- Pure tests prove stable competition discovery, combined filtering, grouping,
  provider-order preservation, invalid-selection normalization, disjoint output,
  and all three reachable empty reasons.
- A UI journey proves the five-day rail, competition groups, competition
  selection, Live filtering, contextual empty state, and original fixture IDs.
- Windows static verification checks the contract, model, tests, localization,
  and UI markers. Xcode compilation, XCTest, VoiceOver, RTL rendering, and
  simulator behavior remain macOS verification gates.
