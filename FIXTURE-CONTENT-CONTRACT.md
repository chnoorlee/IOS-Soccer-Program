# Fixture Content Contract

This slice implements the `لحظات من المباراة` structure directly visible in
the supplied GOAT match-centre screenshot: a fixture-scoped rail of match
moments followed by related reports. It copies no protected branding, layout,
reporting, artwork, audio or footage.

## Authoritative association

- `GET /fixtures/{fixtureId}/content` is independent from the core fixture
  snapshot and incremental event feed. Its response must exactly echo the path
  `fixtureId` before any record is cached or displayed.
- The response contains at most 10 moments and 10 articles. Moment IDs,
  embedded video IDs and article IDs are unique within their respective lists.
- Both arrays preserve provider editorial order. The client does not derive
  association or ranking from titles, team names, event text, publication
  times, follows, favorites or viewing history.
- A moment minute is optional; when present it is an integer from 0 through
  200. It is presentation context, not an event-feed cursor or live-state
  mutation.

## Rights and playback boundary

- Every embedded video is the existing `VideoSummary` contract. A non-playable
  item carries an explicit availability reason; a playable item still requires
  a separate short-lived playback session.
- This endpoint never contains media URLs, FairPlay keys, entitlements or
  provider credentials. Listing a moment does not grant playback.
- The app does not autoplay. Selecting a moment opens the existing video detail
  flow, where playback authorization is re-evaluated.
- Mock content is original fictional metadata. It remains non-playable and
  contains no protected media.

## Failure, cache and refresh behavior

- Fixture content has its own load state and ETag cache resource. Its failure
  cannot erase or stop the score snapshot, event polling, lineups, statistics,
  standings or head-to-head views.
- Mapping and all identity, count, uniqueness, minute and video-rights checks
  complete before a 200 response enters the cache.
- A 304 response reuses the last validated response. A recoverable network,
  rate-limit or temporary server failure may return one complete fictional Mock
  response only when the freshness status identifies it as demo fallback.
- Contract, decoding, authorization, not-found and rights errors do not trigger
  Mock fallback or mix records from different sources.

## Presentation and accessibility

- Arabic and English titles come from explicit localized fields. Regular text
  sizes use a horizontally scrollable moment rail; accessibility sizes use a
  full-width vertical stack with no fixed text height.
- The minute badge is both chronology and the visual signature. It is not the
  only carrier of meaning: VoiceOver receives a localized minute phrase, moment
  title, video title, rights status and navigation hint.
- Reports use the existing Dynamic Type-aware article cards. All navigation and
  retry targets meet the app's 44-point interaction convention.
- Empty, loading, error, freshness and rights-restricted states remain explicit
  and localized. No motion or automatic playback is required to understand the
  section.

## Evidence boundary

The supplied screenshot directly supports the placement and Arabic section
concept. The Apple Lookup description for GOAT also names videos, match
highlights, key goals, interviews and post-match reports. It does not publish
the app's private ranking, CMS, media URLs, license terms or provider schema;
those remain backend and commercial prerequisites.
