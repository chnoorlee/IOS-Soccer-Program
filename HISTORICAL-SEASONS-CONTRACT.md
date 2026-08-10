# Historical seasons contract

Status: implementation contract for the evidence-backed Jdwal capability “History seasons & data”.

## Product boundary

SportsHub may display only seasons explicitly published by its configured sports-data Provider. The client does not infer missing seasons, claim that the archive is complete, or merge statistics between seasons. Mock mode remains visibly fictional demo data.

The first slice covers:

- a competition-level season archive, ordered newest to oldest;
- a clear current/archive state for the selected season;
- season-scoped standings, leaders, and fixtures;
- safe empty states when a Provider publishes a season but has no data for a section.

Season comparison, all-time records, real historical backfill, and completeness guarantees remain outside this slice until the Provider contract and coverage SLA are known.

## Provider contract

For every `CompetitionSummary`:

1. `seasons` contains at most 50 entries and IDs are unique.
2. Every season has a non-empty stable ID and localized name.
3. `startDate` is strictly earlier than `endDate`.
4. Entries are sorted by `startDate` descending. Equal dates use ID ascending as a stable tie-break.
5. At most one entry has `isCurrent = true`.
6. When `currentSeasonId` is present, it resolves to the one entry marked current. When it is absent, no entry may be marked current.
7. The selected season ID is sent unchanged to standings, leaders, and fixture endpoints.
8. Competition fixture responses echo both competition and season scope; the client rejects mismatches, duplicates, and cross-page ordering failures before presenting them.

Invalid catalogs fail closed as contract violations and are not silently reordered, deduplicated, or guessed by the client.

## Presentation contract

- The competition page initially selects the Provider-declared current season, or the newest archived season when no current season exists.
- The archive selector exposes the season name, its date range, and a textual current/archive status. Status never relies on color alone.
- Changing seasons clears the previous standings, leaders, and fixtures before starting the new request.
- Request identity includes the section, season ID, and leader category, so a late response cannot overwrite a newer selection.
- The selector preserves a minimum 44-point target and changes to a vertical layout at accessibility Dynamic Type sizes.

## Acceptance evidence

- DTO tests reject duplicate, unbounded, unordered, invalid-date, and inconsistent-current catalogs.
- Mock Provider tests prove that current and archived requests return distinct standings, leaders, and fixtures.
- Archived fixtures are finished, fall within the selected season, and remain addressable by Match Center.
- A UI journey selects the archived season, sees its results section, and opens the archived match.
- macOS/Xcode type checking, XCTest, simulator RTL/LTR, Dynamic Type, and VoiceOver checks remain required release gates.
