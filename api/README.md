# SportsHub API contract

`openapi.yaml` is the contract between the iOS app, the SportsHub backend, and any sports-data adapter. It is deliberately vendor-neutral: provider IDs, raw payloads, undocumented ordering, and provider-specific error text must never cross this boundary.

## Invariants

- Public base path is `/v1`; breaking field removals or type changes require a separately planned migration.
- All IDs are SportsHub stable IDs. External provider IDs stay in the adapter layer.
- Dates are RFC 3339 UTC instants. Match-day filtering uses an explicit IANA `timeZone`.
- Enum values are `UPPER_SNAKE_CASE`.
- Catalog and history list responses use cursor pagination. The account follow list is a bounded complete snapshot of at most 500 items so the client can safely unfollow by server-issued `followId`.
- The onboarding catalogs for teams, players, and competitions are independent public reads. The client requests at most 100 items per group, validates entity IDs before caching, and may revalidate each group independently with ETag so one failed catalog never hides the other two.
- A follow target is the compound key `(type, entityId)`. Every account follow response includes exactly one matching, server-authoritative team, player, or competition presentation snapshot and uses canonical newest-first ordering with type and ID tie-breakers. Following changes notification eligibility only; it does not enable an event category or grant system permission.
- The iOS client resolves authenticated follow credentials for the expected account ID and fails before HTTP on a mismatch; it also rejects late responses whose identity or local mutation operation is no longer current.
- Errors use one `application/problem+json` schema with stable machine-readable `code` values.
- External data is validated before it is cached or mapped to app models.
- Article `VISUAL_BRIEF` content is a bounded bilingual semantic structure, never arbitrary HTML/SVG or a media-rights container. Format/payload pairing, section and item counts, globally unique item IDs, text lengths, and control characters are validated before public-cache writes; a missing format is treated as `STORY` only for rolling client migration.
- Every current `ArticleSummary` carries a viewer-neutral `engagement` snapshot with bounded total reactions and published-comment count. It may be ETag-cached and can lag the uncached community endpoints; it never contains `myReaction`, hidden moderation states, blocked-author state, ranking or share analytics. Rolling clients tolerate absence and hide the row rather than interpreting unknown as zero.
- Every current `ArticleSummary` also carries `heroMedia` as an explicit authorized object or `null`; rolling clients tolerate omission. Objects include a stable asset ID, direct HTTPS URL, exact MIME/dimensions, bilingual alternative text and bilingual visible credit. Upstream inclusion asserts publication rights; clients still require an exact configured host, unauthenticated redirect-free fetch and an 8 MiB cap. Personal saved-article snapshots omit the media object and signed URL.
- `ETag`/`If-None-Match` are supported on frequently refreshed reads.
- `Idempotency-Key` is required on retryable writes such as comments, follows, playback sessions, and prediction entries.
- Prediction games are free non-wager challenges. Public game metadata is ETag-cacheable, but a user's complete group ranking is authenticated `no-store` state, never enters public cache or demo fallback, and is editable only while both server state and `lockAt` permit it.
- Fixture broadcast listings are bounded read-only schedule metadata: Provider order, two-letter region, bilingual channel, optional bilingual commentator and canonical audio language. They contain no URL or entitlement, are empty for postponed/cancelled fixtures, and never prove subscription or playback rights.
- Live video URLs are never embedded in catalog responses; the client creates a short-lived playback-session resource.
- `/videos/discovery` is one bounded editorial snapshot. Item sport, featured membership, and Trending order are server authority; every placement ID must reference a unique included video, the featured item is disjoint from Trending, and placement never changes playback eligibility.
- Every current video summary/detail carries `poster` as an explicit publisher-authorized object or `null`; rolling clients tolerate omission. A poster includes a direct HTTPS URL, exact MIME/dimensions, bilingual alternative text and visible credit, and uses the same exact-host, unauthenticated, redirect-free 8 MiB image policy as article media. Poster display rights never grant playback, and personal video snapshots omit the object and signed URL.
- `/videos/{videoId}` must echo the path ID. Publisher, program membership, and the bounded related-video order are server authority; related IDs are unique, exclude the current video, and retain their own playback eligibility.
- `/video-programs` is a Provider-ordered bilingual catalog filtered by one explicit sport; `/video-programs/{programId}` must echo the path ID and returns only explicit programme membership. Both use 1...50-item pages, opaque cursors up to 2,048 characters, explicit nullable fields, within/across-page unique IDs, and no inferred host, season, schedule, artwork or playback entitlement. A recoverable Mock fallback may replace only the complete first page and must terminate pagination; it never extends a real later page.
- `/players/{playerId}/content` and `/competitions/{competitionId}/content` must echo the exact path ID. Each is one ETag-capable, season-independent cache unit with at most 10 unique articles and 10 unique videos; article time order and video Provider order are validated before caching. Names, teams, statistics, titles, and descriptions never create an association, and video metadata never grants playback.
- `/search` returns at most 100 unique `(type, entityId)` hits in server-authoritative relevance order after documented Arabic/English Unicode matching. The client may take type-filtered subsequences but never reranks them. Because the current search UI has no per-response provenance banner, a failed remote search does not silently return an offline snapshot or fictional fallback.
- Playback-session responses are never cached or replaced with mock data; all media and FairPlay URLs must use HTTPS and must not be logged.
- Clients set `supportsFairPlay` explicitly. They must send `false` until an `AVContentKeySession`/content-key delegate is configured, and the server must not return FairPlay endpoints to such clients.
- AirPlay and Picture in Picture are per-session server policies; the client must configure AVPlayer/AVPlayerViewController from those booleans instead of enabling external playback globally.
- Asset availability, region and rights windows are server decisions, not hidden client-side switches.
- Competition summaries may expose `currentSeasonId` and a Provider-published archive of at most 50 seasons. Season IDs are unique, dates form real intervals, entries use stable newest-first order, and the sole `isCurrent` flag must resolve to `currentSeasonId`; clients reject conflicts and never invent missing seasons or archive completeness.
- Authenticated watch-progress, watch-history, video-favorite and follow responses are private and must use `Cache-Control: private, no-store`; they never enter the public ETag cache or a mock-account fallback. Single-item and full history deletion remove progress/completion records only and preserve favorites and follows.
- The authenticated home variant is also private/no-store and must fail closed; it cannot be replaced by a guest/mock home snapshot when account personalization is unavailable.
- Guests keep the same state locally. Sign-in exposes an explicit merge action; the server applies newest-update-wins upserts, and the client clears guest records only after a confirmed response.
- Device guest-data clearing is a local-only action: it removes guest progress, favorites, follows, and local video snapshots without contacting the API, changing the signed-in account, or clearing public catalog cache and device preferences. Legacy guest-follow snapshots must never be repopulated from in-memory account state.
- The app-managed public ETag cache is recoverable catalog data only. It is capped at 50 MiB/200 entries and can be inspected or cleared independently; account-private `no-store` responses, playback sessions, guest personalization, Keychain sessions and device preferences never enter or follow that clear operation. The default HTTP session disables a second `URLCache` copy.
- Public home, fixture, article and video responses expose client-visible provenance only after decoding and domain validation: fresh network, successful ETag revalidation, or a timestamped offline snapshot. A recoverable mock fallback is labeled as fictional demo content, never as cached data; authenticated home remains a separate private live/no-store state.
- Match-event polling uses an exclusive `afterRevision` cursor in one monotonic per-fixture sequence. Each no-store response includes ordered event upserts/deletion tombstones plus the latest fixture snapshot and matching `fixtureRevision`; score-only changes may have an empty mutation list. Incremental failures never use disk cache or mock events, and foreground recovery starts from the authoritative full fixture snapshot.
- Fixture standings and head-to-head history are separate public ETag resources. The standings response carries the server-confirmed fixture season and rejects competition/table mismatches; head-to-head history contains only completed matches for the exact team pair, is deterministically ordered, may span competitions, and remains descriptive rather than predictive.
- Fixture lineups preserve incomplete supplier data as an explicit list-only state; the client renders a formation pitch only for a validated 11-player starter set with one goalkeeper, a legal formation and complete unique normalized slots. Statistics reject duplicate types, impossible units/totals and shots-on-target values above shots, then use canonical semantic ordering.
- `/fixtures/{fixtureId}/content` is the only authority for fixture-related moments and reports. It echoes the path ID, preserves provider editorial order, rejects duplicate moment/video/article IDs, and returns rights-filtered video metadata that grants no playback entitlement. Its cache and failure state are independent from the live fixture snapshot and event feed.
- Team detail match windows contain only the requested team: upcoming fixtures are scheduled and ascending, recent fixtures are finished and descending, IDs are unique/disjoint, and embedded team snapshots equal the top-level team snapshot. `/teams/{teamId}/content` echoes the path ID and is the only authority for team-related article/video association; clients never infer it from free text. Video entries remain rights-filtered metadata and grant no playback entitlement.
- The Following team dashboard uses repeated `teamId` values on `/teams/match-snapshots`, at most 20 per HTTP batch. Every response has exactly one ordered row per requested ID; previous is nullable/finished, next is nullable/scheduled, and every embedded team snapshot must equal the row team. The client may chunk up to 100 followed teams but never returns a partial multi-batch result.
- Apple identity tokens are accepted only by `/auth/apple`; the backend verifies signature, issuer, audience, expiry and nonce. Access tokens are short-lived, refresh tokens rotate once, and every auth response is `no-store`.
- Guest merge accepts video/follow target IDs, follow types, positions, completion flags and timestamps only. It never accepts client-copied video metadata, entitlements, or playback URLs.
- Notification preferences and APNs device bindings are account-private, `no-store` resources. Match choices distinguish lineup, kickoff, goal, yellow card, red card, substitution, half-time and full-time; breaking news remains separate. The deprecated `card` response aggregate is true only when both granular card fields are true, and a legacy `card` PATCH sets both. New clients fall back from missing granular card fields to `card`, but default a missing substitution field to false so a rolling migration cannot silently broaden consent. Device upserts are idempotent; APNs tokens are credential-like, must never be returned, logged or used as user identity, and are replaced on rotation. Logout revokes every device binding associated with the current refresh-token family.
- `DELETE /me` returns 204 only after permanent account deletion is complete. The backend removes deletable account data, all SportsHub sessions and notification devices, and revokes the Sign in with Apple grant server-side. The client reuses its idempotency key after ambiguous failures and never clears local state before 204.

## Stages

Each operation has an `x-sportshub-stage` marker:

- `core`: required by the current SwiftUI vertical slice.
- `content`: news, video and sports-entity depth; the iOS client currently implements a subset of these operations, while the real backend remains unimplemented.
- `account`: authenticated personalization and notification state.
- `community`: reactions/comments plus moderation.
- `growth`: free engagement predictions and later separately reviewed growth features.

The OpenAPI contract describes the intended v1 surface. A stage marker does not claim that the backend endpoint is implemented.

## Validation

Use a current OpenAPI 3.1 validator, for example:

```bash
npx @redocly/cli lint api/openapi.yaml
```
