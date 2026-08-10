# Home match filter contract

Date frozen: 2026-08-07

This slice adds one global status filter to the Home match area. It combines the supplied screenshot evidence for a prominent “important matches today” area and live-match access with SportsHub's existing explainable followed/public partition.

It does not copy reference branding, visual assets, or content. It also does not add “Top”, popularity, editorial priority, or importance ranking because the current Home payload has no field that can prove those meanings.

## Before-you-build decision

- Risk: low to medium. Filtering is local and reversible, but applying it independently to followed/public sections could silently corrupt the explanation model.
- Main assumption: a single status choice helps users scan the Home fixture snapshot faster without needing the full date controls in Matches.
- Smallest useful proof: the three-state Mock feed must switch deterministically between live, upcoming, and finished while fixture IDs and follow reasons remain unchanged.
- Do now: one pure presentation model, canonical status semantics, accessible controls, filter-specific followed empty copy, tests, and identity/refresh regression.
- Delay: Home date, competition, broadcast, provider importance, and “Top” filters. Date and live browsing already remain available in the dedicated Matches screen.

## Status semantics

1. **All** includes every fixture from the current Home payload.
2. **Live** includes both `.live` and `.halfTime`; this matches the existing Matches-screen live semantics.
3. **Upcoming**, **Finished**, **Postponed**, and **Cancelled** each match only their exact `FixtureState`.
4. Available controls are **All** plus only the status groups represented in the current payload. Their canonical order is All, Live, Upcoming, Finished, Postponed, Cancelled; provider order does not change control order.
5. If a refresh removes the selected status group, selection normalizes to All before the refreshed feed is committed.

## Explainability invariants

- Filtering is applied only after `HomePersonalization` partitions fixtures.
- A fixture never moves between followed-related and public-general sections because of a filter.
- `HomeFixtureFollowReason` is preserved byte-for-byte for every visible related fixture.
- Relative provider order is preserved within each partition.
- Related and public results remain disjoint and together equal the selected subset of the source fixtures.
- Player follows still never imply a fixture relationship.
- “Important today” remains the provider-supplied public Home subset. The client does not calculate importance.

## UI and state

- One filter control governs both followed and public match sections.
- The control is shown only when the Home payload contains fixtures.
- With followed interests, a selected status with no related fixture shows explicit filter-specific empty copy; it must not claim there are no related fixtures at all.
- A public section with no fixture for the selected status is omitted. With no followed interests, every source fixture remains in the public partition, so every available non-All filter has at least one visible result.
- Refresh retains a still-valid choice. Authentication changes may retain the non-sensitive choice, but old fixture data is removed immediately and a new payload revalidates the choice.

## Accessibility and layout

- Filters use native buttons with at least a 44-point target.
- Selected state uses a checkmark plus the accessibility selected trait, not color alone.
- Regular Dynamic Type uses a horizontally scrollable rail with logical leading order; accessibility sizes use a full-width vertical list.
- SwiftUI leading/trailing semantics provide RTL mirroring.
- Every control has a localized label, hint, stable identifier, and visible text.
- Filtering does not move VoiceOver focus automatically; focus remains on the selected control so the selected trait can be announced and the following result sections are next in traversal order.

## Acceptance checks

1. Pure tests cover All ordering, live/half-time grouping, canonical availability, every exceptional state, invalid-selection normalization, empty input, disjoint partitioning, and follow-reason preservation.
2. UI-test source selects Live and Upcoming and proves the same fixture IDs appear/disappear without creating alternate identities.
3. Static verification requires the contract, model, tests, localization, identifiers, Dynamic Type branch, and selection normalization during feed load.
4. Existing Home personalization, news discovery, deep-link, OpenAPI, localization, and unsafe-source checks remain green.
5. Swift type checking, XCTest execution, simulator RTL/Dynamic Type, and VoiceOver remain macOS/Xcode gates.
