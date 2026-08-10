# SportsHub Season Calendar Contract

Status: frozen implementation contract for the next native iOS slice (2026-08-07).

## 1. Evidence and scope

- The Saudi App Store description for Jdwal 3.4.7 explicitly advertises a calendar for the most important dates of the season.
- The public description does not reveal its event taxonomy, provider, update cadence, private layout, notification rules, or data model.
- SportsHub already has fixture-by-date browsing and competition season fixtures, but no cross-competition view for draws, transfer windows, international breaks, or other season milestones.

This slice adds a read-only, Arabic-first season calendar. It does not create reminders, tickets, travel plans, fixture kickoffs, inferred deadlines, or user-submitted dates.

## 2. Product promise

The screen answers one question: "Which provider-listed milestones matter across the current season window?"

Every event is provider-authored and belongs to exactly one type:

- `COMPETITION_MILESTONE`: a competition phase or season milestone.
- `DRAW`: an official competition draw date.
- `TRANSFER_WINDOW`: the opening, closing, or span of a transfer window.
- `INTERNATIONAL_BREAK`: a provider-listed international break.
- `OTHER`: another explicitly supplied important date.

The client may derive whether an event is upcoming or already past only from the returned date range and the device calendar. It must not infer event importance, confirmation, competition association, or replacement dates.

## 3. Navigation and layout

- Explore presents the season calendar alongside the transfer center as a discovery tool, above the existing four-category grid.
- The screen begins with an evidence boundary and provider window, then offers `Upcoming` and `Full season` scopes plus only the event types present in the response.
- Events retain provider order and appear on an original vertical season spine: a date block, event marker, title, optional detail, optional competition, and optional end date.
- A card with an embedded competition opens the existing competition detail screen. Cards without a competition are informational and not styled as buttons.
- Accessibility Dynamic Type uses full-width vertical controls and never truncates titles, details, or date ranges.

## 4. Service contract

`GET /v1/season-calendar`

The endpoint returns one atomic provider window:

```json
{
  "data": {
    "rangeStart": "2026-07-01T00:00:00Z",
    "rangeEnd": "2027-06-30T23:59:59Z",
    "updatedAt": "2026-08-07T09:00:00Z",
    "sourceName": "Licensed calendar provider",
    "events": [
      {
        "id": "calendar-1",
        "title": {"ar": "قرعة البطولة", "en": "Competition draw"},
        "detail": null,
        "startsAt": "2026-08-20T15:00:00Z",
        "endsAt": null,
        "kind": "DRAW",
        "competition": null
      }
    ]
  }
}
```

The provider window is inclusive, at most 400 days, and contains at most 200 events.

## 5. Client validation

Before display or cache write, the client rejects the response when any invariant fails:

- `rangeStart` is not earlier than `rangeEnd`, or the window exceeds 400 days;
- the source name is blank, longer than 100 characters, or contains control characters;
- more than 200 events are returned, event IDs repeat, an ID/title is invalid, a title exceeds 160 characters, a detail exceeds 500 characters, or display text contains control characters;
- an event starts outside the provider window;
- `endsAt` precedes `startsAt`, exceeds the provider window, or makes an event longer than 120 days;
- events are not ordered by `startsAt` ascending and ID ascending for ties;
- an optional detail is present but blank;
- repeated competition IDs contain contradictory snapshots.

The UI presentation independently preserves these rules so a non-remote provider cannot bypass them.

## 6. Freshness and failure

- `/season-calendar` is public ETag-revalidated content with a 24-hour stale-if-error window.
- Network, revalidated, offline snapshot, refresh-failed, demo, and demo-fallback provenance use the shared public-content status UI.
- A configured fallback may replace the entire atomic calendar with fictional demo content only after a recoverable live-service failure. Contract, authorization, and invalid-query failures remain closed.
- Refresh commits only a fully validated replacement; it never merges events from different providers or snapshots.

## 7. Accessibility and localization

- Arabic remains the first-run language and the layout follows native RTL mirroring.
- Every control and navigable event has a minimum 44-point target.
- Type and time state are expressed in text and symbols, never color alone.
- Each event exposes one coherent VoiceOver label containing title, type, dates, competition, and detail.
- Loading, empty, error, scope, filter, source, and recovery copy is localized in Arabic and English.
- Runtime VoiceOver, Dynamic Type, RTL, locale-calendar, and simulator validation remain required on macOS; Windows checks are structural only.

## 8. Deferred work

- Licensed calendar provider selection, competition mapping, update SLA, and correction history.
- Add-to-calendar/reminder workflows and notification preference design.
- Ticketing, travel, broadcast rights, fixture generation, and editorial submissions.
- User timezone overrides, alternate calendar systems, and home-screen calendar widgets.
