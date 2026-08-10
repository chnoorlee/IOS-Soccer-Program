# Matches arbitrary-date and search contract

Date: 2026-08-07

## Evidence and boundary

The current official GOAT matches screenshot exposes search, calendar, and live
controls above a five-day rail. SportsHub already implements the five-day rail,
live filtering, competition filtering, and competition groups. This slice adds
the two remaining explicit entry points without claiming undocumented server
ranking or cross-season full-text search.

## Date semantics

- A fixture request is keyed by one local calendar day in the user's current
  time zone, matching the existing provider and cache contract.
- Dates are normalized with `Calendar.startOfDay(for:)`; adding rail days uses
  calendar arithmetic rather than fixed 86,400-second intervals so DST does not
  skip or duplicate a local day.
- The rail always exposes five consecutive days at offsets `-2 ... 2` from its
  center.
- Choosing a day in the rail changes only the selected day and keeps the rail
  center. Choosing an arbitrary date in the calendar changes the selected day
  and recenters the rail on it.
- Yesterday, Today, and Tomorrow labels are based on the actual current local
  day, not on the selected rail offset.
- Date changes preserve the status filter. Competition selection is preserved
  only when that competition exists in the new payload, using the existing
  normalization rule.
- No artificial minimum or maximum calendar date is invented. A valid date with
  no provider fixtures uses the existing date empty state.

## Search semantics

- Search candidates are the fixtures currently visible after the selected date,
  status, and competition filters are applied.
- Search is local to the already-loaded candidate fixtures and must not trigger
  one request per fixture or call the global news/entity search endpoint.
- Empty input shows an instruction. One normalized character shows the minimum
  length message. Two or more normalized characters perform search.
- Matching is case- and diacritic-insensitive substring matching over both team
  names, both team monograms, both competition names, and both venue names.
  Arabic tatweel, common alef variants, and alef maqsura are normalized.
- A fixture appears at most once even when multiple fields match. Results keep
  candidate order and preserve the original fixture ID.
- Selecting a result opens the existing match center; search does not create a
  second fixture-detail model.

## Accessibility and layout

- Search and calendar are native toolbar buttons with localized labels, hints,
  and stable identifiers.
- The calendar uses a native graphical `DatePicker`, plus native Cancel, Today,
  and Apply actions. The selected date is not communicated by color alone.
- Search uses a labeled native text field, a 44-point clear action, explicit
  prompt/short-query/empty/results states, and native fixture links.
- Dynamic Type, VoiceOver order, and Arabic RTL use SwiftUI logical layout;
  fixture cards retain their existing accessibility-size vertical reflow.

## Acceptance evidence

- Pure tests cover five local days across DST, rail selection, arbitrary-date
  recentering, real-today relative labels, all search states, English and Arabic
  normalization, every supported match field, stable ordering, and uniqueness.
- A UI journey opens the calendar, applies Today, opens search, finds an original
  fixture ID, and reaches the no-result state.
- Windows checks verify source structure, localization parity, Swift AST, and
  project/OpenAPI integrity. Xcode type checking, XCTest, graphical DatePicker
  interaction, simulator RTL/Dynamic Type, and VoiceOver remain macOS gates.
