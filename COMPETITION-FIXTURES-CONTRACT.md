# Competition Fixtures Contract

## Evidence boundary

The supplied Jdwal reference shows a competition detail surface with separate
Standings, Scorers, and Fixtures tabs plus an explicit season selector. This
slice implements that observable navigation and information hierarchy. It does
not infer trending ranks, media rights, betting data, or supplier-only fields.

## Request scope

- The client requests `GET /v1/competitions/{competitionId}/fixtures`.
- `seasonId` is required. A local match-day response must never be presented as
  the complete season schedule.
- `competitionId`, `seasonId`, `limit=100`, and the optional opaque `cursor`
  define a page request.
- Identifiers and cursors are validated before they can enter a URL.

## Response invariants

- Every page echoes the requested `competitionId` and `seasonId` exactly.
- Every fixture belongs to the requested competition.
- Fixtures are globally ordered by `kickoffAt` ascending, then by stable
  fixture ID ascending when kickoff times are equal.
- Fixture IDs are unique across every page and the complete response is capped
  at 1,000 items.
- `hasMore=false` requires a null `nextCursor`.
- `hasMore=true` requires a non-empty page and a new, non-empty, valid cursor.
- A malformed, mismatched, duplicated, out-of-order, or looping page is a
  contract failure and is never cached as validated data.
- The provider returns only after all pages pass. Cancellation or failure on a
  later page never returns a partial schedule.

## Freshness and fallback

- Each validated page may use conditional HTTP caching with a six-hour stale
  window and is isolated by competition, season, limit, and cursor URL.
- Freshness is reported against the selected competition and season resource.
- Only recoverable network/service errors may fall back to the complete demo
  schedule. Authentication, not-found, decoding, and contract failures remain
  visible.
- A demo fallback is explicitly reported as demo fallback content.

## Presentation

- Competition detail exposes Standings, Leaders, and Fixtures as explicit
  selectable sections; only the selected section loads and renders.
- Fixtures are partitioned exactly once into Live, Upcoming, Results, and Other
  (postponed/cancelled). No fixture may be dropped or duplicated.
- Live and Upcoming sort by kickoff ascending. Results and Other sort by
  kickoff descending. Stable fixture ID breaks equal-time ties.
- Every fixture opens the existing match center using its stable fixture ID.
- Loading, empty, failure, and retry states are specific to the selected
  section. A stale request may not overwrite a newer season, tab, or leader
  category selection.

## Accessibility and localization

- Section controls use text and icons, a minimum 44-point target, selected
  traits, stable identifiers, and logical RTL ordering.
- Regular Dynamic Type uses a horizontally scrollable rail. Accessibility
  Dynamic Type uses full-width vertical buttons.
- Arabic and English provide equivalent labels for all tabs and fixture groups.
- Fixture cards remain a single native navigation target and retain their
  existing Dynamic Type semantics.

## Verification boundary

On Windows, repository verification covers source contracts, localization
parity, OpenAPI validation, Swift syntax inspection, pure presentation tests by
source review, and deterministic UI-journey markers. Xcode compilation, XCTest,
simulator interaction, RTL screenshots, and VoiceOver behavior require macOS
and a real Apple toolchain before release.
