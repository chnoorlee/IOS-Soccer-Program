# Prediction Games Contract

This contract defines the first interactive tournament-prediction slice. It is based on the
current GOAT App Store release note describing World Cup group-order predictions, but uses
original SportsHub data, copy and visual treatment.

## Product and safety boundary

- A prediction game is a free, non-wager sports challenge. The client must not show or accept
  odds, stakes, entry fees, virtual currency, cash value, prizes or purchase-linked advantages.
- Public game metadata may load without an account. Saving or reading a personal entry requires
  an authenticated account and must never fall back to guest storage, demo identity or public
  cache.
- The server-authoritative `state` and `lockAt` both gate editing. A client also disables edits
  when its local clock reaches `lockAt`, but only the server may finally accept or reject a save.
- `LOCKED`, `SETTLED` and `CANCELLED` games are read-only. A `409` response after a stale open
  screen must move the UI to a clear locked/error state instead of retrying silently.
- Rules are informational HTTPS links. They may not carry credentials and do not authorize a
  paid flow.

## Public game contract

- `GET /prediction-games` is an ETag-capable public resource and returns at most 20 games in
  Provider order. IDs are unique and are never inferred from title text.
- Every authoritative remote game has non-empty Arabic and English title/summary, an HTTPS rules
  URL, a lock time, an explicit state and 1...12 ordered groups. Clearly labelled local Demo data
  may omit the external rules URL instead of inventing a legal destination.
- Each group has a unique ID within the game, localized name, 2...8 unique teams and a
  `qualifyingPositions` value in `1..<teams.count`.
- A team may appear in only one group in the same game. Team IDs and localized snapshots are
  server data; the client does not resolve or merge them by displayed name.
- Contract violations are rejected before public cache storage. Recoverable list failures may
  use a clearly labelled demo fallback; personal entries never do.

## Personal entry contract

- `GET /prediction-games/{gameId}/entries/me` is authenticated, `no-store`, and returns either
  one entry or `404` for no saved entry.
- `PUT /prediction-games/{gameId}/entries/me` is authenticated, `no-store`, idempotent and uses
  an `Idempotency-Key`. It replaces the complete entry rather than patching individual rows.
- An entry contains exactly one ranking for every current game group. Every ranking contains
  every group team ID exactly once and no foreign IDs. Group and team order are significant.
- The response must echo the path `gameId` and the submitted complete ranking. A mismatched or
  partial response fails closed.
- Authentication changes invalidate in-flight entry requests and reset the local draft so one
  account's saved ordering cannot appear under another identity.
- Every private read/write captures the expected account ID and resolves an account-bound token
  for that same ID before networking. If the active identity changed, the request fails before
  transmission; discarding a stale response alone is not sufficient write isolation.

## Presentation and accessibility

- Subject: Arabic-speaking football supporters. Single job: arrange every group before the
  clearly displayed lock time and save one complete entry.
- Palette remains SportsHub deep ink `#0D1A33`, teal `#057385`, warm gold `#A1660D`, live red
  `#D62940`, plus semantic system surfaces. The memorable element is a numbered ranking track:
  positions are structural data, and the qualifying zone is labelled in text instead of color
  alone.
- The default draft preserves Provider team order. Up/down controls are the semantic source of
  truth; no task requires a drag gesture. Every control is at least 44x44 points and exposes the
  team, current position, destination and disabled boundary to VoiceOver.
- Arabic uses the app's RTL environment and system Arabic typography. Logical team order remains
  first-to-last regardless of layout direction. Dynamic Type keeps groups vertical and never
  compresses ranking actions into an unreadable horizontal rail.
- Loading, empty, public failure, entry failure, saving, saved, locked, settled, cancelled,
  signed-out and account-unavailable states use visible text and stable accessibility IDs.
- There is no automatic animation, media playback or timer announcement. Lock-time changes are
  re-evaluated on foreground refresh and save.

## Evidence boundary

- Mock game names, teams and predictions are fictional demonstration data.
- Passing Windows static checks or Swift AST parsing does not prove Swift type checking, XCTest,
  network authentication, server lock enforcement, RTL rendering, Dynamic Type or VoiceOver.
- Real competition marks, participant eligibility, scoring, moderation, rules, prizes or sponsor
  terms require a licensed backend and legal review before release.
