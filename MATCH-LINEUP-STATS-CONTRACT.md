# Match Lineup and Statistics Contract

Status: frozen for the current native iOS slice.

This contract defines what SportsHub may display in the Match Center lineups and
statistics tabs. It is deliberately vendor-neutral. A supplier adapter must map
its payload into this shape before the app treats the data as trusted.

## 1. Trust boundary

- The API is the authority for player identity, shirt number, starter status,
  broad position, formation label, formation slot and every statistic value.
- The client never invents a missing player, starter/substitute status, formation,
  pitch position or statistic.
- Incomplete data is a valid state and remains visible with an explanation.
- Structurally contradictory data is rejected before it reaches the UI or cache.
- Mock data is fictional demonstration data and is not evidence of supplier
  coverage.

## 2. Lineup payload

Each team has an optional formation label and up to 40 players. Player IDs and
shirt numbers must be unique within that team. Shirt numbers are integers from 1
through 99. At most 11 players may be marked as starters.

`formationPosition`, when present, contains:

- `line`: 0 through 4, counted from goalkeeper toward attack;
- `order`: 0 through 4, counted left-to-right within that line from the team's
  attacking perspective. It is spatial football data and does not flip with the
  app's Arabic/English reading direction.

A substitute must not have a formation position. Starter formation positions
must be unique.

Formation labels use two to four hyphen-separated integers, for example `4-3-3`
or `4-2-3-1`. Every component is 1 through 5 and the components sum to ten
outfield players. An invalid label is a contract error.

## 3. Pitch eligibility

The visual pitch is supplemental and is shown only when all of the following are
true:

1. The team has exactly 11 starters.
2. Exactly one starter is a goalkeeper.
3. A valid formation label is present.
4. Every starter has a unique formation position.
5. The goalkeeper is at line 0, order 0.
6. Outfield line counts match the formation components.
7. Orders in every line are contiguous from zero.

The goalkeeper is drawn at the bottom and the team attacks toward the top.

Failure of pitch eligibility is not itself a response failure. The app shows the
available ordered starter/substitute lists and an honest missing-data note.
At accessibility Dynamic Type sizes, the app uses the lists and omits the pitch
even when pitch data is complete. VoiceOver uses the textual lists as the source
of truth; the spatial pitch is hidden from the accessibility tree.

## 4. Statistics payload

The response may contain zero or one value for each supported type:

`POSSESSION`, `SHOTS`, `SHOTS_ON_TARGET`, `CORNERS`, `FOULS`, `OFFSIDES`,
`PASSES`, and `SAVES`.

- IDs and types must be unique.
- Values must be finite and non-negative.
- Possession uses `%`, each side is at most 100, and the two sides sum to 100
  within a 0.01 tolerance.
- Count statistics use an empty unit and whole-number values.
- If both shots and shots-on-target are present, shots on target must not exceed
  shots for either team.
- Valid statistics are placed in the canonical order listed above, independent
  of supplier ordering.

An empty statistics array is valid and produces an explicit not-yet-published or
unavailable state based on match status. It never produces a blank panel.

## 5. Acceptance evidence

- Unit tests cover a complete formation, partial/empty data, legacy missing
  `isStarter`, duplicate players and slots, illegal substitutes, invalid
  formations, duplicate statistics, invalid units/totals/counts and relational
  shots errors.
- The local mock demonstrates two complete formations plus substitutes.
- UI journey hooks prove that the semantic lineup list and statistics content
  are reachable; unit tests prove pitch eligibility. Runtime pitch layout,
  VoiceOver, RTL and simulator execution still require Xcode on macOS.
- The OpenAPI schema carries the same bounds and explicitly documents the
  pitch-eligibility and statistics invariants that JSON Schema cannot express.
