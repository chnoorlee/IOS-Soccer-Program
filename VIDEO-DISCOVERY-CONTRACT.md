# Video editorial discovery contract

## Purpose

This slice turns Explore into an evidence-bound video destination with an editorial hero, an explicitly ranked Trending rail, sport categories, and the existing content-type channels. It does not invent rankings, classifications, artwork, or licensed playback.

## Evidence boundary

- The supplied SEC Sports screenshots show a video-led home, a detail page, and an Explore taxonomy.
- The referenced GOAT App Store metadata describes video highlights, goals, interviews, behind-the-scenes material, and analysis.
- The repository contract already exposes `LIVE`, `REPLAY`, `HIGHLIGHT`, `ORIGINAL`, and `INTERVIEW` in each video payload.
- The paginated `/videos` payload does not carry editorial placement or sport metadata.
- The dedicated `/videos/discovery` response is therefore the only source of truth for featured placement, Trending order, and sport classification.

The client may render those surfaces only when the dedicated response supplies the required fields and passes the rules below.

## Discovery response

`GET /videos/discovery` returns one bounded, cacheable response:

1. `items` contains at most 100 entries. Every entry contains a complete rights-filtered `VideoSummary` and exactly one `sport` enum.
2. Video IDs are unique across `items`.
3. `featuredVideoId` is nullable. A non-null value must be a valid ID that references exactly one item.
4. `trendingVideoIds` contains at most 10 unique valid IDs. Every ID must reference an item.
5. `featuredVideoId` must not also occur in `trendingVideoIds`; the two editorial surfaces have distinct semantics.
6. The order of `trendingVideoIds` is the complete ranking contract: array position zero is rank 1. The client never recomputes it from views, follows, saves, or watch progress.
7. An empty `items` array necessarily has a null featured ID and an empty Trending array because dangling references fail closed.
8. An invalid response is rejected before it can enter the public cache.

The client uses a 15-minute stale-if-error window for the entire discovery snapshot. It never combines fresh placements with stale items or returns a partially validated response.

## Source of truth and ordering

1. `SportsVideo.type` is the only source of truth for content-type channel membership.
2. `VideoDiscoveryItem.sport` is the only source of truth for sport membership.
3. `featuredVideoId` is the only source of truth for the hero.
4. `trendingVideoIds` order is the only source of truth for Trending membership and rank.
5. The canonical type-control order is All, Live, Replay, Highlights, Original, Interview.
6. The canonical sport-control order is Football, Basketball, Esports, Motorsport, Combat, Archery. Only sports present in the complete response are shown, after All sports.
7. Type availability is calculated within the selected sport. An unavailable type selection normalizes to All.
8. Library filters preserve the provider's `items` order and original video IDs exactly.
9. Library filters do not alter the global hero or Trending rail; those are editorial surfaces, not derived search results.
10. Filtering and editorial placement must not change `isPlayable`, `availabilityReason`, duration, copy, or any other video metadata.

## Complete remote list

1. `/videos` is read in pages of at most 100 items and may aggregate at most 1,000 items.
2. IDs must be unique across the entire response sequence.
3. `hasMore: true` requires a non-empty page and a non-empty, previously unseen `nextCursor`.
4. `hasMore: false` requires `nextCursor: null`.
5. Each page is decoded and validated, including cross-page constraints, before that page may enter the public cache.
6. A later-page failure never returns a partial remote list. A recoverable failure may replace the whole result with the explicitly labelled demo fallback.
7. The client preserves server order because the API exposes no verified ranking field.

## Rights and playback

- A Live channel is metadata discovery, not proof that a stream is licensed or currently playable.
- The watch action remains available only when the provider returns `isPlayable: true` and no availability reason.
- Login, entitlement, region, not-started, and expired states remain visible in cards and details.
- Mock entries are clearly fictional metadata, have no protected media assets, and remain non-playable.
- Live duration is not rendered as `0:00`; absence of a live duration is not converted into a fabricated value.

## Accessibility and layout

- The featured hero uses original gradients and SF Symbols until licensed artwork exists. It exposes title, type, sport, duration when meaningful, and the availability state as text.
- Every sport and type control has text, an icon, a selected trait, a stable identifier, and a minimum 44-point target.
- Every Trending item exposes its explicit rank in text; rank is not conveyed by color or position alone.
- Regular Dynamic Type uses a horizontal control rail. Accessibility Dynamic Type uses full-width vertical controls so labels do not clip.
- The channel group is exposed as a contained accessibility region and does not rely on color alone.
- Arabic and English localization key sets must remain identical.

## Deferred until evidence exists

- Popularity scores, view counts, recommendation explanations, and personalized ranking require separately defined server evidence.
- Exclusive labels and poster photography require explicit editorial metadata and licensed assets.
- Real live and on-demand playback requires licensed media, a working authorization backend, and macOS/iOS runtime validation.
