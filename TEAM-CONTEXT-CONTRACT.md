# Team Context Contract

This slice implements the team-channel structure evidenced in the reference
screens: a clear previous/next match snapshot followed by recent team news and
related video metadata. It does not copy protected branding, text, artwork or
footage.

## Authoritative scope

- `GET /teams/{teamId}` returns bounded match windows for exactly the requested
  team. The response `team.id` must echo the path identifier, and the matching
  team snapshot embedded in every fixture must equal the top-level team snapshot.
- `nextFixtures` contains at most 10 unique `SCHEDULED` fixtures, each containing
  the team, ordered by kickoff ascending and then ID ascending.
- `recentFixtures` contains at most 10 unique `FINISHED` fixtures, each containing
  the team, ordered by kickoff descending and then ID ascending.
- Fixture IDs are disjoint across the two windows and every fixture competition
  appears in the response competition list. These windows are not represented as
  a complete season schedule.
- `GET /teams/{teamId}/content` echoes `teamId` and returns at most 10 unique
  articles plus 10 unique videos that the service explicitly associated with that
  team. The client never derives association from titles, descriptions, player
  names or team-name substring matches.

## Editorial and rights boundary

- Articles are ordered newest first, with ID as the stable tie-breaker.
- Video order is the provider's editorial order because summary metadata has no
  publication timestamp.
- Videos remain rights-filtered metadata. A card being present does not imply
  playback permission; playback still requires the existing session and
  entitlement flow.
- Mock articles and videos are fictional and contain no protected footage or
  copied reporting.

## Failure and freshness behavior

- Core team identity, squad, and team content have separate load states. Failure
  of the editorial endpoint does not erase the team page or squad.
- Team detail and team content are independent ETag-capable cache resources. A
  recoverable remote failure may show a whole fictional mock response only when
  it is marked as demo fallback. Contract, authorization, not-found and withdrawn
  errors do not mix remote and mock records.
- Async results are request-scoped so an older team request cannot overwrite a
  newer page.

## Accessibility

- Previous and next match slots remain separate even when either side is empty.
- Every match, article, and video card is a standard navigation target with at
  least a 44-point interactive height.
- Cards use the existing Dynamic Type-aware layouts, semantic headings, RTL-safe
  leading/trailing alignment, combined VoiceOver labels and localized empty/error
  states.
