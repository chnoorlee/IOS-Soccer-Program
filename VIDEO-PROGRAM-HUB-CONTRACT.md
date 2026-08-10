# Video Program Hub Contract

Status: frozen for the current native iOS slice.

This contract covers the public task of browsing original sports programmes and
opening their published videos. SEC Sports' current Apple description states
that the app includes original shows, weekly league shows, sports education and
browsing by sport or category. The supplied SEC screenshot also shows an
Explore surface with sport filters and content-led cards. Those sources do not
publish SEC's programme taxonomy, ranking model, artwork rights, episode
relationships or API fields. SportsHub therefore uses its own bilingual
programme shelf, identifiers and provider contract.

## 1. Product scope

- Explore exposes a first-class Programs entry. The programme library can be
  filtered by one explicit `VideoSport`; each filter is a new provider request,
  so the client never filters one incomplete page and calls it a full catalog.
- A programme summary contains a stable ID, bilingual title and description,
  one explicit sport, and an optional featured `VideoSummary`. The featured
  video is editorial metadata, not a programme logo, autoplay preview,
  recommendation score or playback grant.
- Programme detail repeats the authoritative summary and returns a provider-
  ordered page of episodes. Each episode contains a `VideoSummary` and an
  explicit nullable publication date. The client does not infer membership
  from title text, search results, related videos, publisher or watch history.
- Tapping the programme relationship on an existing video detail opens the
  programme by its exact ID. Tapping an episode opens the existing video detail
  and preserves its independent playback/availability checks.

## 2. Ordering, pagination and fallback

- `/video-programs` and `/video-programs/{programId}` use opaque cursor paging,
  with 1...50 items per page and at most 2,048 cursor characters. Provider
  order is authoritative; the client does not label it popularity, recency or
  personalization.
- IDs are unique within every page and across pages already appended in the
  current view. `hasMore == true` requires a non-empty page and a non-empty
  cursor; `hasMore == false` requires `nextCursor == null`.
- The detail response must echo the requested programme ID. A mismatch,
  duplicate ID, malformed cursor, invalid nested video or text contract fails
  before the public response enters cache.
- Recoverable first-page failures may switch the entire visible resource to
  explicitly labelled fictional Mock data. A fallback page always terminates
  pagination. Later-page failures keep the previously loaded real page and
  expose retry; they never append Mock programmes or episodes to real data.

## 3. Content and rights boundary

- Programme descriptions are editorial copy supplied in both languages,
  trimmed, non-empty, free of control characters and limited to 500 Unicode
  scalars. IDs retain the shared 128-scalar safe identifier boundary.
- A featured video or episode may carry the existing optional authorized video
  poster, but the programme object introduces no logo, remote artwork, host,
  sponsor, schedule, season, cast or trademark field. Those require separate
  verified product and rights contracts.
- Programme membership and display do not grant playback. Every nested video
  still follows `isPlayable`, availability, short-lived playback sessions,
  region/entitlement checks and the existing poster-media boundary.
- Mock programme titles, descriptions and relationships are fictional. Mock
  videos remain non-playable and contain no third-party images, footage,
  league marks or personalities.

## 4. Original layout and accessibility

- The library uses SportsHub's deep ink, signal cyan, warm timing gold and
  system surfaces. A narrow sport-coloured signal rail is the programme-shelf
  signature; it does not copy SEC's fluorescent green branding or photography.
- At regular Dynamic Type sizes the library may use two columns; accessibility
  sizes use one logical leading-aligned column. Cards never rely on colour
  alone: sport is always written and paired with a system symbol.
- Sport filters and retry/load-more actions use native buttons, selected traits
  and at least 44-point targets. Loading decoration is hidden from VoiceOver.
- Initial error, later-page error and empty states are distinct. Error focus is
  moved only after the matching request completes, and stale/cancelled requests
  cannot replace a newer filter or retry result.
- Programme cards combine their title, description, sport and featured-video
  context into one navigation target. Episode cards reuse the existing
  accessible video component. There is no autoplay or mandatory animation.

## 5. Acceptance

- DTO tests cover exact mapping, bilingual text bounds, explicit nullable
  featured video/date, duplicate IDs, response-ID mismatch, cursor invariants
  and cross-page duplicate rejection.
- Remote tests cover exact paths/query values, safe path IDs, ETag/cache
  behavior, mapping and rejection before cache writes.
- Mock tests prove sport filtering, programme/episode membership, fictional
  descriptions, terminating pages and non-playable videos.
- UI-test source covers Explore -> Programs -> programme detail -> episode ->
  video detail, with stable accessibility identifiers and no playback claim.
- Windows checks cover source structure, localization parity, plist parsing,
  Swift syntax trees and OpenAPI validity only. Xcode compilation, XCTest,
  Arabic RTL, Dynamic Type, VoiceOver, real provider completeness, CDN media
  and programme rights remain Apple-platform/back-end gates.
