# SportsHub Global Transfer Center Contract

Status: frozen implementation contract for the next native iOS slice (2026-08-07).

## 1. Evidence and scope

- The Saudi App Store description for GOAT 2.1.8 explicitly advertises instant transfer updates and player news.
- The reference-app audit also records a dedicated transfer-center capability in Jdwal.
- The current SportsHub repository exposes transfer history only inside an individual player page. It has no global discovery entry or paged transfer feed.

This slice adds a read-only, Arabic-first transfer center. It does not add transfer scraping, editorial rumor generation, fees, negotiations, notifications, or user submissions.

## 2. Product promise

The transfer center answers one question: "What player moves are being reported, and what is the provider's current status for each one?"

Every row must show exactly one provider-authoritative status:

- `COMPLETED`: the provider marks the move complete.
- `AGREED`: the provider marks an agreement reached but not complete.
- `RUMORED`: an unconfirmed report. The UI must display the rumor label and must not use confirmed language.

The client must not infer or upgrade a status from article text, dates, team changes, or other metadata. "All" is the initial filter and retains the visible status label on every result. The other filters are `COMPLETED`, `AGREED`, and `RUMORED`.

## 3. Navigation and layout

- Explore has one prominent transfer-center entry above the existing four-category grid. It is not a sixth root tab.
- The entry uses the established ink/accent/warm palette and has a minimum 44-point target.
- The destination begins with a short status-boundary explanation, followed by the status filters and provider-ordered transfer cards.
- The card signature is a directional route from the origin team to the destination team, with the player, provider status, and transfer date above it.
- Activating a card opens the existing player detail screen. Team names in the route are descriptive in this slice, avoiding nested interactive controls.
- At accessibility Dynamic Type sizes the filter rail becomes a vertical stack and card content may wrap without clipping.

## 4. Service contract

`GET /v1/transfers`

Query parameters:

- `cursor`: opaque server cursor, optional, 1 to 512 characters after trimming.
- `limit`: required by the client, 1 to 100; SportsHub requests 30.
- `status`: optional `RUMORED | AGREED | COMPLETED`.

Response uses the existing `TransferListResponse` envelope:

```json
{
  "data": [
    {
      "id": "transfer-123",
      "player": {},
      "fromTeam": {},
      "toTeam": {},
      "transferDate": "2026-08-07",
      "status": "COMPLETED"
    }
  ],
  "page": { "nextCursor": null, "hasMore": false }
}
```

Provider order is newest first. Equal dates use transfer ID ascending as the deterministic tiebreaker.

## 5. Client validation

Before displaying a page, the client rejects it when any of these invariants fail:

- more rows are returned than the requested limit;
- transfer IDs are duplicated;
- neither an origin nor a destination team exists;
- origin and destination are the same team;
- returned status differs from an explicit requested status;
- rows violate newest-first order or the equal-date ID tiebreaker;
- `hasMore` is true without a non-empty page and a non-empty next cursor;
- `hasMore` is false while `nextCursor` is non-null.

Across pages, the screen also rejects repeated cursors and duplicate transfer IDs.

## 6. Freshness, caching, and failure

- `/transfers` is public, ETag-revalidated content with a 15-minute stale-if-error window.
- Network, revalidated, offline snapshot, refresh-failed, and demo-fallback provenance use the shared public-content status UI.
- A recoverable live-service failure may use the fictional mock provider only for a first-page request and only when the fallback wrapper is configured. The screen must then identify the content as fictional demo content. That fallback page is terminal: its demo cursor is removed, and failed later-page requests never fall back, so fictional and live records cannot mix.
- A contract violation, authorization failure, or invalid query fails closed and must never fall back.
- Refresh replaces the current filtered result. Loading the next page appends only after all cross-page invariants pass.

## 7. Accessibility and localization

- Arabic remains the first-run language and follows right-to-left layout automatically; arrow symbols use semantic `forward` direction.
- Controls and cards have at least a 44 by 44 point target.
- Status selection exposes the selected trait and an action hint.
- Cards combine player, status, date, origin, and destination into a coherent VoiceOver element.
- Loading, empty, refresh-failed, and next-page-failed states have localized Arabic and English recovery copy.
- Runtime VoiceOver, Dynamic Type, RTL, and simulator validation remain required on macOS; Windows checks are structural only.

## 8. Deferred work

- Licensed transfer feeds and commercial provider selection.
- Rumor sourcing, citations, reliability scoring, and editorial corrections.
- Transfer fees, contract length, medical status, negotiations, and push alerts.
- Subscription/ad-removal, live video, and third-party scraping.
