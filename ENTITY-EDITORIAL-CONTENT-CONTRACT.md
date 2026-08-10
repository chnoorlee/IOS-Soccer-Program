# Entity Editorial Content Contract

This contract adds recent editorial channels to competition and player details. It follows the
public GOAT capability of pairing sports news, player updates, interviews and video summaries with
the entity a supporter is already viewing. It does not copy protected reporting, imagery or media.

## Authoritative association

- `GET /competitions/{competitionId}/content` must echo the exact path `competitionId`.
- `GET /players/{playerId}/content` must echo the exact path `playerId`.
- Each response contains at most 10 unique articles and 10 unique videos. The complete bounded
  response is one cache unit; the client never merges records from a different entity or fallback.
- Association is Provider-authored. The client must not infer it from titles, descriptions,
  competition names, player names, teams, transfers, statistics, search results or substring tags.
- An empty array means the Provider has no confirmed related items in this bounded window. It is
  not evidence that no reporting or legal video exists elsewhere.

## Editorial ordering and rights

- Articles are ordered by `publishedAt` descending, then stable article ID ascending.
- Videos preserve Provider editorial order because `VideoSummary` has no publication timestamp.
- Article and video identifiers must be unique within their respective arrays. An item can appear
  in different entity responses only when the Provider explicitly associates it with each entity.
- Video cards remain rights-filtered metadata. Their presence grants no playback or subscription
  entitlement; playback still uses the existing short-lived server-authorised session flow.
- Mock articles and videos are fictional, contain no protected footage or copied reporting, and
  are attached by exact demo IDs rather than text matching.

## Freshness and failure

- Competition content and player content are separate ETag-capable public cache resources with a
  15-minute stale-if-error window.
- DTO validation, including exact entity echo, maximum counts, unique IDs and article order,
  completes before the response is cached.
- Only recoverable network, rate-limit or service failures may return one whole fictional Mock
  response, visibly marked as demo fallback. Contract, authorization, not-found and withdrawn
  failures never mix remote and Mock items.
- Core identity/statistics, season data, transfers and editorial content keep independent load
  states. Editorial failure does not erase the rest of an entity page.
- Async results are guarded by entity ID and request UUID so an older result cannot overwrite a
  newly selected entity or section.

## Presentation and accessibility

- Subject: Arabic-speaking supporters checking the latest verified context for one competition or
  player. The single job is to answer "what happened recently?" without leaving the entity page.
- Competition details expose a season-independent Latest section alongside standings, leaders and
  fixtures. It remains available even if season data is unavailable.
- Player details show the same bounded editorial channel after season statistics and before the
  independent transfer history.
- The visual signature is a two-lane editorial desk: a labelled newspaper lane with a teal rail and
  a labelled video lane with a warm-gold rail. Icons and headings communicate type without colour.
- Each lane has its own localized empty state. Loading/error/freshness status belongs to the whole
  entity content response, and retry does not reload unrelated page data.
- Article and video cards use standard navigation targets with at least 44 points of interactive
  height, semantic headings, leading/trailing alignment, RTL-safe order, Dynamic Type layouts and
  coherent VoiceOver labels. No new animation is introduced.

## Evidence boundary

- Windows static checks and Swift AST parsing do not prove Swift type checking, XCTest execution,
  simulator navigation, Arabic RTL layout, Dynamic Type or VoiceOver behaviour.
- Real associations, source marks, editorial completeness, media rights and update SLA require a
  licensed Provider and legal/editorial review before release.
