# Following Team Match Dashboard Contract

## Purpose

The Following screen may show one authoritative previous match and one
authoritative next match for every followed team. This is a compact dashboard,
not a complete season schedule and not a client-side inference from the general
fixtures feed.

## Client request

- `SportsDataProviding.teamMatchSnapshots(ids:)` accepts 1...100 team IDs.
- IDs are trimmed, non-empty, at most 128 characters, contain no path/query or
  control characters, and are unique after trimming.
- The remote provider preserves caller order and splits the request into GET
  batches of at most 20 IDs.
- Each request uses repeated `teamId` query parameters on
  `GET /v1/teams/match-snapshots`.
- An empty request or an invalid/duplicate ID is `invalidQuery`; the UI does not
  send a request when there are no followed teams.

## Response

Each batch returns exactly one item for every requested ID in the same order:

```json
{
  "data": [
    {
      "team": { "id": "team-one" },
      "previousFixture": null,
      "nextFixture": null
    }
  ]
}
```

- `data.count` equals the number of requested IDs.
- `data[index].team.id` equals the requested ID at the same index.
- The returned team IDs are therefore unique by construction.
- `previousFixture` and `nextFixture` are independently nullable. `null` means
  that the provider has no fixture in that bounded slot; it is not an error.
- A present previous fixture is `FINISHED`; a present next fixture is
  `SCHEDULED`.
- A present fixture contains the team exactly once as home or away, and that
  embedded `TeamSummary` equals the item-level team snapshot.
- The two fixture IDs within one item are disjoint. The same real-world fixture
  may legitimately appear under two followed teams in different items.
- The server chooses the nearest eligible fixture for each slot. The client can
  validate state, scope, snapshot equality and identity, but cannot prove global
  nearest-match completeness.

Any count, order, identity, state or snapshot violation rejects the complete
batch before it is cached. A later-batch failure rejects the complete client
operation; the UI never combines a partial remote result with another source.

## Cache, freshness and fallback

- Every GET batch is public, ETag-revalidated and may use a one-hour stale
  snapshot on transport/server failure.
- The client reports one aggregate `teamMatchSnapshots(ids:)` freshness key for
  the current ordered team-ID set.
- `remoteWithMockFallback` may replace the complete operation only for the
  existing recoverable transport/server classes. It never masks invalid query,
  authentication, not-found, decoding or contract failures.
- Demo and demo-fallback states remain visibly labelled.

## Following UI

- The dashboard appears only after follow synchronization and only when at
  least one team is followed.
- The dashboard requests the first 100 teams in canonical follow order. Any
  additional followed teams remain visible as basic navigation/unfollow cards
  with an explicit limit explanation; they are never silently discarded.
- Loading, retry and freshness are independent from saved articles, saved
  videos and follow synchronization.
- A follow change invalidates the in-flight dashboard request and reloads the
  exact current ordered team-ID set.
- Each team card keeps the team-detail and unfollow actions available. Each
  present fixture opens Match Center; missing slots use explicit text.
- At accessibility Dynamic Type sizes, controls and match content stack
  vertically. Every interactive target is at least 44 points, previous/next and
  match state are expressed in text, and RTL layout follows semantic leading and
  trailing alignment.

## Exclusions

This contract does not introduce broadcasters, regional viewing rights,
prediction games, trend ranking, reactions or comments. Those require separate
supplier, entitlement and moderation contracts.
