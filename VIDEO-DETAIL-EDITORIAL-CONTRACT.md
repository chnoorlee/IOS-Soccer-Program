# Video detail editorial contract

## Purpose

This slice extends the native video detail page with an expandable synopsis, verified publisher and program context, and a bounded related-video rail. It preserves the existing rights-aware playback and favorite actions without inventing media, editorial relationships, or personalized ranking.

## Evidence boundary

- The supplied SEC Sports detail screenshot directly shows the title, duration, Play and Favorites actions, a synopsis with a Show more control, and a release date.
- SEC Sports' current official App Store description also documents original programs, recommendations, favorites, history, and browsing by sport or category.
- The screenshot does not prove the shape or ranking of a related-content surface.
- Consequently, program membership, publisher attribution, and related-video order may be rendered only when `GET /videos/{videoId}` explicitly returns them. The client never derives those fields from titles, content types, favorites, follows, or watch history.

## Detail response

`GET /videos/{videoId}` returns the requested complete `VideoSummary` plus detail-only editorial fields:

1. The response video ID must exactly equal the normalized path ID. A mismatch is a contract violation and is rejected before caching.
2. `publisher` is nullable localized text. When present, both Arabic and English values must be valid non-empty localized copy.
3. `program` is nullable. When present, it contains a stable identifier and valid Arabic and English title.
4. `relatedVideos` is required and contains at most 10 complete, rights-filtered `VideoSummary` objects.
5. Related IDs must be unique and must not include the current video ID.
6. Array order is the entire related-content ordering contract. The client preserves it exactly and never re-ranks the array locally.
7. An empty related array is valid and causes the related section to be omitted.
8. Every related entry retains its own `isPlayable` and `availabilityReason`; association never grants playback rights.
9. Any invalid current video, context object, or related entry rejects the whole response before it can enter the public cache.

The complete detail response uses a five-minute stale-if-error window. The client never combines fresh metadata with an older editorial-context fragment.

## Presentation

1. The synopsis initially uses a four-line limit only when its copy exceeds the explicit client threshold. Show more and Show less are user-controlled; changing the state never starts playback.
2. Publisher, program, and release date are presented as labelled metadata. Missing nullable values are omitted rather than replaced with fabricated copy.
3. The related section appears only for the exact non-empty server array and uses the server's order.
4. Opening a related card performs the same fresh detail lookup and rights checks as opening any other video.
5. The current Play and Favorites actions remain independent: saving a video does not authorize it, and requesting playback does not save it.

## Accessibility and layout

- Show more and Show less are textual controls with a stable accessibility identifier and at least a 44-point target.
- Metadata and related-content headings expose header semantics.
- Availability remains visible as text and is never conveyed only by color.
- Related cards expose title, type, duration when meaningful, and availability through the existing card semantics.
- Arabic and English localization key sets remain identical, with natural RTL order in Arabic.
- No media autoplays when the page loads, expands, or navigates to a related item.

## Mock and validation boundary

- Mock publisher names, program names, descriptions, and related associations are fictional demo editorial data.
- Mock videos remain non-playable and do not imply licensed SEC Sports, GOAT, league, club, or broadcaster content.
- Static source validation and Swift parser checks on Windows do not prove an Xcode build, XCTest run, simulator rendering, VoiceOver behavior, streaming entitlement, or App Store acceptance.

## Deferred until evidence exists

- Personalized recommendations and explanation labels require a dedicated server contract, privacy review, and ranking evidence.
- Autoplay and continuous-play queues require product consent, playback policy, accessibility review, and licensed media.
- Real posters, publisher marks, program artwork, and protected streams require licensed assets and a working backend.
- Analytics such as impressions, expansion events, recommendation clicks, and watch attribution require an approved telemetry contract.
